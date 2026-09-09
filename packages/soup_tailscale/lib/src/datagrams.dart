import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TailscaleDatagram {
  const TailscaleDatagram(this.data, this.address, this.port);
  final Uint8List data;
  final InternetAddress address;
  final int port;
}

abstract interface class TailscaleDatagramSession {
  Future<void> get ready;
  Stream<TailscaleDatagram> get datagrams;
  void send(List<int> data, InternetAddress address, int port);
  void close();
}

/// One authenticated SOCKS5 UDP association, owned by a discovery attempt.
/// UDP destinations are IPs; name resolution belongs to the HTTP transport.
class Socks5DatagramSession implements TailscaleDatagramSession {
  Socks5DatagramSession({
    required String host,
    required int port,
    required String username,
    required String password,
    this.onClose,
    Duration handshakeTimeout = const Duration(seconds: 2),
  }) {
    _ready.future.ignore();
    _deadline = Timer(
      handshakeTimeout,
      () => _fail(TimeoutException('UDP proxy handshake timed out.')),
    );
    unawaited(_open(host, port, username, password, handshakeTimeout));
  }

  final void Function()? onClose;
  final _ready = Completer<void>();
  final _events = StreamController<TailscaleDatagram>();
  Socket? _tcp;
  RawDatagramSocket? _udp;
  StreamIterator<Uint8List>? _reader;
  Timer? _deadline;
  InternetAddress? _relay;
  int _relayPort = 0;
  bool _closed = false;
  final _buffer = <int>[];

  @override
  Future<void> get ready => _ready.future;
  @override
  Stream<TailscaleDatagram> get datagrams => _events.stream;

  Future<List<int>> _read(int count) async {
    while (_buffer.length < count) {
      if (_closed || !await _reader!.moveNext()) {
        throw const SocketException('UDP proxy closed its control connection.');
      }
      if (_reader!.current.length + _buffer.length > 4096) {
        throw const FormatException('Oversized UDP proxy handshake.');
      }
      _buffer.addAll(_reader!.current);
    }
    final bytes = _buffer.sublist(0, count);
    _buffer.removeRange(0, count);
    return bytes;
  }

  Future<void> _open(
    String host,
    int port,
    String username,
    String password,
    Duration timeout,
  ) async {
    try {
      final tcp = await Socket.connect(host, port, timeout: timeout);
      if (_closed) {
        tcp.destroy();
        return;
      }
      _tcp = tcp;
      _reader = StreamIterator(tcp);
      tcp.add([5, 1, 2]);
      final greeting = await _read(2);
      if (greeting[0] != 5 || greeting[1] != 2) {
        throw const FormatException(
          'UDP proxy rejected authentication method.',
        );
      }
      final user = utf8.encode(username);
      final secret = utf8.encode(password);
      if (user.length > 255 || secret.length > 255) {
        throw const FormatException('Invalid proxy credentials.');
      }
      tcp.add([1, user.length, ...user, secret.length, ...secret]);
      final auth = await _read(2);
      if (auth[0] != 1 || auth[1] != 0) {
        throw const SocketException('UDP proxy authentication failed.');
      }
      final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      if (_closed) {
        udp.close();
        return;
      }
      _udp = udp;
      tcp.add([5, 3, 0, 1, 127, 0, 0, 1, udp.port >> 8, udp.port & 255]);
      final header = await _read(4);
      if (header[0] != 5 ||
          header[1] != 0 ||
          header[2] != 0 ||
          header[3] != 1) {
        throw const FormatException('UDP proxy rejected association.');
      }
      final address = await _read(4);
      final portBytes = await _read(2);
      _relay = InternetAddress.fromRawAddress(Uint8List.fromList(address));
      _relayPort = portBytes[0] * 256 + portBytes[1];
      if (!_relay!.isLoopback || _relayPort == 0) {
        throw const FormatException('Invalid loopback UDP relay.');
      }
      udp.listen(
        (event) {
          if (event != RawSocketEvent.read || _closed) return;
          Datagram? packet;
          while ((packet = udp.receive()) != null) {
            if (packet!.address.address != _relay!.address ||
                packet.port != _relayPort) {
              continue;
            }
            final decoded = decodePacket(packet.data);
            if (decoded != null) _events.add(decoded);
          }
        },
        onError: (Object error) => _fail(error),
        onDone: close,
      );
      _deadline?.cancel();
      if (!_ready.isCompleted) _ready.complete();
      // The association ends when this control connection closes.
      while (!_closed && await _reader!.moveNext()) {}
      if (!_closed) _fail(const SocketException('UDP proxy disconnected.'));
    } on Object catch (error) {
      if (!_closed) _fail(error);
    }
  }

  static TailscaleDatagram? decodePacket(Uint8List bytes) {
    if (bytes.length < 4 ||
        bytes.length > 8192 ||
        bytes[0] != 0 ||
        bytes[1] != 0 ||
        bytes[2] != 0) {
      return null;
    }
    final length = switch (bytes[3]) {
      1 => 4,
      4 => 16,
      _ => 0,
    };
    if (length == 0 || bytes.length < 6 + length) return null;
    final address = InternetAddress.fromRawAddress(
      Uint8List.sublistView(bytes, 4, 4 + length),
    );
    final port = bytes[4 + length] * 256 + bytes[5 + length];
    return TailscaleDatagram(
      Uint8List.sublistView(bytes, 6 + length),
      address,
      port,
    );
  }

  @override
  void send(List<int> data, InternetAddress address, int port) {
    if (_closed || _relay == null) return;
    _udp!.send(
      [
        0,
        0,
        0,
        address.type == InternetAddressType.IPv4 ? 1 : 4,
        ...address.rawAddress,
        port >> 8,
        port & 255,
        ...data,
      ],
      _relay!,
      _relayPort,
    );
  }

  void _fail(Object error) {
    if (_closed) return;
    if (!_ready.isCompleted) _ready.completeError(error);
    if (_events.hasListener) _events.addError(error);
    close();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _deadline?.cancel();
    _tcp?.destroy();
    _udp?.close();
    if (!_ready.isCompleted) {
      _ready.completeError(const SocketException('UDP discovery cancelled.'));
    }
    unawaited(_events.close());
    onClose?.call();
  }
}
