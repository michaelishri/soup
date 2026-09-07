import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socks5_proxy/socks_server.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

void main() {
  test(
    'routes HTTP through the authenticated Tailscale-style SOCKS5 proxy',
    () async {
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final targetSubscription = target.listen((request) async {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('through-socks');
        await request.response.close();
      });

      var authenticated = false;
      final proxy = SocksServer(
        authHandler: (username, password) {
          authenticated =
              username == TailscaleProxy.username &&
              password == 'loopback-secret';
          return authenticated;
        },
      );
      await proxy.bind(InternetAddress.loopbackIPv4, 0);
      final connectionSubscription = proxy.connections.listen(
        (connection) => unawaited(connection.forward()),
      );
      final proxyPort = proxy.proxies.keys.single;
      final client = const DefaultJellyfinClientFactory().create(
        mode: ConnectionMode.tailscale,
        proxy: TailscaleProxy(
          host: InternetAddress.loopbackIPv4.address,
          port: proxyPort,
          password: 'loopback-secret',
        ),
      );

      try {
        final response = await client.get(
          Uri.parse('http://${target.address.address}:${target.port}/health'),
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, 'through-socks');
        expect(authenticated, isTrue);
      } finally {
        client.close();
        await connectionSubscription.cancel();
        await proxy.stop();
        await target.close(force: true);
        await targetSubscription.cancel();
      }
    },
  );

  test('routes HTTPS through authenticated SOCKS5 and performs TLS', () async {
    final serverContext = SecurityContext()
      ..useCertificateChain('test/fixtures/localhost-cert.pem')
      ..usePrivateKey('test/fixtures/localhost-key.pem');
    final target = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      serverContext,
    );
    final targetSubscription = target.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('tls-through-socks');
      await request.response.close();
    });

    var authenticated = false;
    final proxy = SocksServer(
      authHandler: (username, password) {
        authenticated =
            username == TailscaleProxy.username &&
            password == 'loopback-secret';
        return authenticated;
      },
    );
    await proxy.bind(InternetAddress.loopbackIPv4, 0);
    final connectionSubscription = proxy.connections.listen(
      (connection) => unawaited(connection.forward()),
    );
    var sawTestCertificate = false;
    final client =
        DefaultJellyfinClientFactory(
          badCertificateCallback: (certificate) {
            sawTestCertificate = certificate.subject.contains('CN=localhost');
            return sawTestCertificate;
          },
        ).create(
          mode: ConnectionMode.tailscale,
          proxy: TailscaleProxy(
            host: InternetAddress.loopbackIPv4.address,
            port: proxy.proxies.keys.single,
            password: 'loopback-secret',
          ),
        );

    try {
      final response = await client.get(
        Uri.parse('https://127.0.0.1:${target.port}/health'),
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, 'tls-through-socks');
      expect(authenticated, isTrue);
      expect(sawTestCertificate, isTrue);
    } finally {
      client.close();
      await connectionSubscription.cancel();
      await proxy.stop();
      await target.close(force: true);
      await targetSubscription.cancel();
    }
  });
}
