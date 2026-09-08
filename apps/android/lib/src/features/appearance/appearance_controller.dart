import 'package:flutter/foundation.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController(this._store);

  final AppearanceStore _store;
  bool _disposed = false;
  bool _loading = false;
  String? _loadError;
  String? get loadError => _loadError;

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
    if (_disposed || _loading || _initialized) return;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final settings = await _store.read();
      if (_disposed) return;
      _settings = settings;
      _initialized = true;
    } on Object {
      _loadError = 'Could not load your saved appearance. Please try again.';
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> save(AppearanceSettings settings) async {
    if (_disposed || !_initialized || _saving) return;
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
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
