import 'dart:convert';
import 'dart:io';

import 'package:soup_tailscale/src/local_api.dart';
import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:test/test.dart';

void main() {
  test('unavailable adapter reports disconnected', () {
    final client = UnavailableTailscaleClient();

    expect(client.status.phase, TailscaleConnectionPhase.disconnected);
  });

  test('unavailable adapter fails clearly when connection is attempted', () {
    final client = UnavailableTailscaleClient();

    expect(
      client.connectWithAuthKey(authKey: 'tskey-auth-example'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('unavailable adapter rejects interactive registration clearly', () {
    final client = UnavailableTailscaleClient();

    expect(client.connectInteractively(), throwsA(isA<UnsupportedError>()));
  });

  test('parses the authenticated loopback proxy', () {
    final proxy = TailscaleProxy.parse('127.0.0.1:32145', 'secret');

    expect(proxy.host, '127.0.0.1');
    expect(proxy.port, 32145);
    expect(proxy.password, 'secret');
    expect(TailscaleProxy.username, 'tsnet');
  });

  test('parses login and approval backend states', () {
    final login = TailscaleBackendStatus.fromJson({
      'BackendState': 'NeedsLogin',
      'AuthURL': 'https://login.tailscale.com/a/example',
    });
    final approval = TailscaleBackendStatus.fromJson({
      'BackendState': 'NeedsMachineAuth',
    });

    expect(login.backendState, 'NeedsLogin');
    expect(
      login.authorizationUrl,
      Uri.parse('https://login.tailscale.com/a/example'),
    );
    expect(approval.backendState, 'NeedsMachineAuth');
    expect(approval.authorizationUrl, isNull);
  });

  test('rejects non-HTTPS authorization URLs', () {
    final status = TailscaleBackendStatus.fromJson({
      'BackendState': 'NeedsLogin',
      'AuthURL': 'http://example.test/not-safe',
    });

    expect(status.authorizationUrl, isNull);
  });

  test('LocalAPI client authenticates login and status requests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    final subscription = server.listen((request) async {
      requests.add('${request.method} ${request.uri.path}');
      expect(request.headers.value('Sec-Tailscale'), 'localapi');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Basic ${base64Encode(utf8.encode(':local-secret'))}',
      );
      if (request.uri.path.endsWith('status')) {
        request.response.write(
          jsonEncode({
            'BackendState': 'NeedsLogin',
            'AuthURL': 'https://login.tailscale.com/a/example',
          }),
        );
      }
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });
    final client = TailscaleLocalApiClient(
      address: '${server.address.address}:${server.port}',
      credential: 'local-secret',
    );

    await client.startInteractiveLogin();
    final status = await client.status();

    expect(requests, [
      'POST /localapi/v0/login-interactive',
      'GET /localapi/v0/status',
    ]);
    expect(status.backendState, 'NeedsLogin');
  });
}
