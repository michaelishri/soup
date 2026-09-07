import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';

void main() {
  test('connection choice survives a new store instance', () async {
    final preferences = _Preferences();
    for (final mode in ConnectionMode.values) {
      await SharedPreferencesConnectionStore(preferences).write(mode);
      expect(await SharedPreferencesConnectionStore(preferences).read(), mode);
    }
  });

  test(
    'missing and unknown preferences allow legacy session migration',
    () async {
      final preferences = _Preferences();
      final store = SharedPreferencesConnectionStore(preferences);
      expect(await store.read(), isNull);
      preferences.values[SharedPreferencesConnectionStore.settingsKey] =
          'unknown';
      expect(await store.read(), isNull);
    },
  );
}

class _Preferences extends Fake implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
