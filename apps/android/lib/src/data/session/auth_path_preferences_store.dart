import 'package:shared_preferences/shared_preferences.dart';

/// How the user enters Soup when Identity auth is compiled in.
///
/// Default when unset is [AuthPath.soup] (device-link). Direct Jellyfin login
/// (with or without Tailscale) is an explicit opt-in.
enum AuthPath {
  /// Google device-link via Soup Identity (default).
  soup,

  /// Legacy ConnectivityScreen: Tailscale toggle + Jellyfin credentials.
  direct,
}

abstract interface class AuthPathPreferencesStore {
  Future<AuthPath?> read();
  Future<void> write(AuthPath path);
}

class SharedPreferencesAuthPathStore implements AuthPathPreferencesStore {
  SharedPreferencesAuthPathStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const settingsKey = 'auth.path.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<AuthPath?> read() async {
    final value = await _preferences.getString(settingsKey);
    for (final path in AuthPath.values) {
      if (path.name == value) return path;
    }
    return null;
  }

  @override
  Future<void> write(AuthPath path) =>
      _preferences.setString(settingsKey, path.name);
}

class MemoryAuthPathStore implements AuthPathPreferencesStore {
  MemoryAuthPathStore([this.path]);
  AuthPath? path;

  @override
  Future<AuthPath?> read() async => path;

  @override
  Future<void> write(AuthPath value) async => path = value;
}
