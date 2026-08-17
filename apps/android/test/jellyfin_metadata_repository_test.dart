import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';

void main() {
  late SoupDatabase database;

  setUp(() {
    database = SoupDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => database.close());

  test('a recreated repository reads the committed home snapshot', () async {
    final source = FakeMetadataSource(
      home: _home(resume: [_item('one', position: 50)]),
    );
    final first = _repository(database, source, _session('alice'));

    await first.refreshHome();
    final recreated = _repository(database, source, _session('alice'));
    final cached = await recreated.watchHome().firstWhere(
      (snapshot) => snapshot.hasSnapshot,
    );

    expect(cached.data?.resume.single.id, 'one');
    expect(cached.data?.resume.single.playbackPositionTicks, 50);
    expect(cached.data?.resume.single.primaryBlurHash, 'primary-blur-one');
    expect(cached.data?.resume.single.backdropBlurHash, 'backdrop-blur-one');
    expect(cached.stale, isFalse);
  });

  test('shares item metadata but isolates state and visible scopes', () async {
    final aliceSource = FakeMetadataSource(
      home: _home(resume: [_item('shared', position: 100)]),
    );
    final bobSource = FakeMetadataSource(
      home: _home(latest: [_item('shared', played: true)]),
    );
    final alice = _repository(database, aliceSource, _session('alice'));
    final bob = _repository(database, bobSource, _session('bob'));

    await alice.refreshHome();
    await bob.refreshHome();

    expect(await database.select(database.mediaItems).get(), hasLength(1));
    final aliceHome = await alice.watchHome().firstWhere(
      (snapshot) => snapshot.hasSnapshot,
    );
    final bobHome = await bob.watchHome().firstWhere(
      (snapshot) => snapshot.hasSnapshot,
    );
    expect(aliceHome.data?.resume.single.playbackPositionTicks, 100);
    expect(aliceHome.data?.latest, isEmpty);
    expect(bobHome.data?.resume, isEmpty);
    expect(bobHome.data?.latest.single.played, isTrue);
  });

  test(
    'failed refresh keeps the previous snapshot and marks it stale',
    () async {
      final source = FakeMetadataSource(home: _home(latest: [_item('one')]));
      final repository = _repository(database, source, _session('alice'));
      await repository.refreshHome();
      source.error = const JellyfinApiException('Server unavailable.');

      await repository.refreshHome();
      final stale = await repository.watchHome().firstWhere(
        (snapshot) => snapshot.stale,
      );

      expect(stale.hasSnapshot, isTrue);
      expect(stale.data?.latest.single.id, 'one');
      expect(stale.errorMessage, 'Server unavailable.');
    },
  );

  test(
    'complete scope refresh atomically removes revoked membership',
    () async {
      final source = FakeMetadataSource(
        home: _home(),
        libraryItems: [_item('one'), _item('two')],
      );
      final repository = _repository(database, source, _session('alice'));
      await repository.refreshLibraryItems('library');
      source.libraryItems = [_item('two')];

      await repository.refreshLibraryItems('library');
      final visible = await repository
          .watchLibraryItems('library')
          .firstWhere((snapshot) => snapshot.hasSnapshot);

      expect(visible.data?.map((item) => item.id), ['two']);
      expect(await database.findMediaItem('server', 'one'), isNotNull);
    },
  );
}

DriftJellyfinMetadataRepository _repository(
  SoupDatabase database,
  FakeMetadataSource source,
  JellyfinSession session,
) {
  return DriftJellyfinMetadataRepository(
    database: database,
    librarySource: source,
    detailsSource: source,
    session: session,
  );
}

JellyfinSession _session(String userId) => JellyfinSession(
  serverUrl: Uri.parse('http://jellyfin/'),
  serverId: 'server',
  userId: userId,
  userName: userId,
  accessToken: 'token',
);

JellyfinItem _item(String id, {int position = 0, bool played = false}) =>
    JellyfinItem(
      id: id,
      name: 'Item $id',
      type: 'Movie',
      playbackPositionTicks: position,
      played: played,
      primaryImageTag: 'tag-$id',
      primaryBlurHash: 'primary-blur-$id',
      backdropBlurHash: 'backdrop-blur-$id',
    );

JellyfinHome _home({
  List<JellyfinItem> libraries = const [],
  List<JellyfinItem> resume = const [],
  List<JellyfinItem> latest = const [],
}) => JellyfinHome(
  libraries: libraries,
  resume: resume,
  latest: latest,
  recentlyAddedMovies: latest,
  recentlyAddedTv: const [],
);

class FakeMetadataSource
    implements JellyfinLibrarySource, JellyfinDetailsSource {
  FakeMetadataSource({required this.home, this.libraryItems = const []});

  JellyfinHome home;
  List<JellyfinItem> libraryItems;
  Object? error;

  void _throwIfNeeded() {
    final failure = error;
    if (failure != null) throw failure;
  }

  @override
  Future<JellyfinHome> getHome(JellyfinSession session) async {
    _throwIfNeeded();
    return home;
  }

  @override
  Future<JellyfinItem> getItem(JellyfinSession session, String itemId) async {
    _throwIfNeeded();
    return libraryItems.firstWhere((item) => item.id == itemId);
  }

  @override
  Future<List<JellyfinItem>> getLibraryItems(
    JellyfinSession session,
    String libraryId,
  ) async {
    _throwIfNeeded();
    return libraryItems;
  }

  @override
  Future<List<JellyfinItem>> getSeasons(
    JellyfinSession session,
    String seriesId,
  ) async => const [];

  @override
  Future<List<JellyfinItem>> getEpisodes(
    JellyfinSession session,
    String seriesId, {
    required String seasonId,
  }) async => const [];

  @override
  Future<Uint8List?> getImage(
    JellyfinSession session,
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) async => null;
}
