import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:soup_tailscale/src/datagrams.dart';
import 'package:soup_tailscale/src/peers.dart';
import 'package:test/test.dart';

void main() {
  test('peer status tolerates missing fields and prioritizes online peers', () {
    final peers = TailscalePeer.parse({
      'offline': {
        'TailscaleIPs': ['100.64.0.2', 'bad', '::1'],
      },
      'online': {
        'TailscaleIPs': ['100.64.0.3', 'fd7a:115c:a1e0::3'],
        'DNSName': 'media.example.ts.net.',
        'Online': true,
      },
      'invalid': {'TailscaleIPs': '100.64.0.4'},
    });
    expect(peers.map((peer) => peer.id), ['online', 'offline']);
    expect(peers.first.dnsName, 'media.example.ts.net');
    expect(peers.first.addresses, hasLength(2));
    expect(peers.last.addresses, hasLength(1));
    expect(TailscalePeer.parse(null), isEmpty);
  });

  test(
    'UDP decoding rejects fragments, truncated headers and oversized packets',
    () {
      for (final bytes in [
        <int>[],
        [0, 0, 1, 1, 100, 64, 0, 2, 28, 191],
        [0, 0, 0, 4, 0],
        List<int>.filled(8193, 0),
      ]) {
        expect(
          Socks5DatagramSession.decodePacket(Uint8List.fromList(bytes)),
          isNull,
        );
      }
      final packet = Socks5DatagramSession.decodePacket(
        Uint8List.fromList([0, 0, 0, 1, 100, 64, 0, 2, 28, 191, 123, 125]),
      );
      expect(packet!.address.address, '100.64.0.2');
      expect(packet.port, 7359);
      expect(utf8.decode(packet.data), '{}');
    },
  );

  test(
    'authenticated UDP association round trips and cancellation closes control socket',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final relay = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(server.close);
      addTearDown(relay.close);
      final controlClosed = Completer<void>();
      final serverDone = Completer<void>();
      server.listen((socket) async {
        try {
          final iterator = StreamIterator(socket);
          final buffer = <int>[];
          Future<List<int>> read(int count) async {
            while (buffer.length < count) {
              if (!await iterator.moveNext()) throw StateError('closed');
              buffer.addAll(iterator.current);
            }
            final result = buffer.sublist(0, count);
            buffer.removeRange(0, count);
            return result;
          }

          expect(await read(3), [5, 1, 2]);
          // Deliberately split handshake frames across TCP writes.
          socket.add([5]);
          await socket.flush();
          socket.add([2]);
          expect(await read(2), [1, 5]);
          expect(utf8.decode(await read(5)), 'tsnet');
          expect(await read(1), [6]);
          expect(utf8.decode(await read(6)), 'secret');
          socket.add([1, 0]);
          final associate = await read(10);
          expect(associate.take(8), [5, 3, 0, 1, 127, 0, 0, 1]);
          socket.add([
            5,
            0,
            0,
            1,
            127,
            0,
            0,
            1,
            relay.port >> 8,
            relay.port & 255,
          ]);
          while (await iterator.moveNext()) {}
          controlClosed.complete();
          socket.destroy();
          serverDone.complete();
        } on Object catch (error, stack) {
          serverDone.completeError(error, stack);
        }
      });
      relay.listen((event) {
        if (event != RawSocketEvent.read) return;
        final packet = relay.receive()!;
        expect(packet.data.take(10), [0, 0, 0, 1, 100, 64, 0, 2, 28, 191]);
        expect(
          utf8.decode(packet.data.skip(10).toList()),
          'Who is JellyfinServer?',
        );
        relay.send(
          [...packet.data.take(10), ...utf8.encode('{}')],
          packet.address,
          packet.port,
        );
      });
      final session = Socks5DatagramSession(
        host: '127.0.0.1',
        port: server.port,
        username: 'tsnet',
        password: 'secret',
      );
      addTearDown(session.close);
      final response = session.datagrams.first;
      await session.ready;
      session.send(
        utf8.encode('Who is JellyfinServer?'),
        InternetAddress('100.64.0.2'),
        7359,
      );
      expect(utf8.decode((await response).data), '{}');
      session.close();
      await controlClosed.future.timeout(const Duration(seconds: 1));
      await serverDone.future;
    },
  );

  test('stalled handshake times out and releases TCP socket', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final closed = Completer<void>();
    server.listen((socket) {
      socket.listen(
        (_) {},
        onDone: () {
          socket.destroy();
          closed.complete();
        },
      );
    });
    final session = Socks5DatagramSession(
      host: '127.0.0.1',
      port: server.port,
      username: 'tsnet',
      password: 'secret',
      handshakeTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(session.close);
    await expectLater(session.ready, throwsA(isA<TimeoutException>()));
    await closed.future.timeout(const Duration(seconds: 1));
  });
}
