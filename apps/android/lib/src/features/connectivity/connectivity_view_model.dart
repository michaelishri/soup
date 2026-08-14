import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

enum SetupPhase { tailscale, server, credentials, ready }

class ConnectivityViewModel extends ChangeNotifier {
  ConnectivityViewModel(
    this._tailscaleClient, {
    required this.jellyfinClientFactory,
    required this.sessionStore,
  });

  final TailscaleClient _tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
  StreamSubscription<TailscaleStatus>? _statusSubscription;
  http.Client? _httpClient;

  TailscaleStatus _status = const TailscaleStatus.disconnected();
  TailscaleStatus get status => _status;

  SetupPhase _phase = SetupPhase.tailscale;
  SetupPhase get phase => _phase;

  JellyfinServerInfo? _serverInfo;
  JellyfinServerInfo? get serverInfo => _serverInfo;

  JellyfinSession? _session;
  JellyfinSession? get session => _session;

  Uri? _serverUrl;
  Uri? get serverUrl => _serverUrl;

  bool _isBusy = false;
  bool get isBusy =>
      _isBusy || _status.phase == TailscaleConnectionPhase.connecting;

  String? _error;
  String? get error => _error;

  Future<void> initialize() async {
    _statusSubscription = _tailscaleClient.statuses.listen(_setTailscaleStatus);
    _setBusy(true);
    try {
      await _tailscaleClient.restore();
      _status = _tailscaleClient.status;
      if (_status.phase == TailscaleConnectionPhase.connected) {
        final stored = await sessionStore.read();
        if (stored == null) {
          _phase = SetupPhase.server;
        } else {
          _session = stored;
          _serverUrl = stored.serverUrl;
          _phase = SetupPhase.ready;
        }
      }
    } on Object catch (error) {
      _error = _friendlyError(error);
      _phase = SetupPhase.tailscale;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> connect(String authKey) async {
    final trimmedKey = authKey.trim();
    if (trimmedKey.isEmpty || isBusy) return;

    _error = null;
    _setBusy(true);
    try {
      await _tailscaleClient.connect(authKey: trimmedKey);
      _status = _tailscaleClient.status;
      _phase = SetupPhase.server;
    } on Object catch (error) {
      _error = _friendlyError(error);
      _phase = SetupPhase.tailscale;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> checkServer(String value) async {
    if (isBusy) return;
    _error = null;
    _setBusy(true);
    try {
      final url = JellyfinApi.parseServerUrl(value);
      final api = await _api();
      _serverInfo = await api.getPublicSystemInfo(url);
      _serverUrl = url;
      _phase = SetupPhase.credentials;
    } on Object catch (error) {
      _error = _friendlyError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    if (isBusy || _serverUrl == null) return;
    if (username.trim().isEmpty || password.isEmpty) {
      _error = 'Enter your Jellyfin username and password.';
      notifyListeners();
      return;
    }
    _error = null;
    _setBusy(true);
    try {
      final api = await _api();
      final session = await api.authenticate(
        serverUrl: _serverUrl!,
        username: username.trim(),
        password: password,
      );
      await sessionStore.write(session);
      _session = session;
      _phase = SetupPhase.ready;
    } on Object catch (error) {
      _error = _friendlyError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    await sessionStore.clear();
    _session = null;
    _serverInfo = null;
    _phase = SetupPhase.server;
    _error = null;
    notifyListeners();
  }

  Future<JellyfinApi> _api() async {
    final proxy = _status.proxy;
    if (proxy == null) {
      throw const JellyfinApiException('Connect to Tailscale first.');
    }
    _httpClient ??= jellyfinClientFactory.create(proxy);
    return JellyfinApi(_httpClient!, deviceId: await sessionStore.deviceId());
  }

  void _setTailscaleStatus(TailscaleStatus value) {
    _status = value;
    if (value.phase != TailscaleConnectionPhase.connected) {
      _httpClient?.close();
      _httpClient = null;
      _phase = SetupPhase.tailscale;
    }
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  static String _friendlyError(Object error) {
    if (error is JellyfinApiException) return error.message;
    final message = error.toString().replaceFirst(
      RegExp(r'^(Exception|StateError):\s*'),
      '',
    );
    if (message.contains('invalid key') ||
        message.contains('unable to validate API key')) {
      return 'Tailscale rejected this auth key. Generate a fresh one-time key and try again.';
    }
    return message;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _httpClient?.close();
    super.dispose();
  }
}
