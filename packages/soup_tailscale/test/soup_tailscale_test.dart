import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:soup_tailscale/src/local_api.dart';
import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:test/test.dart';

void main() {
  test(
    'stalled LocalAPI body times out and a later request can recover',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final subscription = server.listen((request) async {
        requests++;
        if (requests == 1) {
          request.response.write('{');
          await request.response.flush();
        } else {
          request.response.write('{"BackendState":"Running"}');
          await request.response.close();
        }
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final client = TailscaleLocalApiClient(
        address: '${server.address.address}:${server.port}',
        credential: 'test-only',
        requestTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(client.status(), throwsA(isA<TimeoutException>()));
      expect((await client.status()).backendState, 'Running');
    },
  );

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

  test('waitUntilConnected resolves for an already-connected status', () async {
    final client = _RecordingTailscaleClient()
      ..emit(
        const TailscaleStatus.connected(
          hostname: 'soup',
          tailnetIp: '100.64.0.1',
          proxy: TailscaleProxy(
            host: '127.0.0.1',
            port: 1,
            password: 'secret',
          ),
        ),
      );

    final status = await client.waitUntilConnected(
      timeout: const Duration(seconds: 1),
    );
    expect(status.phase, TailscaleConnectionPhase.connected);
  });

  test('waitUntilConnected throws when status becomes failed', () async {
    final client = _RecordingTailscaleClient()
      ..emit(const TailscaleStatus.failed('bad key'));

    await expectLater(
      client.waitUntilConnected(timeout: const Duration(seconds: 1)),
      throwsA(
        isA<TailscaleException>().having(
          (e) => e.message,
          'message',
          'bad key',
        ),
      ),
    );
  });

  test('redactNativeSecrets strips tskey material', () {
    expect(
      redactNativeSecrets('up failed: tskey-auth-abcDEF123'),
      isNot(contains('tskey-auth')),
    );
    expect(
      redactNativeSecrets('up failed: tskey-auth-abcDEF123'),
      contains('[redacted]'),
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

class _RecordingTailscaleClient implements TailscaleClient {
  final _statuses = StreamController<TailscaleStatus>.broadcast(sync: true);
  TailscaleStatus _status = const TailscaleStatus.disconnected();

  void emit(TailscaleStatus value) {
    _status = value;
    if (!_statuses.isClosed) _statuses.add(value);
  }

  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;

  @override
  TailscaleStatus get status => _status;

  @override
  Future<void> restore() async {}

  @override
  Future<void> connectInteractively() async {}

  @override
  Future<void> connectWithAuthKey({required String authKey}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<TailscalePeer>> peers() async => const [];

  @override
  TailscaleDatagramSession openDatagrams() =>
      throw UnsupportedError('No datagrams in test client');
}

