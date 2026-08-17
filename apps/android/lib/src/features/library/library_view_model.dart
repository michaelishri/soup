import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_metadata_repository.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({
    required this.repository,
    required this.artworkSource,
    required this.session,
  }) {
    _homeSubscription = repository.watchHome().listen(_acceptSnapshot);
  }

  final JellyfinMetadataRepository repository;
  final JellyfinLibrarySource artworkSource;
  final JellyfinSession session;
  final Map<String, Future<Uint8List?>> _images = {};
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
    if (_refreshing) return;
    _refreshing = true;
    notifyListeners();
    try {
      await repository.refreshHome();
    } on Object catch (error) {
      _stale = true;
      _error = error is JellyfinApiException
          ? error.message
          : 'Could not load your Jellyfin library.';
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void _acceptSnapshot(MetadataSnapshot<JellyfinHome> snapshot) {
    if (snapshot.hasSnapshot) {
      _home = snapshot.data;
    }
    _hasSnapshot = snapshot.hasSnapshot;
    _stale = snapshot.stale;
    _error = snapshot.errorMessage;
    notifyListeners();
  }

  Future<Uint8List?> image(
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
      () => artworkSource
          .getImage(session, item, type: type, maxWidth: maxWidth)
          .catchError((Object _) => null),
    );
  }

  @override
  void dispose() {
    unawaited(_homeSubscription?.cancel());
    super.dispose();
  }
}
