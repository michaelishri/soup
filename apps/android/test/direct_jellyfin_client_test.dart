import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';

void main() {
  test('Tailscale mode never falls back to a direct connection', () {
    expect(
      () => const DefaultJellyfinClientFactory().create(
        mode: ConnectionMode.tailscale,
      ),
      throwsStateError,
    );
  });

  for (final secure in [false, true]) {
    test(
      'direct ${secure ? 'HTTPS' : 'HTTP'} reaches the server without SOCKS',
      () async {
        final serverContext = SecurityContext()
          ..useCertificateChain('test/fixtures/localhost-cert.pem')
          ..usePrivateKey('test/fixtures/localhost-key.pem');
        final server = secure
            ? await HttpServer.bindSecure(
                InternetAddress.loopbackIPv4,
                0,
                serverContext,
              )
            : await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          request.response.write('direct');
          await request.response.close();
        });
        final trust = SecurityContext()
          ..setTrustedCertificates('test/fixtures/localhost-cert.pem');
        final client = DefaultJellyfinClientFactory(
          securityContext: trust,
        ).create(mode: ConnectionMode.direct);
        addTearDown(() async {
          client.close();
          await server.close(force: true);
          await subscription.cancel();
        });
        final response = await client.get(
          Uri.parse(
            '${secure ? 'https' : 'http'}://localhost:${server.port}/health',
          ),
        );
        expect(response.body, 'direct');
      },
    );
  }

  test('direct HTTPS rejects an untrusted certificate', () async {
    final context = SecurityContext()
      ..useCertificateChain('test/fixtures/localhost-cert.pem')
      ..usePrivateKey('test/fixtures/localhost-key.pem');
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    final subscription = server.listen(
      (request) async => request.response.close(),
    );
    final client = const DefaultJellyfinClientFactory().create(
      mode: ConnectionMode.direct,
    );
    addTearDown(() async {
      client.close();
      await server.close(force: true);
      await subscription.cancel();
    });
    await expectLater(
      client.get(Uri.parse('https://localhost:${server.port}/')),
      throwsA(isA<Exception>()),
    );
  });
}
