import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';

class DetailsViewModel extends ChangeNotifier {
  DetailsViewModel({required this.repository, required this.initialItem})
    : _item = initialItem,
      _mainScopeHasSnapshot = initialItem.type != 'CollectionFolder' {
    _itemSubscription = repository
        .watchItem(initialItem.id)
        .listen(_acceptItem);
    if (initialItem.type == 'CollectionFolder') {
      _librarySubscription = repository
          .watchLibraryItems(initialItem.id)
          .listen(_acceptLibraryItems);
    } else if (initialItem.type == 'Series') {
      _seasonsSubscription = repository
          .watchSeasons(initialItem.id)
          .listen(_acceptSeasons);
    }
  }

  bool _disposed = false;
  final JellyfinMetadataRepository repository;
  final JellyfinItem initialItem;
  final Map<String, _ScopeStatus> _statuses = {};
  StreamSubscription<MetadataSnapshot<JellyfinItem>>? _itemSubscription;
  StreamSubscription<MetadataSnapshot<List<JellyfinItem>>>?
  _librarySubscription;
  StreamSubscription<MetadataSnapshot<List<JellyfinItem>>>?
  _seasonsSubscription;
  StreamSubscription<MetadataSnapshot<List<JellyfinItem>>>?
  _episodesSubscription;

  JellyfinItem _item;
  JellyfinItem get item => _item;

  List<JellyfinItem> _libraryItems = const [];
  List<JellyfinItem> get libraryItems => _libraryItems;

  List<JellyfinItem> _seasons = const [];
  List<JellyfinItem> get seasons => _seasons;

  List<JellyfinItem> _episodes = const [];
  List<JellyfinItem> get episodes => _episodes;

  JellyfinItem? _selectedSeason;
  JellyfinItem? get selectedSeason => _selectedSeason;

  bool _mainScopeHasSnapshot;
  bool _refreshing = false;
  bool get refreshing => _refreshing;
  bool get loading => _refreshing && !_mainScopeHasSnapshot;

  bool _loadingEpisodes = false;
  bool get refreshingEpisodes => _loadingEpisodes;
  bool _episodesHaveSnapshot = false;
  bool get loadingEpisodes => _loadingEpisodes && !_episodesHaveSnapshot;

  bool get stale => _statuses.values.any((status) => status.stale);

  String? get error => _statuses.values
      .map((status) => status.errorMessage)
      .whereType<String>()
      .firstOrNull;

  String? get blockingError => _mainScopeHasSnapshot ? null : error;

  Future<void> load() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    _notify();
    final refreshes = <Future<void>>[repository.refreshItem(_item.id)];
    if (_item.type == 'CollectionFolder') {
      refreshes.add(repository.refreshLibraryItems(_item.id));
    } else if (_item.type == 'Series') {
      refreshes.add(repository.refreshSeasons(_item.id));
    }
    try {
      await Future.wait(refreshes);
    } on Object catch (error) {
      _statuses['refresh'] = _ScopeStatus(
        stale: true,
        errorMessage: error is JellyfinApiException
            ? error.message
            : 'Could not load these details.',
      );
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> retry() async {
    if (_disposed) return;
    final season = _selectedSeason;
    await Future.wait([
      load(),
      if (season != null) _refreshEpisodes(season.id),
    ]);
  }

  void _acceptItem(MetadataSnapshot<JellyfinItem> snapshot) {
    if (snapshot.hasSnapshot && snapshot.data != null) {
      _item = snapshot.data!;
    }
    _recordStatus('item', snapshot);
  }

  void _acceptLibraryItems(MetadataSnapshot<List<JellyfinItem>> snapshot) {
    if (snapshot.hasSnapshot) {
      _libraryItems = snapshot.data ?? const [];
      _mainScopeHasSnapshot = true;
    }
    _recordStatus('library', snapshot);
  }

  void _acceptSeasons(MetadataSnapshot<List<JellyfinItem>> snapshot) {
    if (snapshot.hasSnapshot) {
      _seasons = snapshot.data ?? const [];
      final selectedStillExists = _seasons.any(
        (season) => season.id == _selectedSeason?.id,
      );
      if (!selectedStillExists && _seasons.isNotEmpty) {
        unawaited(_selectSeason(_seasons.first));
      }
    }
    _recordStatus('seasons', snapshot);
  }

  void _acceptEpisodes(
    String seasonId,
    MetadataSnapshot<List<JellyfinItem>> snapshot,
  ) {
    if (_selectedSeason?.id != seasonId) return;
    if (snapshot.hasSnapshot) {
      _episodes = snapshot.data ?? const [];
      _episodesHaveSnapshot = true;
    }
    _recordStatus('episodes', snapshot);
  }

  void _recordStatus<T>(String key, MetadataSnapshot<T> snapshot) {
    _statuses[key] = _ScopeStatus(
      stale: snapshot.stale,
      errorMessage: snapshot.errorMessage,
    );
    _notify();
  }

  Future<void> selectSeason(JellyfinItem season) => _selectSeason(season);

  Future<void> _selectSeason(JellyfinItem season) async {
    if (_disposed) return;
    if (_selectedSeason?.id == season.id && _episodesSubscription != null) {
      return;
    }
    final previousSubscription = _episodesSubscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    _selectedSeason = season;
    _episodes = const [];
    _episodesHaveSnapshot = false;
    _loadingEpisodes = true;
    _statuses.remove('episodes');
    final seasonId = season.id;
    _episodesSubscription = repository
        .watchEpisodes(_item.id, seasonId: seasonId)
        .listen((snapshot) => _acceptEpisodes(seasonId, snapshot));
    _notify();
    await _refreshEpisodes(seasonId);
  }

  Future<void> _refreshEpisodes(String seasonId) async {
    if (_disposed) return;
    _loadingEpisodes = true;
    _notify();
    try {
      await repository.refreshEpisodes(_item.id, seasonId: seasonId);
    } on Object catch (error) {
      _statuses['episodes'] = _ScopeStatus(
        stale: true,
        errorMessage: error is JellyfinApiException
            ? error.message
            : 'Could not load this season.',
      );
    } finally {
      if (_selectedSeason?.id == seasonId) {
        _loadingEpisodes = false;
        _notify();
      }
    }
  }

  Duration resumePosition(JellyfinItem item) {
    return Duration(microseconds: item.playbackPositionTicks ~/ 10);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_itemSubscription?.cancel());
    unawaited(_librarySubscription?.cancel());
    unawaited(_seasonsSubscription?.cancel());
    unawaited(_episodesSubscription?.cancel());
    super.dispose();
  }
}

class _ScopeStatus {
  const _ScopeStatus({required this.stale, this.errorMessage});

  final bool stale;
  final String? errorMessage;
}
