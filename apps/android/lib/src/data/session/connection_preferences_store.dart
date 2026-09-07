import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionMode { direct, tailscale }

abstract interface class ConnectionPreferencesStore {
  Future<ConnectionMode?> read();
  Future<void> write(ConnectionMode mode);
}

class SharedPreferencesConnectionStore implements ConnectionPreferencesStore {
  SharedPreferencesConnectionStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const settingsKey = 'connection.mode.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<ConnectionMode?> read() async {
    final value = await _preferences.getString(settingsKey);
    for (final mode in ConnectionMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  @override
  Future<void> write(ConnectionMode mode) =>
      _preferences.setString(settingsKey, mode.name);
}

class MemoryConnectionPreferencesStore implements ConnectionPreferencesStore {
  MemoryConnectionPreferencesStore([this.mode]);
  ConnectionMode? mode;

  @override
  Future<ConnectionMode?> read() async => mode;

  @override
  Future<void> write(ConnectionMode value) async => mode = value;
}
