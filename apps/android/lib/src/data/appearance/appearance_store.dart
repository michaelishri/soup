import 'package:shared_preferences/shared_preferences.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';

abstract interface class AppearanceStore {
  Future<AppearanceSettings?> read();

  Future<void> write(AppearanceSettings settings);
}

class SharedPreferencesAppearanceStore implements AppearanceStore {
  SharedPreferencesAppearanceStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const settingsKey = 'appearance.settings.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<AppearanceSettings?> read() async {
    final encoded = await _preferences.getString(settingsKey);
    if (encoded == null) return null;
    return AppearanceSettings.tryDecode(encoded) ??
        (throw const FormatException(
          'Your saved appearance could not be read.',
        ));
  }

  @override
  Future<void> write(AppearanceSettings settings) {
    return _preferences.setString(settingsKey, settings.encode());
  }
}

class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.settings]);

  AppearanceSettings? settings;

  @override
  Future<AppearanceSettings?> read() async => settings;

  @override
  Future<void> write(AppearanceSettings value) async => settings = value;
}
