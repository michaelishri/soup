import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:soup_tailscale/src/local_api.dart';
import 'package:soup_tailscale/src/native_bindings.dart';
import 'package:soup_tailscale/src/datagrams.dart';
import 'package:soup_tailscale/src/peers.dart';

export 'src/datagrams.dart' show TailscaleDatagram, TailscaleDatagramSession;
export 'src/peers.dart' show TailscalePeer;

enum TailscaleConnectionPhase {
  disconnected,
  starting,
  awaitingLogin,
  awaitingApproval,
  connected,
  failed,
}

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
    this.authorizationUrl,
  });

  const TailscaleStatus.disconnected()
    : this(phase: TailscaleConnectionPhase.disconnected);

  const TailscaleStatus.starting()
    : this(phase: TailscaleConnectionPhase.starting);

  const TailscaleStatus.awaitingLogin(Uri authorizationUrl)
    : this(
        phase: TailscaleConnectionPhase.awaitingLogin,
        authorizationUrl: authorizationUrl,
      );

  const TailscaleStatus.awaitingApproval()
    : this(phase: TailscaleConnectionPhase.awaitingApproval);

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
  final Uri? authorizationUrl;
}

abstract interface class TailscaleClient {
  Stream<TailscaleStatus> get statuses;

  TailscaleStatus get status;

  Future<void> restore();

  Future<void> connectInteractively();

  /// Join with a one-time Tailscale auth key and wait until connected.
  ///
  /// Used by Soup roster transport grants; legacy onboarding uses
  /// [connectInteractively] instead.
  Future<void> connectWithAuthKey({required String authKey});

  Future<void> disconnect();

  Future<List<TailscalePeer>> peers();

  TailscaleDatagramSession openDatagrams();
}

extension TailscaleClientWait on TailscaleClient {
  /// Resolves when [status]/[statuses] reach connected, or throws on failure.
  ///
  /// [connectWithAuthKey] already waits internally; this is a Wave 3 hook when
  /// the app needs to re-confirm connectivity without starting a new join.
  Future<TailscaleStatus> waitUntilConnected({
    Duration timeout = const Duration(seconds: 120),
  }) async {
    bool isTerminal(TailscaleStatus value) =>
        value.phase == TailscaleConnectionPhase.connected ||
        value.phase == TailscaleConnectionPhase.failed;

    TailscaleStatus finish(TailscaleStatus value) {
      if (value.phase == TailscaleConnectionPhase.failed) {
        throw TailscaleException(
          'waitUntilConnected',
          value.detail ?? 'Tailscale connection failed.',
        );
      }
      return value;
    }

    if (isTerminal(status)) return finish(status);
    final next = await statuses.firstWhere(isTerminal).timeout(timeout);
    return finish(next);
  }
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
  TailscaleLocalApiClient? _localApi;
  final _datagrams = <TailscaleDatagramSession>{};
  Future<void>? _pendingConnection;
  int _connectionGeneration = 0;

  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;

  @override
  TailscaleStatus get status => _status;

  @override
  Future<void> restore() async {
    final stateFile = File('$stateDirectory/tailscaled.state');
    if (!stateFile.existsSync() || stateFile.lengthSync() == 0) return;
    try {
      await _start(mode: _RegistrationMode.restore);
    } on Object {
      // A stale or expired node state is surfaced through status and can be
      // replaced by entering a fresh one-time auth key.
    }
  }

  @override
  Future<void> connectInteractively() {
    return _start(mode: _RegistrationMode.interactive);
  }

  @override
  Future<void> connectWithAuthKey({required String authKey}) {
    final trimmedKey = authKey.trim();
    if (trimmedKey.isEmpty) {
      return Future.error(ArgumentError.value(authKey, 'authKey', 'is empty'));
    }
    return _start(mode: _RegistrationMode.authKey, authKey: trimmedKey);
  }

  Future<void> _start({
    required _RegistrationMode mode,
    String? authKey,
  }) async {
    if (_status.phase == TailscaleConnectionPhase.connected) {
      return;
    }
    final previous = _pendingConnection;
    if (previous != null) {
      await disconnect();
      await previous;
    }
    final operation = _runStart(mode, authKey);
    _pendingConnection = operation;
    try {
      await operation;
    } finally {
      if (identical(_pendingConnection, operation)) {
        _pendingConnection = null;
      }
    }
  }

  Future<void> _runStart(_RegistrationMode mode, String? authKey) async {
    await disconnect();
    final generation = ++_connectionGeneration;
    _emit(const TailscaleStatus.starting());
    try {
      final directoryPath = stateDirectory;
      final nodeHostname = hostname;
      final interfacesJson = await networkInterfaces();
      final node = await Isolate.run(
        () => _startNativeNode(
          stateDirectory: directoryPath,
          hostname: nodeHostname,
          authKey: authKey,
          interfacesJson: interfacesJson,
        ),
      );
      _server = node.server;
      _ensureCurrent(generation);
      final localApi = TailscaleLocalApiClient(
        address: node.loopbackAddress,
        credential: node.localApiCredential,
      );
      _localApi = localApi;
      if (mode == _RegistrationMode.interactive) {
        await localApi.startInteractiveLogin();
      }
      await _waitUntilConnected(localApi, mode: mode, generation: generation);
      _ensureCurrent(generation);
      final tailnetIp = await Isolate.run(() => _readTailnetIp(node.server));
      _emit(
        TailscaleStatus.connected(
          hostname: hostname,
          tailnetIp: tailnetIp,
          proxy: TailscaleProxy.parse(
            node.loopbackAddress,
            node.proxyCredential,
          ),
        ),
      );
    } on _ConnectionCancelled {
      _localApi = null;
      final server = _server;
      _server = null;
      if (server != null) {
        await Isolate.run(() => tailscaleClose(server));
      }
      // disconnect() owns the final status for an explicitly cancelled attempt.
    } on Object catch (error) {
      _localApi = null;
      final server = _server;
      _server = null;
      if (server != null) {
        await Isolate.run(() => tailscaleClose(server));
      }
      _emit(TailscaleStatus.failed(_friendlyError(error)));
      rethrow;
    }
  }

  Future<void> _waitUntilConnected(
    TailscaleLocalApiClient localApi, {
    required _RegistrationMode mode,
    required int generation,
  }) async {
    var consecutiveFailures = 0;
    var authKeyNeedsLoginSince = DateTime.now();
    final restoring = Stopwatch()..start();
    while (true) {
      _ensureCurrent(generation);
      if (mode == _RegistrationMode.restore &&
          restoring.elapsed >= const Duration(seconds: 30)) {
        throw const TailscaleException(
          'restore',
          'Tailscale took too long to reconnect. Please try again.',
        );
      }
      try {
        final status = await localApi.status();
        consecutiveFailures = 0;
        _ensureCurrent(generation);
        switch (status.backendState) {
          case 'Running':
            return;
          case 'NeedsMachineAuth':
            _emit(const TailscaleStatus.awaitingApproval());
          case 'NeedsLogin':
            if (mode == _RegistrationMode.restore) {
              await disconnect();
              return;
            }
            if (mode == _RegistrationMode.authKey) {
              if (DateTime.now().difference(authKeyNeedsLoginSince) >
                  const Duration(seconds: 3)) {
                throw const TailscaleException(
                  'tailscale_start',
                  'invalid key or unable to validate API key',
                );
              }
              _emit(const TailscaleStatus.starting());
              break;
            }
            final authorizationUrl = status.authorizationUrl;
            if (authorizationUrl != null) {
              _emit(TailscaleStatus.awaitingLogin(authorizationUrl));
            } else {
              _emit(const TailscaleStatus.starting());
            }
          default:
            authKeyNeedsLoginSince = DateTime.now();
            _emit(const TailscaleStatus.starting());
        }
      } on _ConnectionCancelled {
        rethrow;
      } on Object {
        consecutiveFailures++;
        if (consecutiveFailures >= 5) rethrow;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  void _ensureCurrent(int generation) {
    if (generation != _connectionGeneration) throw const _ConnectionCancelled();
  }

  @override
  Future<void> disconnect() async {
    _connectionGeneration++;
    _localApi = null;
    for (final session in _datagrams.toList()) {
      session.close();
    }
    final server = _server;
    _server = null;
    if (server != null) {
      await Isolate.run(() => tailscaleClose(server));
    }
    if (_status.phase != TailscaleConnectionPhase.disconnected) {
      _emit(const TailscaleStatus.disconnected());
    }
  }

  @override
  Future<List<TailscalePeer>> peers() async {
    final api = _localApi;
    final generation = _connectionGeneration;
    if (_status.phase != TailscaleConnectionPhase.connected || api == null) {
      throw StateError('Tailscale is not connected.');
    }
    final peers = await api.peers();
    _ensureCurrent(generation);
    return peers;
  }

  @override
  TailscaleDatagramSession openDatagrams() {
    final proxy = _status.proxy;
    if (_status.phase != TailscaleConnectionPhase.connected || proxy == null) {
      throw StateError('Tailscale is not connected.');
    }
    late final TailscaleDatagramSession session;
    session = Socks5DatagramSession(
      host: proxy.host,
      port: proxy.port,
      username: TailscaleProxy.username,
      password: proxy.password,
      onClose: () => _datagrams.remove(session),
    );
    _datagrams.add(session);
    return session;
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
  Future<void> connectInteractively() {
    return Future.error(
      UnsupportedError('The native libtailscale adapter is unavailable.'),
    );
  }

  @override
  Future<void> connectWithAuthKey({required String authKey}) {
    return Future.error(
      UnsupportedError('The native libtailscale adapter is unavailable.'),
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<TailscalePeer>> peers() async => const [];

  @override
  TailscaleDatagramSession openDatagrams() =>
      throw UnsupportedError('Tailscale UDP is unavailable.');
}

enum _RegistrationMode { restore, interactive, authKey }

class _ConnectionCancelled implements Exception {
  const _ConnectionCancelled();
}

class TailscaleException implements Exception {
  const TailscaleException(this.operation, this.message);

  final String operation;
  final String message;

  @override
  String toString() => '$operation failed: $message';
}

typedef _NativeNode = ({
  int server,
  String loopbackAddress,
  String proxyCredential,
  String localApiCredential,
});

_NativeNode _startNativeNode({
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

    _check(server, 'tailscale_start', tailscaleStart(server));

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
        loopbackAddress: address.toDartString(),
        proxyCredential: proxyCredential.toDartString(),
        localApiCredential: localApiCredential.toDartString(),
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

String _readTailnetIp(int server) {
  final ips = _readNativeString(
    256,
    (output, length) => tailscaleGetIps(server, output, length),
    server: server,
    operation: 'tailscale_getips',
  );
  return ips
      .split(',')
      .map((value) => value.trim())
      .firstWhere(
        (value) => value.isNotEmpty,
        orElse: () => throw const TailscaleException(
          'tailscale_getips',
          'the connected node has no tailnet IP address',
        ),
      );
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
    redactNativeSecrets(
      message.isEmpty ? 'native error $result' : message,
    ),
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
  return redactNativeSecrets(value);
}

/// Strip auth-key shaped substrings from native error text before surfacing.
String redactNativeSecrets(String input) {
  return input.replaceAllMapped(
    RegExp(r'tskey-(?:auth|api|client)-[A-Za-z0-9_-]+', caseSensitive: false),
    (_) => '[redacted]',
  );
}
