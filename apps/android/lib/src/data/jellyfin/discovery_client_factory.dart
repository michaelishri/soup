import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

/// Discovery owns every socket, including unfinished SOCKS and TLS handshakes.
class DiscoveryJellyfinClientFactory implements JellyfinClientFactory {
  const DiscoveryJellyfinClientFactory({this.securityContext});
  final SecurityContext? securityContext;

  @override
  http.Client create({required ConnectionMode mode, TailscaleProxy? proxy}) {
    if (mode == ConnectionMode.direct) {
      return DefaultJellyfinClientFactory(
        securityContext: securityContext,
      ).create(mode: mode);
    }
    if (proxy == null) {
      throw StateError('Discovery requires a connected Tailscale proxy.');
    }
    return _DiscoveryProxyClient(proxy, securityContext);
  }
}

/// A short-lived HTTP CONNECT bridge lets dart:io own TLS while we retain the
/// underlying plaintext tunnel sockets. socks5_proxy's HTTPS factory cannot
/// cancel until its SecureSocket future completes. The bridge is private to one
/// public-info request and never accepts a destination supplied by an incoming
/// loopback connection.
class _DiscoveryProxyClient extends http.BaseClient {
  _DiscoveryProxyClient(this.proxy, this.securityContext);
  final TailscaleProxy proxy;
  final SecurityContext? securityContext;
  final _sockets = <Socket>{};
  ServerSocket? _bridge;
  http.Client? _client;
  bool _closed = false;
  bool _sent = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed || _sent || request.method != 'GET') {
      throw StateError('Discovery transport is closed or already used.');
    }
    _sent = true;
    final bridge = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    if (_closed) {
      await bridge.close();
      throw http.ClientException('Discovery cancelled.');
    }
    _bridge = bridge;
    var accepted = false;
    bridge.listen((incoming) {
      if (accepted || _closed) {
        incoming.destroy();
        return;
      }
      accepted = true;
      unawaited(_tunnel(incoming, request.url));
    });
    final io = HttpClient(context: securityContext)
      ..connectionTimeout = const Duration(seconds: 3)
      ..findProxy = (_) => 'PROXY 127.0.0.1:${bridge.port}';
    _client = IOClient(io);
    return _client!.send(request);
  }

  Future<void> _tunnel(Socket downstream, Uri destination) async {
    final input = StreamIterator(downstream);
    Socket? upstream;
    try {
      if (_closed) {
        downstream.destroy();
        return;
      }
      _sockets.add(downstream);
      // Read the proxy preface ourselves: HttpServer rejects numeric CONNECT
      // authorities on some Dart versions. TLS bytes stay opaque in this tunnel.
      final header = <int>[];
      var boundary = -1;
      while (boundary < 0 && await input.moveNext()) {
        header.addAll(input.current);
        if (header.length > 8192) {
          throw const FormatException('Proxy header too large.');
        }
        for (var i = 0; i + 3 < header.length; i++) {
          if (header[i] == 13 &&
              header[i + 1] == 10 &&
              header[i + 2] == 13 &&
              header[i + 3] == 10) {
            boundary = i + 4;
            break;
          }
        }
      }
      if (boundary < 0) {
        throw const FormatException('Incomplete proxy request.');
      }
      final method = ascii
          .decode(header.take(boundary).toList())
          .split(' ')
          .first;
      Stream<List<int>> remainingInput() async* {
        if (header.length > boundary) yield header.sublist(boundary);
        while (await input.moveNext()) {
          yield input.current;
        }
      }

      final parentZone = Zone.current;
      // Capture the socket before the library awaits its SOCKS handshake. The
      // override applies only to this connection attempt, not other app traffic.
      final connection = await IOOverrides.runZoned(
        () => SocksTCPClient.connect(
          [
            ProxySettings(
              InternetAddress(proxy.host),
              proxy.port,
              username: TailscaleProxy.username,
              password: proxy.password,
            ),
          ],
          InternetAddress(destination.host, type: InternetAddressType.unix),
          destination.port,
        ),
        socketConnect:
            (host, port, {sourceAddress, sourcePort = 0, timeout}) async {
              final socket = await parentZone.run(
                () => Socket.connect(
                  host,
                  port,
                  sourceAddress: sourceAddress,
                  sourcePort: sourcePort,
                  timeout: const Duration(seconds: 3),
                ),
              );
              if (_closed) {
                socket.destroy();
                throw const SocketException('Discovery cancelled.');
              }
              _sockets.add(socket);
              return socket;
            },
      );
      upstream = connection;
      if (_closed) {
        upstream.destroy();
        return;
      }
      if (destination.scheme == 'https') {
        if (method != 'CONNECT') {
          throw const FormatException('Expected a TLS tunnel.');
        }
        downstream.add(
          utf8.encode('HTTP/1.1 200 Connection Established\r\n\r\n'),
        );
        await downstream.flush();
      } else {
        // This client only fetches unauthenticated discovery metadata.
        upstream.add(
          utf8.encode(
            'GET ${destination.path}${destination.hasQuery ? '?${destination.query}' : ''} HTTP/1.1\r\nHost: ${destination.authority}\r\nAccept: application/json\r\nConnection: close\r\n\r\n',
          ),
        );
      }
      await Future.any([
        downstream.addStream(upstream),
        upstream.addStream(remainingInput()),
      ]);
      await downstream.flush();
    } on Object {
      // Closing the tunnel propagates a normal request failure to the client.
    } finally {
      downstream.destroy();
      unawaited(input.cancel());
      upstream?.destroy();
      _sockets.remove(downstream);
      _sockets.remove(upstream);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _client?.close();
    unawaited(_bridge?.close());
    for (final socket in _sockets) {
      socket.destroy();
    }
    _sockets.clear();
  }
}
