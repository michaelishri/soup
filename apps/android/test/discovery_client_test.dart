import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socks5_proxy/socks_server.dart';
import 'package:soup/src/data/jellyfin/discovery_client_factory.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

void main() {
  Future<TailscaleProxy> startProxy() async {
    final proxy = SocksServer(
      authHandler: (username, password) =>
          username == 'tsnet' && password == 'fixture-secret',
    );
    await proxy.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = proxy.connections.listen((connection) {
      unawaited(connection.forward().catchError((Object _) {}));
    });
    addTearDown(() async {
      await subscription.cancel();
      await proxy.stop();
    });
    return TailscaleProxy(
      host: '127.0.0.1',
      port: proxy.proxies.keys.single,
      password: 'fixture-secret',
    );
  }

  for (final secure in [false, true]) {
    test(
      'discovery ${secure ? 'HTTPS' : 'HTTP'} uses SOCKS, preserving path and certificate checks',
      () async {
        final context = SecurityContext()
          ..useCertificateChain('test/fixtures/localhost-cert.pem')
          ..usePrivateKey('test/fixtures/localhost-key.pem');
        final target = secure
            ? await HttpServer.bindSecure(
                InternetAddress.loopbackIPv4,
                0,
                context,
              )
            : await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => target.close(force: true));
        target.listen((request) async {
          expect(request.uri.path, '/jellyfin/System/Info/Public');
          expect(request.headers.value('Authorization'), isNull);
          request.response.write('{"ok":true}');
          await request.response.close();
        });
        final trust = SecurityContext()
          ..setTrustedCertificates('test/fixtures/localhost-cert.pem');
        final client = DiscoveryJellyfinClientFactory(
          securityContext: trust,
        ).create(mode: ConnectionMode.tailscale, proxy: await startProxy());
        addTearDown(client.close);
        final response = await client
            .get(
              Uri.parse(
                '${secure ? 'https' : 'http'}://127.0.0.1:${target.port}/jellyfin/System/Info/Public',
              ),
            )
            .timeout(const Duration(seconds: 3));
        expect(response.statusCode, 200);
        expect(response.body, '{"ok":true}');
      },
    );
  }

  test('cancellation closes a stalled SOCKS handshake immediately', () async {
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(proxy.close);
    final started = Completer<void>();
    final closed = Completer<void>();
    proxy.listen((socket) {
      socket.listen(
        (_) {
          if (!started.isCompleted) started.complete();
        },
        onDone: () {
          socket.destroy();
          closed.complete();
        },
      );
    });
    final client = const DiscoveryJellyfinClientFactory().create(
      mode: ConnectionMode.tailscale,
      proxy: TailscaleProxy(
        host: '127.0.0.1',
        port: proxy.port,
        password: 'fixture-secret',
      ),
    );
    final response = client.get(
      Uri.parse('https://media.example.ts.net/System/Info/Public'),
    );
    final failure = expectLater(response, throwsA(isA<Exception>()));
    await started.future.timeout(const Duration(seconds: 2));
    client.close();
    await closed.future.timeout(const Duration(seconds: 1));
    await failure;
  });

  test('cancellation closes a stalled TLS handshake immediately', () async {
    final target = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(target.close);
    final started = Completer<void>();
    final closed = Completer<void>();
    target.listen((socket) {
      socket.listen(
        (_) {
          if (!started.isCompleted) started.complete();
        },
        onDone: () {
          socket.destroy();
          closed.complete();
        },
      );
    });
    final client = const DiscoveryJellyfinClientFactory().create(
      mode: ConnectionMode.tailscale,
      proxy: await startProxy(),
    );
    final response = client.get(
      Uri.parse('https://127.0.0.1:${target.port}/System/Info/Public'),
    );
    final failure = expectLater(response, throwsA(isA<Exception>()));
    await started.future.timeout(const Duration(seconds: 2));
    client.close();
    await closed.future.timeout(const Duration(seconds: 1));
    await failure;
  });

  test('untrusted TLS certificates are rejected', () async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/localhost-cert.pem')
      ..usePrivateKey('test/fixtures/localhost-key.pem');
    final target = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    target.listen((request) => request.response.close());
    addTearDown(() => target.close(force: true));
    final client = const DiscoveryJellyfinClientFactory().create(
      mode: ConnectionMode.tailscale,
      proxy: await startProxy(),
    );
    addTearDown(client.close);
    await expectLater(
      client.get(
        Uri.parse('https://127.0.0.1:${target.port}/System/Info/Public'),
      ),
      throwsA(
        predicate(
          (error) => error.toString().contains('CERTIFICATE_VERIFY_FAILED'),
        ),
      ),
    );
  });
}
