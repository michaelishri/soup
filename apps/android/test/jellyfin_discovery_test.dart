import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_discovery.dart';
import 'package:soup/src/data/jellyfin/lan_discovery.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';

class FakeLanDiscovery implements LanDiscoverySession {
  final events = StreamController<Datagram>();
  void Function()? onBroadcast;
  bool closed = false;
  int sends = 0;
  @override
  Future<void> get ready async {}
  @override
  Stream<Datagram> get datagrams => events.stream;
  @override
  void broadcast(List<int> bytes) {
    if (!closed) {
      sends++;
      onBroadcast?.call();
    }
  }

  void announce(
    String address, {
    String sender = '192.168.1.8',
    String id = 'server-1',
  }) {
    if (!closed) {
      events.add(
        Datagram(
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({'Address': address, 'Id': id, 'Name': 'Media'}),
            ),
          ),
          InternetAddress(sender),
          7359,
        ),
      );
    }
  }

  @override
  void close() {
    if (!closed) {
      closed = true;
      unawaited(events.close());
    }
  }
}

class FakeDiscoveryUdp implements TailscaleDatagramSession {
  final events = StreamController<TailscaleDatagram>();
  bool closed = false;
  int sends = 0;
  @override
  Future<void> get ready async {}
  @override
  Stream<TailscaleDatagram> get datagrams => events.stream;
  @override
  void send(List<int> data, InternetAddress address, int port) {
    if (!closed) sends++;
  }

  @override
  void close() {
    if (!closed) {
      closed = true;
      unawaited(events.close());
    }
  }
}

class DiscoveryTailnet extends UnavailableTailscaleClient {
  List<TailscalePeer> visible = [];
  final udp = FakeDiscoveryUdp();
  @override
  Future<List<TailscalePeer>> peers() async => visible;
  @override
  TailscaleDatagramSession openDatagrams() => udp;
}

const shortLimits = DiscoveryLimits(
  total: Duration(milliseconds: 200),
  udpWindow: Duration(milliseconds: 20),
  repeat: Duration(milliseconds: 5),
  probe: Duration(milliseconds: 30),
);

void main() {
  test(
    'overall deadline closes all eight active probes and never starts queued work',
    () async {
      final tailnet = DiscoveryTailnet()
        ..visible = List.generate(
          8,
          (i) => TailscalePeer(
            id: '$i',
            hostname: 'media',
            addresses: [InternetAddress('100.64.0.${i + 1}')],
          ),
        );
      final response = Completer<http.Response>();
      final clients = FakeJellyfinClientFactory(
        respond: (_) => response.future,
      );
      final run =
          DefaultJellyfinDiscoveryService(
            tailscale: tailnet,
            clients: clients,
            openLan: FakeLanDiscovery.new,
            limits: const DiscoveryLimits(
              total: Duration(milliseconds: 100),
              udpWindow: Duration(milliseconds: 10),
              repeat: Duration(milliseconds: 2),
              probe: Duration(seconds: 1),
            ),
          ).start(
            ConnectionMode.tailscale,
            FakeTailscaleClient.connectedStatus.proxy,
          );
      final result = (await run.snapshots.toList()).last;
      expect(result.phase, DiscoveryPhase.partial);
      expect(clients.requests, hasLength(8));
      expect(clients.closed, 8);
      expect(tailnet.udp.closed, isTrue);
      response.complete(http.Response('', 404));
      await Future<void>.delayed(Duration.zero);
      expect(clients.requests, hasLength(8));
    },
  );

  test(
    'directed tailnet discovery validates a custom advertised base path',
    () async {
      final tailnet = DiscoveryTailnet()
        ..visible = [
          TailscalePeer(
            id: 'peer',
            hostname: 'media',
            addresses: [InternetAddress('100.64.0.8')],
          ),
        ];
      final clients = FakeJellyfinClientFactory(
        respond: (request) =>
            request.url.toString() ==
                'http://100.64.0.8:8888/jellyfin/System/Info/Public'
            ? FakeJellyfinClientFactory.defaultResponse(request)
            : http.Response('', 404),
      );
      final run =
          DefaultJellyfinDiscoveryService(
            tailscale: tailnet,
            clients: clients,
            openLan: FakeLanDiscovery.new,
            limits: shortLimits,
          ).start(
            ConnectionMode.tailscale,
            FakeTailscaleClient.connectedStatus.proxy,
          );
      final results = run.snapshots.toList();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      tailnet.udp.events.add(
        TailscaleDatagram(
          Uint8List.fromList(
            utf8.encode(
              '{"Address":"http://127.0.0.1:8888/jellyfin","Id":"server-1","Name":"Cinema"}',
            ),
          ),
          InternetAddress('100.64.0.8'),
          7359,
        ),
      );
      final result = (await results).last;
      expect(
        result.servers.single.url.toString(),
        'http://100.64.0.8:8888/jellyfin/',
      );
      expect(clients.requests.any((r) => r.url.host == '127.0.0.1'), isFalse);
    },
  );

  test('IPv6-only tailnet peer gets HTTP fallback without IPv4 UDP', () async {
    final tailnet = DiscoveryTailnet()
      ..visible = [
        TailscalePeer(
          id: 'ipv6',
          hostname: 'media',
          addresses: [InternetAddress('fd7a:115c:a1e0::8')],
        ),
      ];
    final clients = FakeJellyfinClientFactory(
      respond: (request) => request.url.scheme == 'http'
          ? FakeJellyfinClientFactory.defaultResponse(request)
          : http.Response('', 404),
    );
    final result =
        (await DefaultJellyfinDiscoveryService(
                  tailscale: tailnet,
                  clients: clients,
                  openLan: FakeLanDiscovery.new,
                  limits: shortLimits,
                )
                .start(
                  ConnectionMode.tailscale,
                  FakeTailscaleClient.connectedStatus.proxy,
                )
                .snapshots
                .toList())
            .last;
    expect(
      result.servers.single.url.toString(),
      'http://[fd7a:115c:a1e0::8]:8096/',
    );
    expect(tailnet.udp.sends, 0);
  });
  test(
    'LAN discovery preserves custom port/base path and repairs localhost',
    () async {
      final lan = FakeLanDiscovery();
      lan.onBroadcast = () => lan.announce('http://localhost:8888/jellyfin');
      final clients = FakeJellyfinClientFactory(
        respond: (request) {
          expect(request.headers.containsKey('Authorization'), isFalse);
          if (request.url.toString() ==
              'http://192.168.1.8:8888/jellyfin/System/Info/Public') {
            return FakeJellyfinClientFactory.defaultResponse(request);
          }
          return http.Response('', 404);
        },
      );
      final run = DefaultJellyfinDiscoveryService(
        tailscale: DiscoveryTailnet(),
        clients: clients,
        openLan: () => lan,
        limits: shortLimits,
      ).start(ConnectionMode.direct, null);
      final snapshots = await run.snapshots.toList();
      expect(
        snapshots.last.servers.single.url.toString(),
        'http://192.168.1.8:8888/jellyfin/',
      );
      expect(snapshots.last.phase, DiscoveryPhase.complete);
      expect(lan.sends, 2);
      expect(lan.closed, isTrue);
      expect(clients.closed, clients.requests.length);
      expect(clients.requests.any((r) => r.url.host == 'localhost'), isFalse);
      expect(clients.requests.any((r) => r.url.port == 8096), isTrue);
    },
  );

  test(
    'UDP-disabled tailnet server is found by HTTPS and duplicate LAN identity is merged',
    () async {
      final lan = FakeLanDiscovery();
      lan.onBroadcast = () => lan.announce('http://192.168.1.8:8096');
      final tailnet = DiscoveryTailnet()
        ..visible = [
          TailscalePeer(
            id: 'peer',
            hostname: 'media',
            addresses: [InternetAddress('100.64.0.8')],
            dnsName: 'media.example.ts.net',
          ),
        ];
      final clients = FakeJellyfinClientFactory(
        respond: (request) {
          if (request.url.host == 'media.example.ts.net' &&
                  request.url.port == 443 ||
              request.url.host == '192.168.1.8' && request.url.port == 8096) {
            return FakeJellyfinClientFactory.defaultResponse(request);
          }
          return http.Response('', 404);
        },
      );
      final run =
          DefaultJellyfinDiscoveryService(
            tailscale: tailnet,
            clients: clients,
            openLan: () => lan,
            limits: shortLimits,
          ).start(
            ConnectionMode.tailscale,
            FakeTailscaleClient.connectedStatus.proxy,
          );
      final result = (await run.snapshots.toList()).last;
      expect(result.servers, hasLength(1));
      expect(
        result.servers.single.url.toString(),
        'https://media.example.ts.net/',
      );
      expect(result.servers.single.sources, {
        DiscoverySource.local,
        DiscoverySource.tailscale,
      });
      expect(clients.modes.every((m) => m == ConnectionMode.tailscale), isTrue);
      expect(tailnet.udp.sends, 2);
      expect(tailnet.udp.closed, isTrue);
    },
  );

  test(
    'HTTP identity mismatch and malformed public info are rejected',
    () async {
      final lan = FakeLanDiscovery();
      lan.onBroadcast = () =>
          lan.announce('http://192.168.1.8:8888', id: 'different');
      final clients = FakeJellyfinClientFactory(
        respond: (request) => request.url.port == 8888
            ? FakeJellyfinClientFactory.defaultResponse(request)
            : http.Response('{"Version":"10.11.2","Id":""}', 200),
      );
      final result = (await DefaultJellyfinDiscoveryService(
        tailscale: DiscoveryTailnet(),
        clients: clients,
        openLan: () => lan,
        limits: shortLimits,
      ).start(ConnectionMode.direct, null).snapshots.toList()).last;
      expect(result.servers, isEmpty);
    },
  );

  test('unsupported Jellyfin versions remain identifiable', () async {
    final lan = FakeLanDiscovery();
    lan.onBroadcast = () => lan.announce('http://192.168.1.8:8096');
    final clients = FakeJellyfinClientFactory(
      respond: (_) => http.Response(
        '{"ServerName":"Old server","Version":"10.10.7","Id":"server-1"}',
        200,
      ),
    );
    final result = (await DefaultJellyfinDiscoveryService(
      tailscale: DiscoveryTailnet(),
      clients: clients,
      openLan: () => lan,
      limits: shortLimits,
    ).start(ConnectionMode.direct, null).snapshots.toList()).last;
    expect(result.servers.single.info.supportsSoup, isFalse);
  });

  test(
    'cancellation closes pending probes and ignores late responses',
    () async {
      final lan = FakeLanDiscovery();
      lan.onBroadcast = () => lan.announce('http://192.168.1.8:8096');
      final response = Completer<http.Response>();
      final clients = FakeJellyfinClientFactory(
        respond: (_) => response.future,
      );
      final run = DefaultJellyfinDiscoveryService(
        tailscale: DiscoveryTailnet(),
        clients: clients,
        openLan: () => lan,
        limits: shortLimits,
      ).start(ConnectionMode.direct, null);
      final results = run.snapshots.toList();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(clients.requests, isNotEmpty);
      run.cancel();
      response.complete(
        http.Response(
          '{"ServerName":"Media","Version":"10.11.2","Id":"server-1"}',
          200,
        ),
      );
      expect(await results, isEmpty);
      expect(lan.closed, isTrue);
      expect(clients.closed, clients.requests.length);
    },
  );

  test('overall deadline and peer cap report partial coverage', () async {
    final tailnet = DiscoveryTailnet()
      ..visible = List.generate(
        3,
        (i) => TailscalePeer(
          id: '$i',
          hostname: 'media',
          addresses: [InternetAddress('100.64.0.${i + 1}')],
        ),
      );
    final clients = FakeJellyfinClientFactory(
      respond: (_) => http.Response('', 404),
    );
    final result =
        (await DefaultJellyfinDiscoveryService(
                  tailscale: tailnet,
                  clients: clients,
                  openLan: FakeLanDiscovery.new,
                  limits: const DiscoveryLimits(
                    total: Duration(milliseconds: 100),
                    udpWindow: Duration(milliseconds: 10),
                    repeat: Duration(milliseconds: 2),
                    maxPeers: 1,
                  ),
                )
                .start(
                  ConnectionMode.tailscale,
                  FakeTailscaleClient.connectedStatus.proxy,
                )
                .snapshots
                .toList())
            .last;
    expect(result.phase, DiscoveryPhase.partial);
    expect(clients.requests.map((r) => r.url.host).toSet(), {'100.64.0.1'});
  });

  test(
    'empty local network completes without probing unknown LAN addresses',
    () async {
      final clients = FakeJellyfinClientFactory();
      final result = (await DefaultJellyfinDiscoveryService(
        tailscale: DiscoveryTailnet(),
        clients: clients,
        openLan: FakeLanDiscovery.new,
        limits: shortLimits,
      ).start(ConnectionMode.direct, null).snapshots.toList()).last;
      expect(result.phase, DiscoveryPhase.complete);
      expect(result.servers, isEmpty);
      expect(clients.requests, isEmpty);
    },
  );
}
