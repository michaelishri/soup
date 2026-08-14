import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

void main() {
  test('normalises a server URL with a Jellyfin base path', () {
    expect(
      JellyfinApi.parseServerUrl('media.example/jellyfin').toString(),
      'http://media.example/jellyfin/',
    );
  });

  test(
    'uses the current MediaBrowser header and typed 10.11 response',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ServerName":"Home","Version":"10.11.3","Id":"server"}',
          200,
        );
      });
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'device-id');

      final info = await api.getPublicSystemInfo(
        Uri.parse('https://media.example/jellyfin/'),
      );

      expect(captured.url.path, '/jellyfin/System/Info/Public');
      expect(captured.headers['authorization'], contains('Client="Soup"'));
      expect(
        captured.headers['authorization'],
        contains('DeviceId="device-id"'),
      );
      expect(info.name, 'Home');
      expect(info.supportsSoup, isTrue);
    },
  );

  test(
    'authenticates with the 10.11 endpoint and returns a typed session',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"AccessToken":"secret-token","ServerId":"server","User":{"Id":"user","Name":"Alex"}}',
          200,
        );
      });
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'device-id');

      final session = await api.authenticate(
        serverUrl: Uri.parse('http://jellyfin:8096/'),
        username: 'Alex',
        password: 'password',
      );

      expect(captured.url.path, '/Users/AuthenticateByName');
      expect(jsonDecode(captured.body), {'Username': 'Alex', 'Pw': 'password'});
      expect(session.accessToken, 'secret-token');
      expect(session.userName, 'Alex');
    },
  );

  test('rejects a Jellyfin server older than 10.11', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"ServerName":"Old","Version":"10.10.7","Id":"server"}',
        200,
      ),
    );
    addTearDown(client.close);

    expect(
      () => JellyfinApi(
        client,
        deviceId: 'device',
      ).getPublicSystemInfo(Uri.parse('http://jellyfin/')),
      throwsA(isA<JellyfinApiException>()),
    );
  });
}
