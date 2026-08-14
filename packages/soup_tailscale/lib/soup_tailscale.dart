import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:soup_tailscale/src/native_bindings.dart';

enum TailscaleConnectionPhase { disconnected, connecting, connected, failed }

class TailscaleProxy {
  const TailscaleProxy({
    required this.host,
    required this.port,
    required this.password,
  });

  factory TailscaleProxy.parse(String address, String password) {
    final uri = Uri.parse('socks5://$address');
    if (uri.host.isEmpty || !uri.hasPort) {
      throw FormatException('Invalid libtailscale loopback address: $address');
    }
    return TailscaleProxy(host: uri.host, port: uri.port, password: password);
  }

  static const username = 'tsnet';

  final String host;
  final int port;
  final String password;
}

class TailscaleStatus {
  const TailscaleStatus({
    required this.phase,
    this.hostname,
    this.tailnetIp,
    this.detail,
    this.proxy,
  });

  const TailscaleStatus.disconnected()
    : this(phase: TailscaleConnectionPhase.disconnected);

  const TailscaleStatus.connecting()
    : this(phase: TailscaleConnectionPhase.connecting);

  const TailscaleStatus.connected({
    required String hostname,
    required String tailnetIp,
    required TailscaleProxy proxy,
  }) : this(
         phase: TailscaleConnectionPhase.connected,
         hostname: hostname,
         tailnetIp: tailnetIp,
         proxy: proxy,
       );

  const TailscaleStatus.failed(String detail)
    : this(phase: TailscaleConnectionPhase.failed, detail: detail);

  final TailscaleConnectionPhase phase;
  final String? hostname;
  final String? tailnetIp;
  final String? detail;
  final TailscaleProxy? proxy;
}

abstract interface class TailscaleClient {
  Stream<TailscaleStatus> get statuses;

  TailscaleStatus get status;

  Future<void> restore();

  Future<void> connect({required String authKey});

  Future<void> disconnect();
}

class NativeTailscaleClient implements TailscaleClient {
  NativeTailscaleClient({
    required this.stateDirectory,
    required this.networkInterfaces,
    this.hostname = 'soup-android',
  });

  final String stateDirectory;
  final Future<String> Function() networkInterfaces;
  final String hostname;
  final _statuses = StreamController<TailscaleStatus>.broadcast(sync: true);

  TailscaleStatus _status = const TailscaleStatus.disconnected();
  int? _server;
  Future<void>? _pendingConnection;

  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;

  @override
  TailscaleStatus get status => _status;

  @override
  Future<void> restore() async {
    final stateFile = File('$stateDirectory/tailscaled.state');
    if (!stateFile.existsSync() || stateFile.lengthSync() == 0) return;
    try {
      await _start(authKey: null);
    } on Object {
      // A stale or expired node state is surfaced through status and can be
      // replaced by entering a fresh one-time auth key.
    }
  }

  @override
  Future<void> connect({required String authKey}) {
    final trimmedKey = authKey.trim();
    if (trimmedKey.isEmpty) {
      return Future.error(ArgumentError.value(authKey, 'authKey', 'is empty'));
    }
    return _start(authKey: trimmedKey);
  }

  Future<void> _start({required String? authKey}) {
    if (_status.phase == TailscaleConnectionPhase.connected) {
      return Future.value();
    }
    return _pendingConnection ??= _runStart(authKey).whenComplete(() {
      _pendingConnection = null;
    });
  }

  Future<void> _runStart(String? authKey) async {
    await disconnect();
    _emit(const TailscaleStatus.connecting());
    try {
      final directoryPath = stateDirectory;
      final nodeHostname = hostname;
      final interfacesJson = await networkInterfaces();
      final connection = await Isolate.run(
        () => _startNative(
          stateDirectory: directoryPath,
          hostname: nodeHostname,
          authKey: authKey,
          interfacesJson: interfacesJson,
        ),
      );
      _server = connection.server;
      _emit(
        TailscaleStatus.connected(
          hostname: hostname,
          tailnetIp: connection.tailnetIp,
          proxy: TailscaleProxy.parse(
            connection.loopbackAddress,
            connection.proxyCredential,
          ),
        ),
      );
    } on Object catch (error) {
      _server = null;
      _emit(TailscaleStatus.failed(_friendlyError(error)));
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await Isolate.run(() => tailscaleClose(server));
    }
    if (_status.phase != TailscaleConnectionPhase.disconnected) {
      _emit(const TailscaleStatus.disconnected());
    }
  }

  void _emit(TailscaleStatus value) {
    _status = value;
    if (!_statuses.isClosed) _statuses.add(value);
  }

  Future<void> dispose() async {
    await disconnect();
    await _statuses.close();
  }
}

class UnavailableTailscaleClient implements TailscaleClient {
  static const _status = TailscaleStatus.disconnected();

  @override
  Stream<TailscaleStatus> get statuses => const Stream.empty();

  @override
  TailscaleStatus get status => _status;

  @override
  Future<void> restore() async {}

  @override
  Future<void> connect({required String authKey}) {
    return Future.error(
      UnsupportedError('The native libtailscale adapter is unavailable.'),
    );
  }

  @override
  Future<void> disconnect() async {}
}

class TailscaleException implements Exception {
  const TailscaleException(this.operation, this.message);

  final String operation;
  final String message;

  @override
  String toString() => '$operation failed: $message';
}

({int server, String tailnetIp, String loopbackAddress, String proxyCredential})
_startNative({
  required String stateDirectory,
  required String hostname,
  required String? authKey,
  required String interfacesJson,
}) {
  Directory(stateDirectory).createSync(recursive: true);
  final logsDirectory = '$stateDirectory/logs';
  Directory(logsDirectory).createSync(recursive: true);
  _withNativeString(logsDirectory, (value) {
    if (tailscaleSetLogsDirectory(value) != 0) {
      throw const TailscaleException(
        'tailscale_set_logs_directory',
        'could not configure the Android log directory',
      );
    }
  });
  _withNativeString(interfacesJson, (value) {
    if (tailscaleSetInterfaces(value) != 0) {
      throw const TailscaleException(
        'tailscale_set_interfaces',
        'Android returned invalid network interface data',
      );
    }
  });
  final server = tailscaleNew();
  if (server <= 0) {
    throw const TailscaleException('tailscale_new', 'invalid server handle');
  }

  try {
    _withNativeString(stateDirectory, (value) {
      _check(server, 'tailscale_set_dir', tailscaleSetDirectory(server, value));
    });
    _withNativeString(hostname, (value) {
      _check(
        server,
        'tailscale_set_hostname',
        tailscaleSetHostname(server, value),
      );
    });
    _check(server, 'tailscale_set_ephemeral', tailscaleSetEphemeral(server, 0));
    _check(
      server,
      'tailscale_set_logfd',
      tailscaleSetLogFileDescriptor(server, -1),
    );
    if (authKey != null) {
      _withNativeString(authKey, (value) {
        _check(
          server,
          'tailscale_set_authkey',
          tailscaleSetAuthKey(server, value),
        );
      });
    }

    _check(server, 'tailscale_up', tailscaleUp(server));

    final ips = _readNativeString(
      256,
      (output, length) {
        return tailscaleGetIps(server, output, length);
      },
      server: server,
      operation: 'tailscale_getips',
    );
    final tailnetIp = ips
        .split(',')
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty);

    final address = calloc<Uint8>(128).cast<Utf8>();
    final proxyCredential = calloc<Uint8>(33).cast<Utf8>();
    final localApiCredential = calloc<Uint8>(33).cast<Utf8>();
    try {
      _check(
        server,
        'tailscale_loopback',
        tailscaleLoopback(
          server,
          address,
          128,
          proxyCredential,
          localApiCredential,
        ),
      );
      return (
        server: server,
        tailnetIp: tailnetIp,
        loopbackAddress: address.toDartString(),
        proxyCredential: proxyCredential.toDartString(),
      );
    } finally {
      calloc.free(address);
      calloc.free(proxyCredential);
      calloc.free(localApiCredential);
    }
  } on Object {
    tailscaleClose(server);
    rethrow;
  }
}

void _withNativeString(String value, void Function(Pointer<Utf8>) action) {
  final nativeValue = value.toNativeUtf8();
  try {
    action(nativeValue);
  } finally {
    calloc.free(nativeValue);
  }
}

String _readNativeString(
  int capacity,
  int Function(Pointer<Utf8>, int) reader, {
  required int server,
  required String operation,
}) {
  final output = calloc<Uint8>(capacity).cast<Utf8>();
  try {
    _check(server, operation, reader(output, capacity));
    return output.toDartString();
  } finally {
    calloc.free(output);
  }
}

void _check(int server, String operation, int result) {
  if (result == 0) return;
  final message = _nativeError(server);
  throw TailscaleException(
    operation,
    message.isEmpty ? 'native error $result' : message,
  );
}

String _nativeError(int server) {
  final output = calloc<Uint8>(2048).cast<Utf8>();
  try {
    final result = tailscaleErrorMessage(server, output, 2048);
    return result == 0 ? output.toDartString() : '';
  } finally {
    calloc.free(output);
  }
}

String _friendlyError(Object error) {
  final value = error.toString();
  if (value.contains('asset') || value.contains('symbol')) {
    return 'The embedded Tailscale library could not be loaded.';
  }
  return value;
}
