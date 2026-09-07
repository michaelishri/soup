import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

enum SetupPhase { connection, server, credentials, ready }

class ConnectivityViewModel extends ChangeNotifier {
  ConnectivityViewModel(
    this._tailscaleClient, {
    required this.jellyfinClientFactory,
    required this.sessionStore,
    required this.connectionStore,
  });

  final TailscaleClient _tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
  final ConnectionPreferencesStore connectionStore;
  StreamSubscription<TailscaleStatus>? _statusSubscription;
  http.Client? _httpClient;
  Future<void> _connectionTask = Future.value();
  Future<void> _disconnectTask = Future.value();
  int _connectionGeneration = 0;
  int _formGeneration = 0;
  bool _acceptStatuses = false;
  bool _disposed = false;
  bool _initialized = false;
  bool get initialized => _initialized;
  ConnectionMode _mode = ConnectionMode.direct;
  ConnectionMode get mode => _mode;
  bool get tailscaleEnabled => mode == ConnectionMode.tailscale;
  TailscaleStatus _status = const TailscaleStatus.disconnected();
  TailscaleStatus get status => _status;
  bool get tailscaleConnected =>
      _status.phase == TailscaleConnectionPhase.connected &&
      _status.proxy != null;
  bool get canContinueConnection =>
      initialized && !isBusy && (!tailscaleEnabled || tailscaleConnected);
  SetupPhase _phase = SetupPhase.connection;
  SetupPhase get phase => _phase;
  JellyfinServerInfo? _serverInfo;
  JellyfinServerInfo? get serverInfo => _serverInfo;
  JellyfinSession? _session;
  JellyfinSession? get session => _session;
  Uri? _serverUrl;
  Uri? get serverUrl => _serverUrl;
  bool _isBusy = false;
  bool get isBusy => _isBusy;
  String? _error;
  String? get error => _error;

  Future<void> initialize() async {
    _statusSubscription = _tailscaleClient.statuses.listen(_setTailscaleStatus);
    _isBusy = true;
    _notify();
    try {
      final savedMode = await connectionStore.read();
      final stored = await sessionStore.read();
      if (_disposed) return;
      // Existing authenticated installations always used embedded Tailscale.
      _mode =
          savedMode ??
          (stored == null ? ConnectionMode.direct : ConnectionMode.tailscale);
      _session = stored;
      _serverUrl = stored?.serverUrl;
      _initialized = true;
      _isBusy = false;
      if (tailscaleEnabled) {
        final generation = _connectionGeneration + 1;
        await _startTailscale(restoreOnly: true);
        if (!_current(generation) || !tailscaleConnected) return;
      } else if (savedMode == null && stored == null) {
        return;
      }
      _phase = stored == null ? SetupPhase.server : SetupPhase.ready;
    } on Object catch (error) {
      if (!_disposed) _error = _friendlyError(error);
    } finally {
      if (!_disposed) {
        if (!_initialized) {
          _initialized = true;
          _isBusy = false;
        }
        _notify();
      }
    }
  }

  Future<void> setTailscaleEnabled(bool enabled) {
    if (!initialized || isBusy || enabled == tailscaleEnabled) {
      return Future.value();
    }
    _mode = enabled ? ConnectionMode.tailscale : ConnectionMode.direct;
    _session = null;
    _serverInfo = null;
    _serverUrl = null;
    _error = null;
    _phase = SetupPhase.connection;
    _formGeneration++;
    _closeTransport();
    if (enabled) return _startTailscale();
    ++_connectionGeneration;
    _acceptStatuses = false;
    _status = const TailscaleStatus.disconnected();
    final previous = _connectionTask;
    final cancellation = _disconnect();
    _connectionTask = () async {
      await cancellation;
      await previous;
    }();
    _notify();
    return _connectionTask;
  }

  Future<void> retryTailscale() {
    if (!tailscaleEnabled || isBusy) return Future.value();
    return _startTailscale(newCode: true);
  }

  Future<void> _disconnect() {
    _disconnectTask = _disconnectTask
        .then((_) => _tailscaleClient.disconnect())
        .catchError((Object error) {
          if (!_disposed && tailscaleEnabled) {
            _error = _friendlyError(error);
            _notify();
          }
        });
    return _disconnectTask;
  }

  Future<void> _startTailscale({
    bool restoreOnly = false,
    bool newCode = false,
  }) {
    final generation = ++_connectionGeneration;
    _acceptStatuses = false;
    _status = const TailscaleStatus.starting();
    _error = null;
    _closeTransport();
    final previous = _connectionTask;
    final cancellation = _disconnect();
    // Cancel promptly, but let the old native startup unwind before beginning
    // another attempt. Statuses are accepted only for the latest selection.
    _connectionTask = () async {
      try {
        await cancellation;
        await previous;
        if (!_current(generation)) return;
        _acceptStatuses = true;
        if (!newCode) await _tailscaleClient.restore();
        if (!_current(generation)) return;
        if (!restoreOnly &&
            _tailscaleClient.status.phase !=
                TailscaleConnectionPhase.connected) {
          await _tailscaleClient.connectInteractively();
        }
        if (!_current(generation)) return;
        _setTailscaleStatus(_tailscaleClient.status);
        if (!tailscaleConnected && restoreOnly) {
          _error ??= 'Reconnect to Tailscale to continue.';
        }
      } on Object catch (error) {
        if (_current(generation)) {
          _status = TailscaleStatus.failed(_friendlyError(error));
          _error = _friendlyError(error);
        }
      } finally {
        if (_current(generation)) _notify();
      }
    }();
    _notify();
    return _connectionTask;
  }

  bool _current(int generation) =>
      !_disposed && tailscaleEnabled && generation == _connectionGeneration;

  Future<void> continueConnection() async {
    if (!canContinueConnection) return;
    _error = null;
    _isBusy = true;
    _notify();
    try {
      // Clear an old account before persisting a changed transport.
      if (_session == null) await sessionStore.clear();
      await connectionStore.write(mode);
      if (!_disposed && (!tailscaleEnabled || tailscaleConnected)) {
        _phase = _session == null ? SetupPhase.server : SetupPhase.ready;
      }
    } on Object catch (error) {
      if (!_disposed) _error = _friendlyError(error);
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void back() {
    if (isBusy) return;
    _formGeneration++;
    _error = null;
    if (_phase == SetupPhase.credentials) {
      _serverInfo = null;
      _phase = SetupPhase.server;
    } else if (_phase == SetupPhase.server) {
      _phase = SetupPhase.connection;
    }
    _notify();
  }

  Future<void> checkServer(String value) async {
    if (isBusy || _phase != SetupPhase.server) return;
    final generation = ++_formGeneration;
    _error = null;
    _serverInfo = null;
    _isBusy = true;
    _notify();
    try {
      final url = JellyfinApi.parseServerUrl(value);
      final api = await authenticatedApi();
      final info = await api.getPublicSystemInfo(url);
      if (_disposed || generation != _formGeneration) return;
      _serverInfo = info;
      _serverUrl = url;
      _phase = SetupPhase.credentials;
    } on Object catch (error) {
      if (!_disposed && generation == _formGeneration) {
        _error = _friendlyError(error);
      }
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    if (isBusy || _serverUrl == null || _phase != SetupPhase.credentials) {
      return;
    }
    if (username.trim().isEmpty || password.isEmpty) {
      _error = 'Enter your Jellyfin username and password.';
      _notify();
      return;
    }
    final generation = ++_formGeneration;
    _error = null;
    _isBusy = true;
    _notify();
    try {
      final api = await authenticatedApi();
      final session = await api.authenticate(
        serverUrl: _serverUrl!,
        username: username.trim(),
        password: password,
      );
      if (_disposed || generation != _formGeneration) return;
      await sessionStore.write(session);
      if (_disposed || generation != _formGeneration) return;
      _session = session;
      _phase = SetupPhase.ready;
    } on Object catch (error) {
      if (!_disposed && generation == _formGeneration) {
        _error = _friendlyError(error);
      }
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    await sessionStore.clear();
    _session = null;
    _serverInfo = null;
    _phase = tailscaleEnabled && !tailscaleConnected
        ? SetupPhase.connection
        : SetupPhase.server;
    _error = null;
    _notify();
  }

  Future<JellyfinApi> authenticatedApi() async {
    if (tailscaleEnabled && !tailscaleConnected) {
      throw const JellyfinApiException('Connect to Tailscale to continue.');
    }
    _httpClient ??= jellyfinClientFactory.create(
      mode: mode,
      proxy: tailscaleEnabled ? _status.proxy : null,
    );
    return JellyfinApi(_httpClient!, deviceId: await sessionStore.deviceId());
  }

  void _setTailscaleStatus(TailscaleStatus value) {
    if (_disposed || !tailscaleEnabled || !_acceptStatuses) return;
    final oldProxy = _status.proxy;
    final proxy = value.proxy;
    if (oldProxy?.host != proxy?.host ||
        oldProxy?.port != proxy?.port ||
        oldProxy?.password != proxy?.password) {
      _closeTransport();
    }
    _status = value;
    if (value.phase == TailscaleConnectionPhase.failed) _error = value.detail;
    if (value.phase == TailscaleConnectionPhase.connected) _error = null;
    if (!tailscaleConnected && _phase != SetupPhase.connection) {
      _formGeneration++;
      _phase = SetupPhase.connection;
      _error =
          'Your Tailscale connection was interrupted. Reconnect to continue.';
    }
    _notify();
  }

  void _closeTransport() {
    _httpClient?.close();
    _httpClient = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _friendlyError(Object error) {
    if (error is JellyfinApiException) return error.message;
    return error.toString().replaceFirst(
      RegExp(r'^(Exception|StateError):\s*'),
      '',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _acceptStatuses = false;
    _connectionGeneration++;
    _statusSubscription?.cancel();
    _closeTransport();
    unawaited(_tailscaleClient.disconnect().catchError((Object _) {}));
    super.dispose();
  }
}
