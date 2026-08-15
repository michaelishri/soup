import 'package:flutter/foundation.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController(this._store);

  final AppearanceStore _store;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _saving = false;
  bool get saving => _saving;

  AppearanceSettings? _settings;
  AppearanceSettings? get settings => _settings;
  AppearanceSettings get effectiveSettings =>
      _settings ?? AppearanceSettings.defaults;

  String? _error;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      _settings = await _store.read();
    } on Object {
      _settings = null;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> save(AppearanceSettings settings) async {
    if (_saving) return;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _store.write(settings);
      _settings = settings;
    } on Object {
      _error = 'Could not save your appearance. Try again.';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
