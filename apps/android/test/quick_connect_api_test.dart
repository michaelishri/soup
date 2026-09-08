import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'support/quick_connect_fixture.dart';

void main() {
  final url = Uri.parse('https://example.test/jellyfin/');
  test(
    'Quick Connect contract retains subpaths, device headers and secret encoding',
    () async {
      final requests = <http.Request>[];
      final fixture = QuickConnectFixture();
      final client = MockClient((request) async {
        requests.add(request);
        return fixture.respond(request);
      });
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'soup-device');
      expect(await api.isQuickConnectEnabled(url), isTrue);
      final initiated = await api.initiateQuickConnect(url);
      expect(initiated.code, '123456');
      expect(initiated.authenticated, isFalse);
      await api.getQuickConnectState(serverUrl: url, secret: 's+/=&?');
      final session = await api.authenticateWithQuickConnect(
        serverUrl: url,
        secret: 's+/=&?',
      );
      expect(session.serverUrl, url);
      expect(session.userName, 'Quick user');
      expect(session.accessToken, 'test-token');
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /jellyfin/QuickConnect/Enabled',
        'POST /jellyfin/QuickConnect/Initiate',
        'GET /jellyfin/QuickConnect/Connect',
        'POST /jellyfin/Users/AuthenticateWithQuickConnect',
      ]);
      expect(requests[2].url.queryParameters, {'secret': 's+/=&?'});
      expect(jsonDecode(requests[3].body), {'Secret': 's+/=&?'});
      for (final request in requests) {
        expect(
          request.headers['Authorization'],
          contains('DeviceId="soup-device"'),
        );
        expect(request.headers['Authorization'], contains('Client="Soup"'));
        expect(request.headers['Authorization'], contains('Version="0.1.0"'));
        expect(request.headers['Accept'], 'application/json');
      }
    },
  );

  for (final status in [401, 404, 500]) {
    test(
      'preserves HTTP $status without exposing server bodies or secrets',
      () async {
        final client = MockClient(
          (_) async => http.Response('secret-token-private', status),
        );
        addTearDown(client.close);
        final api = JellyfinApi(client, deviceId: 'device');
        for (final request in <Future<Object> Function()>[
          () => api.isQuickConnectEnabled(url),
          () => api.initiateQuickConnect(url),
          () => api.getQuickConnectState(serverUrl: url, secret: 'private'),
          () => api.authenticateWithQuickConnect(
            serverUrl: url,
            secret: 'private',
          ),
        ]) {
          await expectLater(
            request(),
            throwsA(
              isA<JellyfinApiException>()
                  .having((e) => e.statusCode, 'status', status)
                  .having(
                    (e) => e.message,
                    'safe message',
                    isNot(contains('private')),
                  )
                  .having(
                    (e) => e.message,
                    'not password error',
                    isNot(contains('username')),
                  ),
            ),
          );
        }
      },
    );
  }
  for (final body in [
    '{}',
    '{"Code":"123456","Secret":"s"}',
    '{"Authenticated":false,"Code":"","Secret":"s"}',
    '{"Authenticated":false,"Code":"123456","Secret":""}',
    '{"Authenticated":"false","Code":"123456","Secret":"s"}',
    'not-json',
  ]) {
    test('rejects malformed Quick Connect state: $body', () async {
      final client = MockClient((_) async => http.Response(body, 200));
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'device');
      await expectLater(
        api.initiateQuickConnect(url),
        throwsA(isA<JellyfinApiException>()),
      );
      await expectLater(
        api.getQuickConnectState(serverUrl: url, secret: 's'),
        throwsA(isA<JellyfinApiException>()),
      );
    });
  }
  test(
    'rejects empty availability and incomplete authentication responses',
    () async {
      final client = MockClient((_) async => http.Response('', 204));
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'device');
      await expectLater(
        api.isQuickConnectEnabled(url),
        throwsA(isA<JellyfinApiException>()),
      );
      await expectLater(
        api.authenticateWithQuickConnect(serverUrl: url, secret: 's'),
        throwsA(isA<JellyfinApiException>()),
      );
    },
  );
  for (final body in ['{}', '"true"', '1', 'null']) {
    test(
      'malformed availability is an error rather than disabled: $body',
      () async {
        final client = MockClient((_) async => http.Response(body, 200));
        addTearDown(client.close);
        await expectLater(
          JellyfinApi(client, deviceId: 'd').isQuickConnectEnabled(url),
          throwsA(isA<JellyfinApiException>()),
        );
      },
    );
  }
  test('transport exceptions cannot leak polling URL or secret', () async {
    final client = MockClient(
      (request) async =>
          throw http.ClientException('private-token', request.url),
    );
    addTearDown(client.close);
    await expectLater(
      JellyfinApi(
        client,
        deviceId: 'device',
      ).getQuickConnectState(serverUrl: url, secret: 'secret-in-url'),
      throwsA(
        isA<JellyfinApiException>().having(
          (e) => e.message,
          'redacted',
          allOf(
            isNot(contains('private-token')),
            isNot(contains('secret-in-url')),
          ),
        ),
      ),
    );
  });
  testWidgets('availability times out after 15 seconds', (tester) async {
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    addTearDown(client.close);
    final result = expectLater(
      JellyfinApi(client, deviceId: 'd').isQuickConnectEnabled(url),
      throwsA(isA<JellyfinApiException>()),
    );
    await tester.pump(const Duration(seconds: 15));
    await result;
    response.complete(http.Response('true', 200));
    await tester.pump();
  });
}
