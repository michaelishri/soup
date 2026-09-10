import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/soup/soup_session_store.dart';
import 'package:soup_identity/soup_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Soup session round trips with optional lastServerId', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureSoupSessionStore();
    final session = SoupSession.fromTokens(
      const SoupSessionTokens(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresIn: 900,
        tokenType: 'Bearer',
        googleSub: 'sub-1',
        email: 'a@b.c',
      ),
      lastServerId: 'home-jf',
      issuedAt: DateTime.utc(2026, 9, 10, 6),
    );
    await store.write(session);
    final reopened = await const SecureSoupSessionStore().read();
    expect(reopened?.accessToken, 'access');
    expect(reopened?.refreshToken, 'refresh');
    expect(reopened?.googleSub, 'sub-1');
    expect(reopened?.lastServerId, 'home-jf');
    expect(reopened?.accessExpiresAt, DateTime.utc(2026, 9, 10, 6, 15));
  });

  test('corrupt Soup session throws without clearing storage', () async {
    FlutterSecureStorage.setMockInitialValues({
      'soup.session': jsonEncode({'accessToken': ''}),
    });
    await expectLater(
      const SecureSoupSessionStore().read(),
      throwsFormatException,
    );
    expect(
      await const FlutterSecureStorage().read(key: 'soup.session'),
      isNotEmpty,
    );
  });

  test('Jellyfin session key is not shared with Soup store', () async {
    FlutterSecureStorage.setMockInitialValues({
      'jellyfin.session': jsonEncode({
        'serverUrl': 'http://jellyfin:8096',
        'serverId': 'server-1',
        'userId': 'user-1',
        'userName': 'Michael',
        'accessToken': 'jf-token',
      }),
    });
    expect(await const SecureSoupSessionStore().read(), isNull);
  });

  test('storage read errors are propagated', () async {
    final store = SecureSoupSessionStore(_UnavailableStorage());
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
