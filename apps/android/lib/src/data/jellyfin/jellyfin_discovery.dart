import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/jellyfin/discovery_client_factory.dart';
import 'package:soup/src/data/jellyfin/lan_discovery.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

enum DiscoveryPhase { searching, complete, partial, unavailable }

enum DiscoverySource { local, tailscale }

class DiscoveredJellyfinServer {
  const DiscoveredJellyfinServer({
    required this.info,
    required this.url,
    required this.sources,
    required this.rank,
  });
  final JellyfinServerInfo info;
  final Uri url;
  final Set<DiscoverySource> sources;
  final int rank;
}

class JellyfinDiscoverySnapshot {
  const JellyfinDiscoverySnapshot({
    this.servers = const [],
    this.phase = DiscoveryPhase.searching,
  });
  final List<DiscoveredJellyfinServer> servers;
  final DiscoveryPhase phase;
  bool get searching => phase == DiscoveryPhase.searching;
}

abstract interface class JellyfinDiscoveryRun {
  Stream<JellyfinDiscoverySnapshot> get snapshots;
  void cancel();
}

abstract interface class JellyfinDiscoveryService {
  JellyfinDiscoveryRun start(ConnectionMode mode, TailscaleProxy? proxy);
}

class DiscoveryLimits {
  const DiscoveryLimits({
    this.total = const Duration(seconds: 15),
    this.udpWindow = const Duration(seconds: 3),
    this.repeat = const Duration(milliseconds: 500),
    this.probe = const Duration(seconds: 3),
    this.peerLookup = const Duration(seconds: 2),
    this.concurrency = 8,
    this.maxPeers = 128,
  });
  final Duration total, udpWindow, repeat, probe, peerLookup;
  final int concurrency, maxPeers;
}

class DefaultJellyfinDiscoveryService implements JellyfinDiscoveryService {
  DefaultJellyfinDiscoveryService({
    required this.tailscale,
    this.clients = const DiscoveryJellyfinClientFactory(),
    LanDiscoverySession Function()? openLan,
    this.limits = const DiscoveryLimits(),
  }) : openLan = openLan ?? SocketLanDiscoverySession.new;
  final TailscaleClient tailscale;
  final JellyfinClientFactory clients;
  final LanDiscoverySession Function() openLan;
  final DiscoveryLimits limits;
  @override
  JellyfinDiscoveryRun start(ConnectionMode mode, TailscaleProxy? proxy) =>
      _DiscoveryRun(this, mode, proxy);
}

class _Candidate {
  const _Candidate(this.url, this.source, this.rank, [this.expectedId]);
  final Uri url;
  final DiscoverySource source;
  final int rank;
  final String? expectedId;
}

class _DiscoveryRun implements JellyfinDiscoveryRun {
  _DiscoveryRun(this.service, this.mode, this.proxy) {
    _sourcesLeft = mode == ConnectionMode.tailscale ? 2 : 1;
    _sourceCount = _sourcesLeft;
    _deadline = Timer(
      service.limits.total,
      () => _finish(DiscoveryPhase.partial),
    );
    scheduleMicrotask(() {
      if (_closed) return;
      unawaited(_lan());
      if (mode == ConnectionMode.tailscale) unawaited(_tailnet());
    });
  }

  final DefaultJellyfinDiscoveryService service;
  final ConnectionMode mode;
  final TailscaleProxy? proxy;
  final _events = StreamController<JellyfinDiscoverySnapshot>();
  final _queue = Queue<_Candidate>();
  final _seen = <String>{};
  final _servers = <String, DiscoveredJellyfinServer>{};
  final _clients = <http.Client>{};
  final _waits = <Timer, Completer<bool>>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _closeSockets = <void Function()>[];
  late final Timer _deadline;
  late int _sourcesLeft, _sourceCount;
  int _failures = 0;
  int _active = 0;
  bool _partial = false;
  bool _closed = false;
  static final _message = utf8.encode('Who is JellyfinServer?');

  @override
  Stream<JellyfinDiscoverySnapshot> get snapshots => _events.stream;

  Future<bool> _wait(Duration duration) {
    final done = Completer<bool>();
    late final Timer timer;
    timer = Timer(duration, () {
      _waits.remove(timer);
      done.complete(!_closed);
    });
    _waits[timer] = done;
    return done.future;
  }

  Future<void> _lan() async {
    LanDiscoverySession? session;
    final responders = <String, InternetAddress>{};
    var failed = false;
    try {
      session = service.openLan();
      _closeSockets.add(session.close);
      _subscriptions.add(
        session.datagrams.listen(
          (packet) {
            if (_closed || packet.port != 7359) return;
            if (_advertisement(
              packet.data,
              packet.address,
              DiscoverySource.local,
            )) {
              responders[packet.address.address] = packet.address;
            }
          },
          onError: (Object _) {
            failed = true;
          },
        ),
      );
      await session.ready.timeout(service.limits.peerLookup);
      if (_closed) return;
      session.broadcast(_message);
      unawaited(_repeat(session.broadcast));
      if (!await _wait(service.limits.udpWindow)) return;
      for (final address in responders.values) {
        _standard(address.address, DiscoverySource.local);
      }
    } on Object {
      failed = true;
    } finally {
      session?.close();
      if (failed) _failures++;
      _sourcesLeft--;
      _pump();
    }
  }

  Future<void> _repeat(void Function(List<int>) send) async {
    if (await _wait(service.limits.repeat)) {
      try {
        send(_message);
      } on Object {
        /* Other discovery paths remain usable. */
      }
    }
  }

  Future<void> _tailnet() async {
    TailscaleDatagramSession? session;
    var failed = false;
    try {
      final all = await service.tailscale.peers().timeout(
        service.limits.peerLookup,
      );
      if (_closed) return;
      _partial |= all.length > service.limits.maxPeers;
      final peers = all.take(service.limits.maxPeers).toList();
      final addresses = {
        for (final peer in peers)
          for (final ip in peer.addresses) ip.address: ip,
      };
      if (peers.isNotEmpty) {
        try {
          session = service.tailscale.openDatagrams();
          _closeSockets.add(session.close);
          _subscriptions.add(
            session.datagrams.listen(
              (packet) {
                if (_closed ||
                    packet.port != 7359 ||
                    !addresses.containsKey(packet.address.address)) {
                  return;
                }
                _advertisement(
                  packet.data,
                  packet.address,
                  DiscoverySource.tailscale,
                );
              },
              onError: (Object _) {
                failed = true;
              },
            ),
          );
          await session.ready.timeout(service.limits.peerLookup);
          if (_closed) return;
          void send(List<int> bytes) {
            for (final ip in addresses.values.where(
              (ip) => ip.type == InternetAddressType.IPv4,
            )) {
              session!.send(bytes, ip, 7359);
            }
          }

          send(_message);
          unawaited(_repeat(send));
          if (!await _wait(service.limits.udpWindow)) return;
        } on Object {
          failed = true;
        } finally {
          session?.close();
        }
      }
      if (_closed) return;
      for (final peer in peers) {
        // Certificate names must use the peer's DNS name, not its IP address.
        if (peer.dnsName case final dns? when dns.isNotEmpty) {
          _add(
            Uri(scheme: 'https', host: dns, path: '/'),
            DiscoverySource.tailscale,
            0,
          );
          _add(
            Uri(scheme: 'https', host: dns, port: 8920, path: '/'),
            DiscoverySource.tailscale,
            0,
          );
        }
        for (final ip in peer.addresses) {
          _standard(ip.address, DiscoverySource.tailscale);
        }
      }
    } on Object {
      failed = true;
    } finally {
      if (failed) _failures++;
      _sourcesLeft--;
      _pump();
    }
  }

  bool _advertisement(
    List<int> data,
    InternetAddress sender,
    DiscoverySource source,
  ) {
    if (_closed || data.length > 8192 || !_safeHost(sender.address)) {
      return false;
    }
    try {
      final value = jsonDecode(utf8.decode(data));
      if (value is! Map ||
          value['Id'] is! String ||
          (value['Id'] as String).isEmpty ||
          value['Address'] is! String) {
        return false;
      }
      final url = Uri.tryParse(value['Address'] as String);
      if (url == null ||
          !url.hasAuthority ||
          !{'http', 'https'}.contains(url.scheme) ||
          url.userInfo.isNotEmpty) {
        return false;
      }
      final id = value['Id'] as String;
      // Preserve advertised ports/base paths even when the advertised host is
      // localhost or a LAN address inaccessible from the tailnet.
      _add(
        url.replace(host: sender.address),
        source,
        source == DiscoverySource.tailscale ? 0 : 2,
        id,
      );
      _add(
        url,
        source,
        url.host == sender.address
            ? (source == DiscoverySource.tailscale ? 0 : 2)
            : 4,
        id,
      );
      return true;
    } on Object {
      return false;
    }
  }

  static bool _safeHost(String host) {
    if (host.isEmpty ||
        host.toLowerCase().replaceFirst(RegExp(r'\.$'), '') == 'localhost') {
      return false;
    }
    final ip = InternetAddress.tryParse(host);
    return ip == null ||
        (!ip.isLoopback &&
            !ip.isMulticast &&
            ip.address != '0.0.0.0' &&
            ip.address != '::');
  }

  void _standard(String host, DiscoverySource source) {
    final rank = source == DiscoverySource.tailscale ? 0 : 2;
    _add(Uri(scheme: 'https', host: host, port: 8920, path: '/'), source, rank);
    _add(Uri(scheme: 'http', host: host, port: 8096, path: '/'), source, rank);
  }

  void _add(Uri raw, DiscoverySource source, int networkRank, [String? id]) {
    if (_closed || !_safeHost(raw.host)) return;
    if (_seen.length >= 512) {
      _partial = true;
      return;
    }
    final url = JellyfinApi.parseServerUrl(raw.toString());
    // Keep source and expected identity in the key so a LAN result can also
    // acquire its tailnet provenance without accepting a mismatched UDP ID.
    if (!_seen.add('$url|${source.name}|$id')) return;
    _queue.add(
      _Candidate(
        url,
        source,
        networkRank + (url.scheme == 'https' ? 0 : 1),
        id,
      ),
    );
    _pump();
  }

  void _pump() {
    if (_closed) return;
    while (_active < service.limits.concurrency && _queue.isNotEmpty) {
      _active++;
      final candidate = _queue.removeFirst();
      unawaited(
        _probe(candidate).whenComplete(() {
          _active--;
          _pump();
        }),
      );
    }
    if (_sourcesLeft == 0 && _active == 0 && _queue.isEmpty) {
      _finish(
        _partial || _failures > 0
            ? (_failures == _sourceCount && _servers.isEmpty
                  ? DiscoveryPhase.unavailable
                  : DiscoveryPhase.partial)
            : DiscoveryPhase.complete,
      );
    }
  }

  Future<void> _probe(_Candidate candidate) async {
    http.Client? client;
    try {
      client = service.clients.create(mode: mode, proxy: proxy);
      _clients.add(client);
      final info = await _readInfo(client, candidate.url).timeout(
        service.limits.probe,
        onTimeout: () {
          client!.close();
          throw TimeoutException('Server discovery timed out.');
        },
      );
      if (_closed ||
          (candidate.expectedId != null && candidate.expectedId != info.id)) {
        return;
      }
      final previous = _servers[info.id];
      final prefer = previous == null || candidate.rank < previous.rank;
      _servers[info.id] = DiscoveredJellyfinServer(
        info: prefer ? info : previous.info,
        url: prefer ? candidate.url : previous.url,
        rank: prefer ? candidate.rank : previous.rank,
        sources: Set.unmodifiable({...?previous?.sources, candidate.source}),
      );
      _emit(DiscoveryPhase.searching);
    } on Object {
      /* A failed candidate does not fail discovery. */
    } finally {
      client?.close();
      _clients.remove(client);
    }
  }

  static Future<JellyfinServerInfo> _readInfo(
    http.Client client,
    Uri base,
  ) async {
    final request = http.Request('GET', base.resolve('System/Info/Public'))
      ..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw const FormatException('Not a Jellyfin response.');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > 65536) {
        throw const FormatException('Oversized discovery response.');
      }
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, Object?> ||
        value['Id'] is! String ||
        (value['Id'] as String).isEmpty ||
        value['Version'] is! String ||
        !RegExp(r'^\d+\.\d+').hasMatch(value['Version'] as String) ||
        value['ServerName'] is! String) {
      throw const FormatException('Invalid Jellyfin public information.');
    }
    return JellyfinServerInfo.fromJson(value);
  }

  void _emit(DiscoveryPhase phase) {
    if (!_closed) {
      _events.add(
        JellyfinDiscoverySnapshot(
          servers: List.unmodifiable(_servers.values),
          phase: phase,
        ),
      );
    }
  }

  void _finish(DiscoveryPhase phase) {
    if (_closed) return;
    _emit(phase);
    cancel();
  }

  @override
  void cancel() {
    if (_closed) return;
    _closed = true;
    _deadline.cancel();
    for (final close in _closeSockets) {
      close();
    }
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    for (final entry in _waits.entries) {
      entry.key.cancel();
      entry.value.complete(false);
    }
    _waits.clear();
    for (final client in _clients.toList()) {
      client.close();
    }
    _queue.clear();
    unawaited(_events.close());
  }
}
