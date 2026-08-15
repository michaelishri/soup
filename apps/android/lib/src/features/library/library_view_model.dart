import 'package:flutter/foundation.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel({required this.source, required this.session});

  final JellyfinLibrarySource source;
  final JellyfinSession session;
  final Map<String, Future<Uint8List?>> _images = {};

  JellyfinHome? _home;
  JellyfinHome? get home => _home;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _home = await source.getHome(session);
    } on Object catch (error) {
      _error = error is JellyfinApiException
          ? error.message
          : 'Could not load your Jellyfin library.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> image(
    JellyfinItem item, {
    String type = 'Primary',
    int maxWidth = 480,
  }) {
    final key = '${item.id}:$type:$maxWidth';
    return _images.putIfAbsent(
      key,
      () => source
          .getImage(session, item, type: type, maxWidth: maxWidth)
          .catchError((Object _) => null),
    );
  }
}
