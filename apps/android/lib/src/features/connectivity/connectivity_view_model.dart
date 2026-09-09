import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/jellyfin/jellyfin_discovery.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup/src/features/connectivity/tailscale_authorization_controller.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

enum SetupPhase { connection, server, credentials, ready }

enum QuickConnectPhase {
  idle,
  checking,
  waiting,
  paused,
  expired,
  unavailable,
  error,
  completing,
}

class ConnectivityViewModel extends ChangeNotifier {
  ConnectivityViewModel(
    this._tailscaleClient, {
    required this.jellyfinClientFactory,
    required this.sessionStore,
    required this.connectionStore,
    this.discoveryService,
    TailscaleAuthorizationBrowser authorizationBrowser =
        const PlatformTailscaleAuthorizationBrowser(),
  }) : authorization = TailscaleAuthorizationController(
         browser: authorizationBrowser,
       );

  final TailscaleAuthorizationController authorization;

  final TailscaleClient _tailscaleClient;
  final JellyfinClientFactory jellyfinClientFactory;
  final SessionStore sessionStore;
  final ConnectionPreferencesStore connectionStore;
  final JellyfinDiscoveryService? discoveryService;
  JellyfinDiscoveryRun? _discoveryRun;
  StreamSubscription<JellyfinDiscoverySnapshot>? _discoverySubscription;
  int _discoveryGeneration = 0;
  bool _discoveryStarted = false;
  bool _manualServer = false;
  bool _resumeDiscovery = false;
  JellyfinDiscoverySnapshot _discovery = const JellyfinDiscoverySnapshot(
    phase: DiscoveryPhase.complete,
  );
  JellyfinDiscoverySnapshot get discovery => _discovery;
  String? selectedDiscoveryId;
  bool get showingServerDiscovery =>
      discoveryService != null && !_manualServer && _phase == SetupPhase.server;

  bool get _canDiscover => !isBusy && _canAcceptDiscovery;

  // Next may save preferences while a prefetched search finishes. Preserve
  // current-generation results during that write; navigation cancels stale runs.
  bool get _canAcceptDiscovery =>
      !_disposed &&
      _initialized &&
      !_initializing &&
      _foreground &&
      _session == null &&
      !_manualServer &&
      discoveryService != null &&
      (_phase == SetupPhase.server ||
          (_phase == SetupPhase.connection && tailscaleConnected)) &&
      (!tailscaleEnabled || tailscaleConnected);

  void searchServers({bool again = false, bool preserveResults = false}) {
    if (!_canDiscover || (_discoveryStarted && !again)) return;
    final previous = preserveResults
        ? _discovery.servers
        : <DiscoveredJellyfinServer>[];
    _stopDiscovery();
    _discoveryStarted = true;
    _discovery = JellyfinDiscoverySnapshot(servers: previous);
    final generation = _discoveryGeneration;
    try {
      final run = discoveryService!.start(
        mode,
        tailscaleEnabled ? _status.proxy : null,
      );
      _discoveryRun = run;
      _discoverySubscription = run.snapshots.listen(
        (snapshot) {
          if (!_canAcceptDiscovery || generation != _discoveryGeneration) {
            return;
          }
          _discovery = JellyfinDiscoverySnapshot(
            phase: snapshot.phase,
            servers: List.unmodifiable(
              {
                for (final server in previous) server.info.id: server,
                for (final server in snapshot.servers) server.info.id: server,
              }.values,
            ),
          );
          _notify();
        },
        onError: (Object _) {
          if (!_canAcceptDiscovery || generation != _discoveryGeneration) {
            return;
          }
          _discovery = JellyfinDiscoverySnapshot(
            servers: _discovery.servers,
            phase: DiscoveryPhase.unavailable,
          );
          _stopDiscovery();
          _notify();
        },
      );
    } on Object {
      _discovery = JellyfinDiscoverySnapshot(
        servers: previous,
        phase: DiscoveryPhase.unavailable,
      );
    }
    _notify();
  }

  void enterServerManually() {
    if (_phase != SetupPhase.server || isBusy) return;
    _manualServer = true;
    _resumeDiscovery = false;
    _stopDiscovery();
    _error = null;
    _notify();
  }

  Future<void> connectDiscoveredServer(DiscoveredJellyfinServer server) async {
    if (!showingServerDiscovery || isBusy || !server.info.supportsSoup) return;
    selectedDiscoveryId = server.info.id;
    await checkServer(server.url.toString(), expectedId: server.info.id);
  }

  void _stopDiscovery({bool clear = false}) {
    _discoveryGeneration++;
    _discoveryRun?.cancel();
    _discoveryRun = null;
    unawaited(_discoverySubscription?.cancel());
    _discoverySubscription = null;
    if (clear) {
      _discoveryStarted = false;
      selectedDiscoveryId = null;
      _discovery = const JellyfinDiscoverySnapshot(
        phase: DiscoveryPhase.complete,
      );
    } else if (_discovery.searching) {
      _discovery = JellyfinDiscoverySnapshot(
        servers: _discovery.servers,
        phase: DiscoveryPhase.partial,
      );
    }
  }

  StreamSubscription<TailscaleStatus>? _statusSubscription;
  http.Client? _httpClient;
  Future<void> _connectionTask = Future.value();
  Future<void> _disconnectTask = Future.value();
  Future<void> _quickConnectTask = Future.value();
  Future<void> _sessionTask = Future.value();
  Timer? _quickConnectTimer;
  int _quickConnectGeneration = 0;
  JellyfinQuickConnectRequest? _quickConnectRequest;
  QuickConnectPhase _quickConnectPhase = QuickConnectPhase.idle;
  QuickConnectPhase get quickConnectPhase => _quickConnectPhase;
  String? get quickConnectCode => _quickConnectRequest?.code;
  String? _quickConnectError;
  String? get quickConnectError => _quickConnectError;
  bool _foreground = true;
  bool _resumeOnForeground = false;
  int _connectionGeneration = 0;
  int _formGeneration = 0;
  bool _acceptStatuses = false;
  bool _disposed = false;
  bool _initialized = false;
  bool get initialized => _initialized;
  bool _initializing = false;
  String? _initializationError;
  String? get initializationError => _initializationError;
  bool _connecting = false;
  bool get connecting => _connecting;
  int _transportRevision = 0;
  int get transportRevision => _transportRevision;
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
    if (_disposed || _initializing || _initialized) return;
    _initializing = true;
    _initializationError = null;
    _statusSubscription ??= _tailscaleClient.statuses.listen(
      _setTailscaleStatus,
    );
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
      if (tailscaleEnabled) {
        final generation = _connectionGeneration + 1;
        await _startTailscale(restoreOnly: true);
        if (!_current(generation) || !tailscaleConnected) return;
      } else if (savedMode == null && stored == null) {
        return;
      }
      _phase = stored == null ? SetupPhase.server : SetupPhase.ready;
    } on Object {
      if (!_disposed) {
        _initializationError =
            'Could not load your saved sign-in. Please try again.';
      }
    } finally {
      if (!_disposed) {
        _initializing = false;
        _isBusy = false;
        searchServers();
        _notify();
      }
    }
  }

  Future<void> setTailscaleEnabled(bool enabled) {
    if (!initialized || isBusy || enabled == tailscaleEnabled) {
      return Future.value();
    }
    _stopQuickConnect(clear: true);
    _mode = enabled ? ConnectionMode.tailscale : ConnectionMode.direct;
    _manualServer = false;
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

  Future<void> reconnectSession() {
    if (_session == null || !tailscaleEnabled || isBusy || connecting) {
      return Future.value();
    }
    // Reuse the node after a network failure. A missing/expired node can sign
    // in again, without discarding the Jellyfin account.
    return _startTailscale(
      restoreOnly: status.phase != TailscaleConnectionPhase.disconnected,
    );
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
    _connecting = true;
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
        if (_current(generation)) {
          _connecting = false;
          _notify();
        }
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
      if (_session == null) await _mutateSession(sessionStore.clear);
      await connectionStore.write(mode);
      if (!_disposed && (!tailscaleEnabled || tailscaleConnected)) {
        _phase = _session == null ? SetupPhase.server : SetupPhase.ready;
      }
    } on Object catch (error) {
      if (!_disposed) _error = _friendlyError(error);
    } finally {
      _isBusy = false;
      searchServers();
      _notify();
    }
  }

  void back() {
    if (isBusy && _phase != SetupPhase.credentials) return;
    if (_phase == SetupPhase.server &&
        _manualServer &&
        discoveryService != null) {
      _manualServer = false;
      _error = null;
      _notify();
      return;
    }
    _stopQuickConnect(clear: true);
    _formGeneration++;
    _isBusy = false;
    _error = null;
    if (_phase == SetupPhase.credentials) {
      _serverInfo = null;
      _phase = SetupPhase.server;
    } else if (_phase == SetupPhase.server) {
      _stopDiscovery(clear: true);
      _phase = SetupPhase.connection;
    }
    _notify();
  }

  Future<void> checkServer(String value, {String? expectedId}) async {
    if (isBusy || _phase != SetupPhase.server) return;
    _resumeDiscovery = false;
    _stopDiscovery();
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
      if (expectedId != null && info.id != expectedId) {
        throw const JellyfinApiException(
          'This address now belongs to a different server. Search again.',
        );
      }
      _serverInfo = info;
      _serverUrl = url;
      _phase = SetupPhase.credentials;
    } on Object catch (error) {
      if (!_disposed && generation == _formGeneration) {
        _error = _friendlyError(error);
      }
    } finally {
      if (!_disposed && generation == _formGeneration) {
        _isBusy = false;
        _notify();
      }
    }
    if (!_disposed &&
        generation == _formGeneration &&
        _phase == SetupPhase.credentials) {
      if (_foreground) {
        unawaited(startQuickConnect());
      } else {
        _resumeOnForeground = true;
        _quickConnectPhase = QuickConnectPhase.paused;
        _notify();
      }
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    if (isBusy || _serverUrl == null || _phase != SetupPhase.credentials) {
      return;
    }
    pauseQuickConnect();
    if (username.trim().isEmpty || password.isEmpty) {
      _error = 'Enter your Jellyfin username and password.';
      _notify();
      return;
    }
    final generation = ++_formGeneration;
    final url = _serverUrl!;
    _error = null;
    _isBusy = true;
    _notify();
    try {
      final api = await authenticatedApi();
      if (!_formCurrent(generation, url)) return;
      final session = await api.authenticate(
        serverUrl: url,
        username: username.trim(),
        password: password,
      );
      await _commitSession(session, generation, url);
    } on Object catch (error) {
      if (!_disposed && generation == _formGeneration) {
        _error = _friendlyError(error);
      }
    } finally {
      if (!_disposed && generation == _formGeneration) {
        _isBusy = false;
        _notify();
      }
    }
  }

  Future<void> signOut() async {
    _stopQuickConnect(clear: true);
    _formGeneration++;
    await _mutateSession(sessionStore.clear);
    _session = null;
    _manualServer = false;
    _stopDiscovery(clear: true);
    _serverInfo = null;
    _phase = tailscaleEnabled && !tailscaleConnected
        ? SetupPhase.connection
        : SetupPhase.server;
    _error = null;
    searchServers();
    _notify();
  }

  /// Editing, rather than merely focusing a TV field, claims password sign-in.
  void pauseQuickConnect() {
    if (_phase != SetupPhase.credentials) return;
    _resumeOnForeground = false;
    if (_quickConnectPhase == QuickConnectPhase.paused ||
        _quickConnectPhase == QuickConnectPhase.unavailable) {
      return;
    }
    _stopQuickConnect();
    _quickConnectPhase = QuickConnectPhase.paused;
    _notify();
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _resumeDiscovery =
          _discovery.searching && _session == null && !_manualServer;
      if (_resumeDiscovery) _stopDiscovery();
      _resumeOnForeground =
          _phase == SetupPhase.credentials &&
          {
            QuickConnectPhase.checking,
            QuickConnectPhase.waiting,
            QuickConnectPhase.completing,
          }.contains(_quickConnectPhase);
      if (_resumeOnForeground) {
        _stopQuickConnect();
        _quickConnectPhase = QuickConnectPhase.paused;
        _notify();
      }
    } else {
      if (_resumeDiscovery) {
        _resumeDiscovery = false;
        searchServers(again: true, preserveResults: true);
      }
      if (_resumeOnForeground) {
        _resumeOnForeground = false;
        unawaited(startQuickConnect());
      }
    }
  }

  /// Resume checks the existing request first. New-code explicitly replaces it.
  Future<void> startQuickConnect({bool newCode = false}) {
    if (_disposed ||
        !_foreground ||
        isBusy ||
        _phase != SetupPhase.credentials ||
        _serverUrl == null) {
      return Future.value();
    }
    _stopQuickConnect();
    if (newCode) _quickConnectRequest = null;
    _resumeOnForeground = false;
    _quickConnectError = null;
    _quickConnectPhase = QuickConnectPhase.checking;
    final generation = _quickConnectGeneration;
    final url = _serverUrl!;
    _notify();
    return _queueQuickConnect(generation, url, resume: true);
  }

  bool _quickConnectCurrent(int generation, Uri url) =>
      !_disposed &&
      _foreground &&
      _phase == SetupPhase.credentials &&
      _serverUrl == url &&
      generation == _quickConnectGeneration;

  Future<void> _queueQuickConnect(
    int generation,
    Uri url, {
    bool resume = false,
  }) {
    // A paused/replaced HTTP request may still be unwinding. Do not overlap it
    // with a new poll, even when Resume is selected repeatedly.
    _quickConnectTask = _quickConnectTask.then((_) async {
      if (!_quickConnectCurrent(generation, url)) return;
      try {
        final api = await authenticatedApi();
        if (!_quickConnectCurrent(generation, url)) return;
        var request = _quickConnectRequest;
        if (request == null) {
          final enabled = await api.isQuickConnectEnabled(url);
          if (!_quickConnectCurrent(generation, url)) return;
          if (!enabled) {
            _quickConnectPhase = QuickConnectPhase.unavailable;
            return;
          }
          request = await api.initiateQuickConnect(url);
        } else {
          try {
            request = await api.getQuickConnectState(
              serverUrl: url,
              secret: request.secret,
            );
          } on JellyfinApiException catch (error) {
            if (!_quickConnectCurrent(generation, url)) return;
            if (!resume || error.statusCode != 404) rethrow;
            // Explicit resume transparently replaces an expired request.
            _quickConnectRequest = null;
            request = await api.initiateQuickConnect(url);
          }
        }
        if (!_quickConnectCurrent(generation, url)) return;
        _quickConnectRequest = request;
        if (request.authenticated) {
          _quickConnectPhase = QuickConnectPhase.completing;
          _error = null;
          _isBusy = true;
          final authGeneration = ++_formGeneration;
          _notify();
          try {
            final session = await api.authenticateWithQuickConnect(
              serverUrl: url,
              secret: request.secret,
            );
            if (!_quickConnectCurrent(generation, url)) return;
            await _commitSession(session, authGeneration, url);
          } finally {
            if (!_disposed && authGeneration == _formGeneration) {
              _isBusy = false;
            }
          }
        } else {
          _quickConnectPhase = QuickConnectPhase.waiting;
          _quickConnectTimer = Timer(const Duration(seconds: 5), () {
            unawaited(_queueQuickConnect(generation, url));
          });
        }
      } on Object catch (error) {
        if (!_quickConnectCurrent(generation, url)) return;
        final status = error is JellyfinApiException ? error.statusCode : null;
        _quickConnectPhase = switch (status) {
          401 => QuickConnectPhase.unavailable,
          404 => QuickConnectPhase.expired,
          _ => QuickConnectPhase.error,
        };
        if (status == 401 || status == 404) _quickConnectRequest = null;
        _quickConnectError = error is JellyfinApiException
            ? error.message
            : 'Unable to finish Quick Connect. Please retry.';
      } finally {
        if (!_disposed) _notify();
      }
    });
    return _quickConnectTask;
  }

  void _stopQuickConnect({bool clear = false}) {
    _quickConnectTimer?.cancel();
    _quickConnectTimer = null;
    _quickConnectGeneration++;
    if (_quickConnectPhase == QuickConnectPhase.completing) {
      _formGeneration++;
      _isBusy = false;
    }
    if (clear) {
      _quickConnectRequest = null;
      _quickConnectError = null;
      _quickConnectPhase = QuickConnectPhase.idle;
      _resumeOnForeground = false;
    }
  }

  bool _formCurrent(int generation, Uri url) =>
      !_disposed &&
      generation == _formGeneration &&
      _phase == SetupPhase.credentials &&
      _serverUrl == url;

  Future<void> _mutateSession(Future<void> Function() action) {
    final task = _sessionTask.then((_) => action());
    _sessionTask = task.catchError((Object _) {});
    return task;
  }

  Future<void> _commitSession(JellyfinSession value, int generation, Uri url) =>
      _mutateSession(() async {
        if (!_formCurrent(generation, url)) return;
        try {
          await sessionStore.write(value);
        } on Object {
          // A storage write can fail after partially persisting a session.
          await sessionStore.clear();
          rethrow;
        }
        if (!_formCurrent(generation, url)) {
          // Complete cleanup before any subsequent login is allowed to write.
          await sessionStore.clear();
          return;
        }
        _session = value;
        _phase = SetupPhase.ready;
        _stopQuickConnect(clear: true);
        _isBusy = false;
        _notify();
      });

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
      if (_phase == SetupPhase.credentials ||
          (_phase == SetupPhase.server && isBusy)) {
        _stopQuickConnect(clear: true);
        _formGeneration++;
        _isBusy = false;
        _phase = SetupPhase.server;
        _serverInfo = null;
      }
    }
    _status = value;
    if (value.phase == TailscaleConnectionPhase.failed) _error = value.detail;
    if (value.phase == TailscaleConnectionPhase.connected) _error = null;
    if (tailscaleConnected && _session != null) _phase = SetupPhase.ready;
    if (!tailscaleConnected && _phase != SetupPhase.connection) {
      _formGeneration++;
      _phase = SetupPhase.connection;
      _error =
          'Your Tailscale connection was interrupted. Reconnect to continue.';
    }
    searchServers();
    _notify();
  }

  void _closeTransport() {
    _stopDiscovery(clear: true);
    _transportRevision++;
    _httpClient?.close();
    _httpClient = null;
  }

  void _notify() {
    if (!_disposed) {
      authorization.update(_status, attempt: _connectionGeneration);
      notifyListeners();
    }
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
    authorization.dispose();
    _stopDiscovery(clear: true);
    _formGeneration++;
    _stopQuickConnect(clear: true);
    _acceptStatuses = false;
    _connectionGeneration++;
    _statusSubscription?.cancel();
    _closeTransport();
    unawaited(_tailscaleClient.disconnect().catchError((Object _) {}));
    super.dispose();
  }
}
