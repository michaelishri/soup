import 'dart:async';
import 'dart:io';

import 'package:soup/src/platform/android_network_interfaces.dart';

abstract interface class LanDiscoverySession {
  Future<void> get ready;
  Stream<Datagram> get datagrams;
  void broadcast(List<int> bytes);
  void close();
}

class SocketLanDiscoverySession implements LanDiscoverySession {
  SocketLanDiscoverySession({
    AndroidNetworkInterfaces interfaces = const AndroidNetworkInterfaces(),
  }) {
    _ready = _open(interfaces);
    _ready.ignore();
  }

  final _events = StreamController<Datagram>();
  final _sockets = <({RawDatagramSocket socket, InternetAddress broadcast})>[];
  late final Future<void> _ready;
  bool _closed = false;
  @override
  Future<void> get ready => _ready;
  @override
  Stream<Datagram> get datagrams => _events.stream;

  Future<void> _open(AndroidNetworkInterfaces interfaces) async {
    final addresses = await interfaces.broadcasts();
    for (final entry in addresses) {
      if (_closed) return;
      final socket = await RawDatagramSocket.bind(entry.address, 0);
      if (_closed) {
        socket.close();
        return;
      }
      socket.broadcastEnabled = true;
      _sockets.add((socket: socket, broadcast: entry.broadcast));
      socket.listen(
        (event) {
          if (_closed || event != RawSocketEvent.read) return;
          Datagram? packet;
          while ((packet = socket.receive()) != null) {
            _events.add(packet!);
          }
        },
        onError: (Object error) {
          if (!_closed) _events.addError(error);
        },
      );
    }
  }

  @override
  void broadcast(List<int> bytes) {
    if (_closed) return;
    for (final entry in _sockets) {
      entry.socket.send(bytes, entry.broadcast, 7359);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final entry in _sockets) {
      entry.socket.close();
    }
    _sockets.clear();
    unawaited(_events.close());
  }
}
