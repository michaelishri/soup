import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/session/session_store.dart';

import 'support/connectivity_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only an absent saved session means first use', () async {
    FlutterSecureStorage.setMockInitialValues({});
    expect(await const SecureSessionStore().read(), isNull);
    for (final encoded in [
      'not-json',
      '{}',
      '[]',
      jsonEncode({
        'serverUrl': '',
        'serverId': 'server-1',
        'userId': 'user-1',
        'accessToken': 'token',
      }),
    ]) {
      FlutterSecureStorage.setMockInitialValues({'jellyfin.session': encoded});
      await expectLater(
        const SecureSessionStore().read(),
        throwsFormatException,
      );
      expect(
        await const FlutterSecureStorage().read(key: 'jellyfin.session'),
        encoded,
      );
    }
  });

  test('saved account round trips across store instances', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await const SecureSessionStore().write(testSession);
    final reopened = await const SecureSessionStore().read();
    expect(reopened?.serverUrl, testSession.serverUrl);
    expect(reopened?.serverId, testSession.serverId);
    expect(reopened?.userId, testSession.userId);
    expect(reopened?.accessToken, testSession.accessToken);
  });

  test('storage read errors are propagated', () async {
    final store = SecureSessionStore(_UnavailableStorage());
    await expectLater(store.read(), throwsA(isA<PlatformException>()));
  });
}

class _UnavailableStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => Future.error(PlatformException(code: 'unavailable'));
}
