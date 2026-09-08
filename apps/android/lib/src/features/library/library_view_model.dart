import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soup/src/data/artwork/artwork_cache.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required this.repository,
    required this.session,
    this.artworkRepository,
  }) {
    _homeSubscription = repository.watchHome().listen(_acceptSnapshot);
  }

  bool _disposed = false;
  final JellyfinMetadataRepository repository;
  final ArtworkRepository? artworkRepository;
  final JellyfinSession session;
  final Map<String, Future<CachedArtwork?>> _images = {};
  final Set<String> _prefetchedImages = {};
  StreamSubscription<MetadataSnapshot<JellyfinHome>>? _homeSubscription;

  JellyfinHome? _home;
  JellyfinHome? get home => _home;

  bool _hasSnapshot = false;
  bool get hasSnapshot => _hasSnapshot;

  bool _refreshing = false;
  bool get refreshing => _refreshing;
  bool get loading => _refreshing && !_hasSnapshot;

  bool _stale = false;
  bool get stale => _stale;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    _notify();
    try {
      await repository.refreshHome();
    } on Object catch (error) {
      _stale = true;
      _error = error is JellyfinApiException
          ? error.message
          : 'Could not load your Jellyfin library.';
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  void _acceptSnapshot(MetadataSnapshot<JellyfinHome> snapshot) {
    if (snapshot.hasSnapshot) {
      _home = snapshot.data;
    }
    _hasSnapshot = snapshot.hasSnapshot;
    _stale = snapshot.stale;
    _error = snapshot.errorMessage;
    _notify();
  }

  Future<CachedArtwork?> image(
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) {
    final tag = type == 'Backdrop'
        ? item.backdropImageTag
        : item.primaryImageTag;
    final key = '${item.id}:$type:$maxWidth:$tag';
    return _images.putIfAbsent(
      key,
      () =>
          artworkRepository
              ?.getArtwork(item, type: type, maxWidth: maxWidth)
              .catchError((Object _) => null) ??
          Future.value(),
    );
  }

  void prefetchArtwork(
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) {
    final repository = artworkRepository;
    if (repository == null) return;
    final tag = type == 'Backdrop'
        ? item.backdropImageTag
        : item.primaryImageTag;
    if (tag == null || tag.isEmpty) return;
    final key = '${item.id}:$type:$maxWidth:$tag';
    if (!_prefetchedImages.add(key)) return;
    repository.prefetch(item, type: type, maxWidth: maxWidth);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_homeSubscription?.cancel());
    super.dispose();
  }
}
