import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:soup_identity/soup_identity.dart';
import 'package:test/test.dart';

void main() {
  group('HttpSoupIdentityClient', () {
    test('startDeviceLink posts and parses DeviceLinkStart', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/device/link');
          return Response(
            jsonEncode({
              'device_code': 'dc-1',
              'user_code': 'ABCD-EFGH',
              'verification_uri': 'http://identity.test/auth/google/start',
              'verification_uri_complete':
                  'http://identity.test/auth/google/start?user_code=ABCD-EFGH',
              'expires_in': 600,
              'interval': 5,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final start = await client.startDeviceLink();
      expect(start.deviceCode, 'dc-1');
      expect(start.userCode, 'ABCD-EFGH');
      expect(start.interval, 5);
      expect(
        start.verificationUriComplete.queryParameters['user_code'],
        'ABCD-EFGH',
      );
    });

    test('pollDeviceLink returns approved tokens', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test/'),
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/auth/device/link/dc-1');
          return Response(
            jsonEncode({
              'status': 'approved',
              'access_token': 'access',
              'refresh_token': 'refresh',
              'expires_in': 900,
              'token_type': 'Bearer',
              'email': 'a@example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final poll = await client.pollDeviceLink('dc-1');
      expect(poll.status, DeviceLinkStatus.approved);
      expect(poll.tokens?.accessToken, 'access');
      expect(poll.tokens?.email, 'a@example.com');
    });

    test('refreshSession posts refresh_token', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/sessions/refresh');
          expect(jsonDecode(request.body), {'refresh_token': 'old'});
          return Response(
            jsonEncode({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
              'expires_in': 900,
              'token_type': 'Bearer',
              'email': 'a@example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final tokens = await client.refreshSession('old');
      expect(tokens.accessToken, 'new-access');
      expect(tokens.refreshToken, 'new-refresh');
    });

    test('listServers sends Bearer access token', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/v1/me/servers');
          expect(request.headers['authorization'], 'Bearer access');
          return Response(
            jsonEncode({
              'servers': [
                {
                  'id': 'home-jf',
                  'name': 'Home',
                  'audience': 'jellyfin:home-jf',
                  'base_url': null,
                  'magic_dns': 'jellyfin.tailnet.ts.net',
                  'entitlement': {'display_name': 'Dev'},
                  'transport_grant': null,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final roster = await client.listServers('access');
      expect(roster.servers, hasLength(1));
      expect(roster.servers.single.id, 'home-jf');
      expect(roster.servers.single.transportGrant, isNull);
    });

    test('listServers parses claimable transport grant material', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test'),
        httpClient: MockClient((request) async {
          return Response(
            jsonEncode({
              'servers': [
                {
                  'id': 'home-jf',
                  'name': 'Home',
                  'audience': 'jellyfin:home-jf',
                  'transport_grant': {
                    'id': '11111111-1111-1111-1111-111111111111',
                    'grant_type': 'tailscale_auth_key',
                    'expires_at': '2026-09-10T12:00:00Z',
                    'claimed_at': null,
                    'material': 'tskey-auth-example',
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final roster = await client.listServers('access');
      final grant = roster.servers.single.transportGrant;
      expect(grant, isNotNull);
      expect(grant!.isClaimableTailscaleAuthKey, isTrue);
      expect(grant.material, 'tskey-auth-example');
      final claimable = RosterServer.firstClaimableAuthKey(roster.servers);
      expect(claimable?.server.id, 'home-jf');
      expect(claimable?.grant.material, 'tskey-auth-example');
      expect(roster.autoSelected?.id, 'home-jf');
    });

    test('mintAssertion posts server_id with Bearer token', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/assertions');
          expect(request.headers['authorization'], 'Bearer access');
          expect(jsonDecode(request.body), {'server_id': 'home-jf'});
          return Response(
            jsonEncode({
              'assertion': 'jwt.example',
              'expires_in': 180,
              'server_id': 'home-jf',
              'audience': 'jellyfin:home-jf',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      final minted = await client.mintAssertion(
        accessToken: 'access',
        serverId: 'home-jf',
      );
      expect(minted.assertion, 'jwt.example');
      expect(minted.serverId, 'home-jf');
      expect(minted.audience, 'jellyfin:home-jf');
    });

    test('non-2xx becomes SoupIdentityException', () async {
      final client = HttpSoupIdentityClient(
        baseUrl: Uri.parse('http://identity.test'),
        httpClient: MockClient((_) async => Response('{"error":"nope"}', 401)),
      );
      addTearDown(client.close);

      await expectLater(
        client.refreshSession('bad'),
        throwsA(
          isA<SoupIdentityException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });

  group('MockSoupIdentityClient', () {
    test('approves after configured polls and lists servers', () async {
      final client = MockSoupIdentityClient(pollsUntilApproved: 2);
      addTearDown(client.close);

      final start = await client.startDeviceLink();
      expect(
        (await client.pollDeviceLink(start.deviceCode)).status,
        DeviceLinkStatus.pending,
      );
      final approved = await client.pollDeviceLink(start.deviceCode);
      expect(approved.status, DeviceLinkStatus.approved);
      expect(approved.tokens?.accessToken, isNotEmpty);

      final roster = await client.listServers(approved.tokens!.accessToken);
      expect(roster.servers.single.id, 'home-jf');
    });
  });

  group('redactSecrets', () {
    test('strips tskey, bearer, and jwt shapes', () {
      final raw =
          'fail tskey-auth-abc123XYZ Bearer eyJhbGciOiJIUzI1NiJ9.aaa.bbb '
          '{"access_token":"sekrit"}';
      final cleaned = redactSecrets(raw);
      expect(cleaned, isNot(contains('tskey-auth')));
      expect(cleaned, isNot(contains('Bearer eyJ')));
      expect(cleaned, isNot(contains('sekrit')));
      expect(cleaned, contains('[redacted]'));
    });

    test('SoupIdentityException.toString does not echo body', () {
      final err = SoupIdentityException(
        'failed with tskey-auth-leakme',
        statusCode: 500,
        body: '{"material":"tskey-auth-body"}',
      );
      expect(err.toString(), isNot(contains('tskey-auth-leakme')));
      expect(err.toString(), isNot(contains('tskey-auth-body')));
      expect(err.toString(), contains('[redacted]'));
    });
  });
}
