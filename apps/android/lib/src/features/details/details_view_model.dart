import 'package:flutter/foundation.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

class DetailsViewModel extends ChangeNotifier {
  DetailsViewModel({
    required this.source,
    required this.session,
    required this.initialItem,
  }) : _item = initialItem;

  final JellyfinDetailsSource source;
  final JellyfinSession session;
  final JellyfinItem initialItem;

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

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingEpisodes = false;
  bool get loadingEpisodes => _loadingEpisodes;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_item.type == 'CollectionFolder') {
        _libraryItems = await source.getLibraryItems(session, _item.id);
      } else {
        _item = await source.getItem(session, _item.id);
        if (_item.type == 'Series') {
          _seasons = await source.getSeasons(session, _item.id);
          if (_seasons.isNotEmpty) {
            await _selectSeason(_seasons.first, notify: false);
          }
        }
      }
    } on Object catch (error) {
      _error = error is JellyfinApiException
          ? error.message
          : 'Could not load these details.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectSeason(JellyfinItem season) {
    return _selectSeason(season, notify: true);
  }

  Future<void> _selectSeason(
    JellyfinItem season, {
    required bool notify,
  }) async {
    if (_loadingEpisodes || _selectedSeason?.id == season.id) return;
    _selectedSeason = season;
    _episodes = const [];
    _loadingEpisodes = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      _episodes = await source.getEpisodes(
        session,
        _item.id,
        seasonId: season.id,
      );
    } on Object catch (error) {
      _error = error is JellyfinApiException
          ? error.message
          : 'Could not load this season.';
    } finally {
      _loadingEpisodes = false;
      if (notify) notifyListeners();
    }
  }

  Duration resumePosition(JellyfinItem item) {
    return Duration(microseconds: item.playbackPositionTicks ~/ 10);
  }
}
