import 'dart:async';

import 'package:drift/drift.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

class MetadataSnapshot<T> {
  const MetadataSnapshot({
    required this.data,
    required this.hasSnapshot,
    required this.stale,
    this.errorMessage,
  });

  const MetadataSnapshot.empty()
    : data = null,
      hasSnapshot = false,
      stale = false,
      errorMessage = null;

  final T? data;
  final bool hasSnapshot;
  final bool stale;
  final String? errorMessage;
}

abstract interface class JellyfinMetadataRepository {
  Stream<MetadataSnapshot<JellyfinHome>> watchHome();

  Future<void> refreshHome();

  Stream<MetadataSnapshot<JellyfinItem>> watchItem(String itemId);

  Future<void> refreshItem(String itemId);

  Stream<MetadataSnapshot<List<JellyfinItem>>> watchLibraryItems(
    String libraryId,
  );

  Future<void> refreshLibraryItems(String libraryId);

  Stream<MetadataSnapshot<List<JellyfinItem>>> watchSeasons(String seriesId);

  Future<void> refreshSeasons(String seriesId);

  Stream<MetadataSnapshot<List<JellyfinItem>>> watchEpisodes(
    String seriesId, {
    required String seasonId,
  });

  Future<void> refreshEpisodes(String seriesId, {required String seasonId});

  Future<void> close();
}

class DriftJellyfinMetadataRepository implements JellyfinMetadataRepository {
  DriftJellyfinMetadataRepository({
    required this.database,
    required this.librarySource,
    required this.detailsSource,
    required this.session,
  });

  final SoupDatabase database;
  final JellyfinLibrarySource librarySource;
  final JellyfinDetailsSource detailsSource;
  final JellyfinSession session;

  String get _serverId => session.serverId.isEmpty
      ? session.serverUrl.toString()
      : session.serverId;

  List<ScopeKey> get _homeKeys => [
    _scope(CacheScopeType.homeLibraries, homeScopeId),
    _scope(CacheScopeType.homeResume, homeScopeId),
    _scope(CacheScopeType.homeLatest, homeScopeId),
    _scope(CacheScopeType.homeRecentMovies, homeScopeId),
    _scope(CacheScopeType.homeRecentTv, homeScopeId),
  ];

  ScopeKey _scope(String type, String id) =>
      ScopeKey(serverId: _serverId, userId: session.userId, type: type, id: id);

  @override
  Stream<MetadataSnapshot<JellyfinHome>> watchHome() {
    final keys = _homeKeys;
    return _combineScopeStreams(
      [for (final key in keys) _watchScope(key)],
      (snapshots) => JellyfinHome(
        libraries: snapshots[0].data ?? const [],
        resume: snapshots[1].data ?? const [],
        latest: snapshots[2].data ?? const [],
        recentlyAddedMovies: snapshots[3].data ?? const [],
        recentlyAddedTv: snapshots[4].data ?? const [],
      ),
    );
  }

  @override
  Future<void> refreshHome() async {
    final keys = _homeKeys;
    try {
      final home = await librarySource.getHome(session);
      final groups = <(ScopeKey, List<JellyfinItem>)>[
        (keys[0], home.libraries),
        (keys[1], home.resume),
        (keys[2], home.latest),
        (keys[3], home.recentlyAddedMovies ?? const []),
        (keys[4], home.recentlyAddedTv ?? const []),
      ];
      await _writeGroups(groups);
    } on Object catch (error) {
      await database.markScopesStale(keys, error);
    }
  }

  @override
  Stream<MetadataSnapshot<JellyfinItem>> watchItem(String itemId) {
    return _watchScope(_scope(CacheScopeType.itemDetails, itemId)).map(
      (snapshot) => MetadataSnapshot(
        data: snapshot.data?.firstOrNull,
        hasSnapshot: snapshot.hasSnapshot,
        stale: snapshot.stale,
        errorMessage: snapshot.errorMessage,
      ),
    );
  }

  @override
  Future<void> refreshItem(String itemId) {
    final key = _scope(CacheScopeType.itemDetails, itemId);
    return _refreshList(
      key,
      () async => [await detailsSource.getItem(session, itemId)],
    );
  }

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchLibraryItems(
    String libraryId,
  ) => _watchScope(_scope(CacheScopeType.libraryContents, libraryId));

  @override
  Future<void> refreshLibraryItems(String libraryId) {
    return _refreshList(
      _scope(CacheScopeType.libraryContents, libraryId),
      () => detailsSource.getLibraryItems(session, libraryId),
    );
  }

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchSeasons(String seriesId) =>
      _watchScope(_scope(CacheScopeType.seriesSeasons, seriesId));

  @override
  Future<void> refreshSeasons(String seriesId) {
    return _refreshList(
      _scope(CacheScopeType.seriesSeasons, seriesId),
      () => detailsSource.getSeasons(session, seriesId),
    );
  }

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchEpisodes(
    String seriesId, {
    required String seasonId,
  }) => _watchScope(_scope(CacheScopeType.seasonEpisodes, seasonId));

  @override
  Future<void> refreshEpisodes(String seriesId, {required String seasonId}) {
    return _refreshList(
      _scope(CacheScopeType.seasonEpisodes, seasonId),
      () => detailsSource.getEpisodes(session, seriesId, seasonId: seasonId),
    );
  }

  Future<void> _refreshList(
    ScopeKey key,
    Future<List<JellyfinItem>> Function() request,
  ) async {
    try {
      final items = await request();
      await _writeGroups([(key, items)]);
    } on Object catch (error) {
      await database.markScopeStale(key, error);
    }
  }

  Future<void> _writeGroups(List<(ScopeKey, List<JellyfinItem>)> groups) async {
    final updatedAt = DateTime.now().toUtc();
    final itemsById = <String, JellyfinItem>{};
    for (final (_, items) in groups) {
      for (final item in items) {
        if (item.id.isNotEmpty) itemsById[item.id] = item;
      }
    }
    await database.replaceScopes(
      items: [
        for (final item in itemsById.values) _mediaCompanion(item, updatedAt),
      ],
      userStates: [
        for (final item in itemsById.values) _stateCompanion(item, updatedAt),
      ],
      scopes: [
        for (final (key, items) in groups)
          ScopeSnapshotWrite(
            key: key,
            orderedItemIds: [for (final item in items) item.id],
          ),
      ],
      refreshedAt: updatedAt,
    );
  }

  MediaItemsCompanion _mediaCompanion(JellyfinItem item, DateTime updatedAt) {
    return MediaItemsCompanion.insert(
      serverId: _serverId,
      itemId: item.id,
      name: item.name,
      type: item.type,
      collectionType: Value(item.collectionType),
      overview: Value(item.overview),
      productionYear: Value(item.productionYear),
      officialRating: Value(item.officialRating),
      communityRating: Value(item.communityRating),
      runTimeTicks: Value(item.runTimeTicks),
      seriesName: Value(item.seriesName),
      seasonName: Value(item.seasonName),
      indexNumber: Value(item.indexNumber),
      parentIndexNumber: Value(item.parentIndexNumber),
      primaryImageTag: Value(item.primaryImageTag),
      backdropImageTag: Value(item.backdropImageTag),
      primaryBlurHash: Value(item.primaryBlurHash),
      backdropBlurHash: Value(item.backdropBlurHash),
      updatedAt: updatedAt,
    );
  }

  UserItemStatesCompanion _stateCompanion(
    JellyfinItem item,
    DateTime updatedAt,
  ) {
    return UserItemStatesCompanion.insert(
      serverId: _serverId,
      userId: session.userId,
      itemId: item.id,
      playbackPositionTicks: Value(item.playbackPositionTicks),
      playedPercentage: Value(item.playedPercentage),
      played: Value(item.played),
      updatedAt: updatedAt,
    );
  }

  Stream<MetadataSnapshot<List<JellyfinItem>>> _watchScope(ScopeKey key) {
    late final StreamController<MetadataSnapshot<List<JellyfinItem>>>
    controller;
    StreamSubscription<List<CachedScopedItem>>? itemsSubscription;
    StreamSubscription<ScopeSync?>? syncSubscription;
    var cachedItems = const <CachedScopedItem>[];
    ScopeSync? sync;
    var itemsReady = false;
    var syncReady = false;

    void emit() {
      if (!itemsReady || !syncReady || controller.isClosed) return;
      controller.add(
        MetadataSnapshot(
          data: [for (final item in cachedItems) _fromCached(item)],
          hasSnapshot: sync?.lastSuccessfulRefresh != null,
          stale: sync?.stale ?? false,
          errorMessage: sync?.errorMessage,
        ),
      );
    }

    controller = StreamController(
      onListen: () {
        itemsSubscription = database.watchScope(key).listen((value) {
          cachedItems = value;
          itemsReady = true;
          emit();
        }, onError: controller.addError);
        syncSubscription = database.watchScopeSync(key).listen((value) {
          sync = value;
          syncReady = true;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await itemsSubscription?.cancel();
        await syncSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<MetadataSnapshot<T>> _combineScopeStreams<T>(
    List<Stream<MetadataSnapshot<List<JellyfinItem>>>> streams,
    T Function(List<MetadataSnapshot<List<JellyfinItem>>>) build,
  ) {
    late final StreamController<MetadataSnapshot<T>> controller;
    final values = List<MetadataSnapshot<List<JellyfinItem>>?>.filled(
      streams.length,
      null,
    );
    final subscriptions = <StreamSubscription<void>>[];

    void emit() {
      if (values.any((value) => value == null) || controller.isClosed) return;
      final snapshots = values.cast<MetadataSnapshot<List<JellyfinItem>>>();
      final hasSnapshot = snapshots.every((value) => value.hasSnapshot);
      controller.add(
        MetadataSnapshot(
          data: hasSnapshot ? build(snapshots) : null,
          hasSnapshot: hasSnapshot,
          stale: snapshots.any((value) => value.stale),
          errorMessage: snapshots
              .map((value) => value.errorMessage)
              .whereType<String>()
              .firstOrNull,
        ),
      );
    }

    controller = StreamController(
      onListen: () {
        for (var index = 0; index < streams.length; index++) {
          subscriptions.add(
            streams[index].listen((value) {
              values[index] = value;
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () => Future.wait([
        for (final subscription in subscriptions) subscription.cancel(),
      ]),
    );
    return controller.stream;
  }

  JellyfinItem _fromCached(CachedScopedItem cached) {
    final item = cached.item;
    final state = cached.userState;
    return JellyfinItem(
      id: item.itemId,
      name: item.name,
      type: item.type,
      collectionType: item.collectionType,
      overview: item.overview,
      productionYear: item.productionYear,
      officialRating: item.officialRating,
      communityRating: item.communityRating,
      runTimeTicks: item.runTimeTicks,
      playbackPositionTicks: state?.playbackPositionTicks ?? 0,
      playedPercentage: state?.playedPercentage,
      played: state?.played ?? false,
      seriesName: item.seriesName,
      seasonName: item.seasonName,
      indexNumber: item.indexNumber,
      parentIndexNumber: item.parentIndexNumber,
      primaryImageTag: item.primaryImageTag,
      backdropImageTag: item.backdropImageTag,
      primaryBlurHash: item.primaryBlurHash,
      backdropBlurHash: item.backdropBlurHash,
    );
  }

  @override
  Future<void> close() async {}
}

/// A small stream-backed adapter retained for isolated widget tests and embeds.
/// Soup's authenticated application path always supplies the Drift repository.
class TransientJellyfinMetadataRepository
    implements JellyfinMetadataRepository {
  TransientJellyfinMetadataRepository({
    required this.session,
    this.librarySource,
    this.detailsSource,
  });

  final JellyfinSession session;
  final JellyfinLibrarySource? librarySource;
  final JellyfinDetailsSource? detailsSource;
  final _home = _SnapshotSignal<JellyfinHome>();
  final _items = <String, _SnapshotSignal<JellyfinItem>>{};
  final _libraries = <String, _SnapshotSignal<List<JellyfinItem>>>{};
  final _seasons = <String, _SnapshotSignal<List<JellyfinItem>>>{};
  final _episodes = <String, _SnapshotSignal<List<JellyfinItem>>>{};

  @override
  Stream<MetadataSnapshot<JellyfinHome>> watchHome() => _home.watch();

  @override
  Future<void> refreshHome() => _refresh(
    _home,
    () => _requireLibrarySource().getHome(session),
    'Could not load your Jellyfin library.',
  );

  @override
  Stream<MetadataSnapshot<JellyfinItem>> watchItem(String itemId) =>
      _signal(_items, itemId).watch();

  @override
  Future<void> refreshItem(String itemId) => _refresh(
    _signal(_items, itemId),
    () => _requireDetailsSource().getItem(session, itemId),
    'Could not load these details.',
  );

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchLibraryItems(
    String libraryId,
  ) => _signal(_libraries, libraryId).watch();

  @override
  Future<void> refreshLibraryItems(String libraryId) => _refresh(
    _signal(_libraries, libraryId),
    () => _requireDetailsSource().getLibraryItems(session, libraryId),
    'Could not load this library.',
  );

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchSeasons(String seriesId) =>
      _signal(_seasons, seriesId).watch();

  @override
  Future<void> refreshSeasons(String seriesId) => _refresh(
    _signal(_seasons, seriesId),
    () => _requireDetailsSource().getSeasons(session, seriesId),
    'Could not load seasons.',
  );

  @override
  Stream<MetadataSnapshot<List<JellyfinItem>>> watchEpisodes(
    String seriesId, {
    required String seasonId,
  }) => _signal(_episodes, seasonId).watch();

  @override
  Future<void> refreshEpisodes(String seriesId, {required String seasonId}) =>
      _refresh(
        _signal(_episodes, seasonId),
        () => _requireDetailsSource().getEpisodes(
          session,
          seriesId,
          seasonId: seasonId,
        ),
        'Could not load this season.',
      );

  _SnapshotSignal<T> _signal<T>(
    Map<String, _SnapshotSignal<T>> signals,
    String id,
  ) {
    return signals.putIfAbsent(id, _SnapshotSignal<T>.new);
  }

  Future<void> _refresh<T>(
    _SnapshotSignal<T> signal,
    Future<T> Function() request,
    String fallback,
  ) async {
    try {
      signal.succeed(await request());
    } on Object catch (error) {
      signal.fail(_message(error, fallback));
    }
  }

  JellyfinLibrarySource _requireLibrarySource() {
    return librarySource ??
        (throw StateError('A Jellyfin library source was not supplied.'));
  }

  JellyfinDetailsSource _requireDetailsSource() {
    return detailsSource ??
        (throw StateError('A Jellyfin details source was not supplied.'));
  }

  @override
  Future<void> close() async {
    await Future.wait([
      _home.close(),
      for (final signal in _items.values) signal.close(),
      for (final signal in _libraries.values) signal.close(),
      for (final signal in _seasons.values) signal.close(),
      for (final signal in _episodes.values) signal.close(),
    ]);
  }

  static String _message(Object error, String fallback) {
    return error is JellyfinApiException ? error.message : fallback;
  }
}

class _SnapshotSignal<T> {
  MetadataSnapshot<T> _value = const MetadataSnapshot.empty();
  final StreamController<MetadataSnapshot<T>> _controller =
      StreamController.broadcast();

  Stream<MetadataSnapshot<T>> watch() {
    return Stream.multi((listener) {
      listener.add(_value);
      final subscription = _controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = subscription.cancel;
    });
  }

  void succeed(T data) {
    _value = MetadataSnapshot(data: data, hasSnapshot: true, stale: false);
    _controller.add(_value);
  }

  void fail(String message) {
    _value = MetadataSnapshot(
      data: _value.data,
      hasSnapshot: _value.hasSnapshot,
      stale: true,
      errorMessage: message,
    );
    _controller.add(_value);
  }

  Future<void> close() => _controller.close();
}
