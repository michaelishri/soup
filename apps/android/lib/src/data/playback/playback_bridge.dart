import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

class PlaybackBridge {
  PlaybackBridge(this._transport, this._session, this._headers);

  final http.Client _transport;
  final JellyfinSession _session;
  final Map<String, String> _headers;
  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    unawaited(
      server.forEach(_handle).catchError((Object _) {
        // Individual player requests receive their own HTTP error response.
      }),
    );
  }

  Uri localUriFor(Uri upstream) {
    final server = _server;
    if (server == null) {
      throw StateError('Playback bridge has not started.');
    }
    if (upstream.host != _session.serverUrl.host ||
        _effectivePort(upstream) != _effectivePort(_session.serverUrl)) {
      throw const JellyfinApiException(
        'Jellyfin returned a playback URL for an unexpected server.',
      );
    }
    return upstream.replace(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
    );
  }

  Future<void> _handle(HttpRequest incoming) async {
    final response = incoming.response;
    if (incoming.method != 'GET' && incoming.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }
    try {
      final upstream = _session.serverUrl.replace(
        path: incoming.uri.path,
        query: incoming.uri.hasQuery ? incoming.uri.query : null,
      );
      final request = http.Request(incoming.method, upstream);
      incoming.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (_requestHopByHop.contains(lower) || lower == 'content-length') {
          return;
        }
        request.headers[name] = values.join(',');
      });
      request.headers.addAll(_headers);
      final upstreamResponse = await _transport.send(request);
      response.statusCode = upstreamResponse.statusCode;
      if (upstreamResponse.reasonPhrase case final reason?) {
        response.reasonPhrase = reason;
      }
      upstreamResponse.headers.forEach((name, value) {
        if (!_responseHopByHop.contains(name.toLowerCase())) {
          response.headers.set(name, value);
        }
      });
      if (incoming.method != 'HEAD') {
        await response.addStream(upstreamResponse.stream);
      }
    } on Object {
      try {
        response.statusCode = HttpStatus.badGateway;
      } on StateError {
        // The upstream response had already started streaming.
      }
    } finally {
      await response.close();
    }
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  static const _requestHopByHop = {
    'connection',
    'host',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };

  static const _responseHopByHop = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }
}
