import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup/src/data/soup/soup_session_store.dart';
import 'package:soup_identity/soup_identity.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

enum SoupDeviceLinkPhase {
  idle,
  starting,
  waiting,
  refreshing,
  loadingRoster,
  connectingTransport,
  exchanging,
  ready,
  expired,
  error,
  /// Soup refresh is dead; Google device-link UI required.
  needsGoogleSignIn,
}

/// Soup Identity device-link + Pattern A Jellyfin exchange (Wave 3).
///
/// Flow: device-link → roster (auto-select first server) → optional auth-key
/// Tailscale join → POST /v1/assertions → POST /SoupAuth/Exchange →
/// persist [JellyfinSession]. Cold start restores Soup session and can silently
/// re-exchange when the Jellyfin token fails.
class SoupDeviceLinkViewModel extends ChangeNotifier {
  SoupDeviceLinkViewModel({
    required SoupIdentityClient client,
    required SoupSessionStore sessionStore,
    required SessionStore jellyfinSessionStore,
    required this._jellyfinApiProvider,
    TailscaleClient? tailscaleClient,
    this.connectTransportGrants = true,
    this.performJellyfinExchange = true,
  }) : _client = client,
       _sessionStore = sessionStore,
       _jellyfinSessionStore = jellyfinSessionStore,
       _tailscaleClient = tailscaleClient;

  final SoupIdentityClient _client;
  final SoupSessionStore _sessionStore;
  final SessionStore _jellyfinSessionStore;
  final Future<JellyfinApi> Function() _jellyfinApiProvider;
  final TailscaleClient? _tailscaleClient;
  final bool connectTransportGrants;
  final bool performJellyfinExchange;

  SoupDeviceLinkPhase _phase = SoupDeviceLinkPhase.idle;
  SoupDeviceLinkPhase get phase => _phase;

  DeviceLinkStart? _link;
  DeviceLinkStart? get link => _link;

  SoupSession? _session;
  SoupSession? get session => _session;

  ServerRoster? _roster;
  ServerRoster? get roster => _roster;

  RosterServer? _selectedServer;
  RosterServer? get selectedServer => _selectedServer;

  JellyfinSession? _jellyfinSession;
  JellyfinSession? get jellyfinSession => _jellyfinSession;

  /// True after a successful auth-key join from a roster transport grant.
  bool _transportConnected = false;
  bool get transportConnected => _transportConnected;

  String? _transportServerId;
  String? get transportServerId => _transportServerId;

  String? _transportError;
  String? get transportError => _transportError;

  String? _exchangeError;
  String? get exchangeError => _exchangeError;

  String? _error;
  String? get error => _error;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _busy = false;
  bool get isBusy => _busy;

  /// Soup session present and Jellyfin exchange completed (or skipped).
  bool get isFullyReady =>
      _phase == SoupDeviceLinkPhase.ready &&
      _session != null &&
      (!performJellyfinExchange || _jellyfinSession != null);

  /// Show Google QR / progress / exchange retry instead of legacy onboarding.
  bool get showsAuthShell {
    if (_session == null ||
        _phase == SoupDeviceLinkPhase.needsGoogleSignIn) {
      return true;
    }
    switch (_phase) {
      case SoupDeviceLinkPhase.starting:
      case SoupDeviceLinkPhase.waiting:
      case SoupDeviceLinkPhase.loadingRoster:
      case SoupDeviceLinkPhase.connectingTransport:
      case SoupDeviceLinkPhase.exchanging:
      case SoupDeviceLinkPhase.refreshing:
      case SoupDeviceLinkPhase.expired:
      case SoupDeviceLinkPhase.error:
        return true;
      case SoupDeviceLinkPhase.ready:
        return performJellyfinExchange && _jellyfinSession == null;
      case SoupDeviceLinkPhase.idle:
      case SoupDeviceLinkPhase.needsGoogleSignIn:
        return false;
    }
  }

  Timer? _pollTimer;
  int _generation = 0;
  bool _disposed = false;
  bool _foreground = true;

  Future<void> initialize() async {
    if (_disposed || _initialized) return;
    _busy = true;
    _notify();
    try {
      final stored = await _sessionStore.read();
      if (_disposed) return;
      _session = stored;
      _jellyfinSession = await _jellyfinSessionStore.read();
      _initialized = true;
      if (stored != null) {
        _phase = SoupDeviceLinkPhase.loadingRoster;
        _notify();
        await _hydrateFromStoredSession(stored);
      }
    } on Object {
      if (!_disposed) {
        _error = 'Could not load your Soup sign-in. Please try again.';
        _initialized = true;
      }
    } finally {
      if (!_disposed) {
        _busy = false;
        _notify();
      }
    }
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_phase == SoupDeviceLinkPhase.waiting && _link != null) {
      _schedulePoll(immediate: true);
    }
  }

  Future<void> startDeviceLink({bool newCode = false}) {
    if (_disposed || _busy) return Future.value();
    if (!newCode && _phase == SoupDeviceLinkPhase.waiting && _link != null) {
      return Future.value();
    }
    final generation = ++_generation;
    _busy = true;
    _error = null;
    _exchangeError = null;
    _phase = SoupDeviceLinkPhase.starting;
    _pollTimer?.cancel();
    _pollTimer = null;
    _notify();

    return () async {
      try {
        final start = await _client.startDeviceLink();
        if (_disposed || generation != _generation) return;
        _link = start;
        _phase = SoupDeviceLinkPhase.waiting;
        _busy = false;
        _notify();
        _schedulePoll(immediate: true);
      } on Object catch (error) {
        if (_disposed || generation != _generation) return;
        _phase = SoupDeviceLinkPhase.error;
        _error = _friendlyError(error);
        _busy = false;
        _notify();
      }
    }();
  }

  void _schedulePoll({bool immediate = false}) {
    _pollTimer?.cancel();
    final link = _link;
    if (link == null || !_foreground) return;
    final delay = immediate
        ? Duration.zero
        : Duration(seconds: link.interval.clamp(1, 60));
    _pollTimer = Timer(delay, () => unawaited(_poll(link.deviceCode)));
  }

  Future<void> _poll(String deviceCode) async {
    if (_disposed || !_foreground || _phase != SoupDeviceLinkPhase.waiting) {
      return;
    }
    final generation = _generation;
    try {
      final poll = await _client.pollDeviceLink(deviceCode);
      if (_disposed || generation != _generation) return;
      switch (poll.status) {
        case DeviceLinkStatus.pending:
          _schedulePoll();
        case DeviceLinkStatus.expired:
          _phase = SoupDeviceLinkPhase.expired;
          _error = 'This code has expired. Get a new code to continue.';
          _notify();
        case DeviceLinkStatus.approved:
          final tokens = poll.tokens;
          if (tokens == null) {
            _phase = SoupDeviceLinkPhase.error;
            _error = 'Soup approved the device but returned no tokens.';
            _notify();
            return;
          }
          await _complete(tokens, generation);
      }
    } on SoupIdentityException catch (error) {
      if (_disposed || generation != _generation) return;
      if (error.statusCode == 404) {
        _phase = SoupDeviceLinkPhase.expired;
        _error = 'This code is no longer valid. Get a new code to continue.';
      } else {
        _phase = SoupDeviceLinkPhase.error;
        _error = _friendlyError(error);
      }
      _notify();
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _phase = SoupDeviceLinkPhase.error;
      _error = _friendlyError(error);
      _notify();
    }
  }

  Future<void> _complete(SoupSessionTokens tokens, int generation) async {
    _busy = true;
    _phase = SoupDeviceLinkPhase.loadingRoster;
    _notify();
    try {
      var session = SoupSession.fromTokens(tokens);
      ServerRoster? roster;
      try {
        roster = await _client.listServers(tokens.accessToken);
        final selected = roster.autoSelected;
        if (selected != null) {
          session = session.copyWith(lastServerId: selected.id);
        }
      } on Object {
        roster = null;
      }
      if (_disposed || generation != _generation) return;
      await _sessionStore.write(session);
      if (_disposed || generation != _generation) return;
      _session = session;
      _roster = roster;
      _selectedServer = _resolveSelected(roster, session.lastServerId);
      await _maybeConnectTransport(roster, generation);
      if (_disposed || generation != _generation) return;
      await _maybeExchange(session, generation);
      if (_disposed || generation != _generation) return;
      if (_phase != SoupDeviceLinkPhase.error &&
          _phase != SoupDeviceLinkPhase.needsGoogleSignIn) {
        _phase = SoupDeviceLinkPhase.ready;
      }
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _phase = SoupDeviceLinkPhase.error;
      _error = _friendlyError(error);
    } finally {
      if (!_disposed && generation == _generation) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<void> refreshAndReloadRoster() async {
    final session = _session;
    if (_disposed || session == null || _busy) return;
    final generation = ++_generation;
    _busy = true;
    _phase = SoupDeviceLinkPhase.refreshing;
    _error = null;
    _notify();
    try {
      final tokens = await _client.refreshSession(session.refreshToken);
      if (_disposed || generation != _generation) return;
      var next = SoupSession.fromTokens(
        tokens,
        lastServerId: session.lastServerId,
      );
      final roster = await _client.listServers(tokens.accessToken);
      if (_disposed || generation != _generation) return;
      final selected = roster.autoSelected;
      if (selected != null && next.lastServerId == null) {
        next = next.copyWith(lastServerId: selected.id);
      }
      await _sessionStore.write(next);
      if (_disposed || generation != _generation) return;
      _session = next;
      _roster = roster;
      _selectedServer = _resolveSelected(roster, next.lastServerId);
      await _maybeConnectTransport(roster, generation);
      if (_disposed || generation != _generation) return;
      await _maybeExchange(next, generation);
      if (_disposed || generation != _generation) return;
      if (_phase != SoupDeviceLinkPhase.error &&
          _phase != SoupDeviceLinkPhase.needsGoogleSignIn) {
        _phase = SoupDeviceLinkPhase.ready;
      }
    } on SoupIdentityException catch (error) {
      if (_disposed || generation != _generation) return;
      if (error.statusCode == 401) {
        await _forceGoogleSignIn();
      } else {
        _phase = SoupDeviceLinkPhase.error;
        _error = _friendlyError(error);
      }
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _phase = SoupDeviceLinkPhase.error;
      _error = _friendlyError(error);
    } finally {
      if (!_disposed && generation == _generation) {
        _busy = false;
        _notify();
      }
    }
  }

  /// Silent re-exchange when a stored Jellyfin token fails (401).
  ///
  /// Refreshes Soup access if needed, mints a new assertion, exchanges, and
  /// replaces the Jellyfin session. Returns false when Google UI is required.
  Future<bool> silentReExchange() async {
    if (_disposed || !performJellyfinExchange) return false;
    var session = _session;
    if (session == null) {
      await _forceGoogleSignIn();
      return false;
    }
    final generation = ++_generation;
    _busy = true;
    _phase = SoupDeviceLinkPhase.exchanging;
    _exchangeError = null;
    _error = null;
    _notify();
    try {
      try {
        await _ensureRoster(session, generation);
      } on SoupIdentityException catch (error) {
        if (error.statusCode == 401) {
          final tokens = await _client.refreshSession(session.refreshToken);
          if (_disposed || generation != _generation) return false;
          session = SoupSession.fromTokens(
            tokens,
            lastServerId: session.lastServerId,
          );
          await _sessionStore.write(session);
          if (_disposed || generation != _generation) return false;
          _session = session;
          await _ensureRoster(session, generation);
        } else {
          rethrow;
        }
      }
      if (_disposed || generation != _generation) return false;
      await _maybeConnectTransport(_roster, generation);
      if (_disposed || generation != _generation) return false;
      final exchanged = await _exchangeNow(session, generation);
      if (_disposed || generation != _generation) return false;
      if (!exchanged) {
        _phase = SoupDeviceLinkPhase.error;
        return false;
      }
      _phase = SoupDeviceLinkPhase.ready;
      return true;
    } on SoupIdentityException catch (error) {
      if (_disposed || generation != _generation) return false;
      if (error.statusCode == 401) {
        await _forceGoogleSignIn();
        return false;
      }
      _phase = SoupDeviceLinkPhase.error;
      _error = _friendlyError(error);
      return false;
    } on Object catch (error) {
      if (_disposed || generation != _generation) return false;
      _phase = SoupDeviceLinkPhase.error;
      _error = _friendlyError(error);
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        _busy = false;
        _notify();
      }
    }
  }

  /// Probe stored Jellyfin session; silent re-exchange on 401.
  Future<bool> ensureJellyfinSessionValid() async {
    if (_disposed || !performJellyfinExchange) return true;
    final existing = _jellyfinSession ?? await _jellyfinSessionStore.read();
    if (existing == null) {
      return silentReExchange();
    }
    _jellyfinSession = existing;
    try {
      final api = await _jellyfinApiProvider();
      await api.validateSession(existing);
      return true;
    } on JellyfinApiException catch (error) {
      if (error.statusCode == 401) {
        return silentReExchange();
      }
      rethrow;
    }
  }

  Future<void> clearSession() async {
    _generation++;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _sessionStore.clear();
    await _jellyfinSessionStore.clear();
    if (_disposed) return;
    _session = null;
    _jellyfinSession = null;
    _roster = null;
    _selectedServer = null;
    _link = null;
    _transportConnected = false;
    _transportServerId = null;
    _transportError = null;
    _exchangeError = null;
    _error = null;
    _phase = SoupDeviceLinkPhase.idle;
    _notify();
  }

  Future<void> _hydrateFromStoredSession(SoupSession session) async {
    final generation = _generation;
    try {
      await _ensureRoster(session, generation);
      if (_disposed || generation != _generation) return;
      await _maybeConnectTransport(_roster, generation);
      if (_disposed || generation != _generation) return;
      if (performJellyfinExchange) {
        final existing =
            _jellyfinSession ?? await _jellyfinSessionStore.read();
        if (existing != null) {
          _jellyfinSession = existing;
          try {
            final api = await _jellyfinApiProvider();
            await api.validateSession(existing);
          } on JellyfinApiException catch (error) {
            if (error.statusCode == 401) {
              final ok = await silentReExchange();
              if (!ok) return;
            } else {
              // Keep stored session; library load can retry.
            }
          }
        } else {
          await _maybeExchange(session, generation);
        }
      }
      if (_disposed || generation != _generation) return;
      if (_phase != SoupDeviceLinkPhase.error &&
          _phase != SoupDeviceLinkPhase.needsGoogleSignIn) {
        _phase = SoupDeviceLinkPhase.ready;
      }
      _notify();
    } on SoupIdentityException catch (error) {
      if (error.statusCode == 401) {
        try {
          await refreshAndReloadRoster();
        } on Object {
          await _forceGoogleSignIn();
        }
      } else if (!_disposed) {
        _phase = SoupDeviceLinkPhase.ready;
        _notify();
      }
    } on Object {
      if (!_disposed) {
        _phase = SoupDeviceLinkPhase.ready;
        _notify();
      }
    }
  }

  Future<void> _ensureRoster(SoupSession session, int generation) async {
    final roster = await _client.listServers(session.accessToken);
    if (_disposed || generation != _generation) return;
    _roster = roster;
    _selectedServer = _resolveSelected(roster, session.lastServerId);
    if (_selectedServer != null &&
        session.lastServerId != _selectedServer!.id) {
      final next = session.copyWith(lastServerId: _selectedServer!.id);
      await _sessionStore.write(next);
      if (_disposed || generation != _generation) return;
      _session = next;
    }
  }

  RosterServer? _resolveSelected(ServerRoster? roster, String? lastServerId) {
    if (roster == null || roster.servers.isEmpty) return null;
    if (lastServerId != null) {
      for (final server in roster.servers) {
        if (server.id == lastServerId) return server;
      }
    }
    return roster.autoSelected;
  }

  /// Claimable grant → [connectWithAuthKey] → wait connected.
  Future<void> _maybeConnectTransport(
    ServerRoster? roster,
    int generation,
  ) async {
    final client = _tailscaleClient;
    if (!connectTransportGrants || client == null || roster == null) {
      return;
    }
    if (_transportConnected &&
        client.status.phase == TailscaleConnectionPhase.connected) {
      return;
    }
    final claimable = RosterServer.firstClaimableAuthKey(roster.servers);
    if (claimable == null) return;

    _phase = SoupDeviceLinkPhase.connectingTransport;
    _transportError = null;
    _notify();
    try {
      final material = claimable.grant.material!.trim();
      await client.connectWithAuthKey(authKey: material);
      if (_disposed || generation != _generation) return;
      await client.waitUntilConnected(timeout: const Duration(seconds: 30));
      if (_disposed || generation != _generation) return;
      _transportConnected = true;
      _transportServerId = claimable.server.id;
      _transportError = null;
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      _transportConnected = false;
      _transportServerId = null;
      _transportError =
          'Could not join Tailscale with the Soup transport grant. ${_friendlyError(error)}';
    }
  }

  Future<void> _maybeExchange(SoupSession session, int generation) async {
    if (!performJellyfinExchange) return;
    if (_jellyfinSession != null) return;
    _phase = SoupDeviceLinkPhase.exchanging;
    _exchangeError = null;
    _notify();
    await _exchangeNow(session, generation);
  }

  Future<bool> _exchangeNow(SoupSession session, int generation) async {
    final server = _selectedServer ?? _roster?.autoSelected;
    if (server == null) {
      _exchangeError =
          'No Soup servers yet. Ask the host to invite this Google account.';
      _phase = SoupDeviceLinkPhase.error;
      return false;
    }
    final serverUrl = server.jellyfinServerUrl;
    if (serverUrl == null ||
        !{'http', 'https'}.contains(serverUrl.scheme) ||
        serverUrl.host.isEmpty) {
      _exchangeError =
          'This Soup server has no reachable Jellyfin address yet.';
      _phase = SoupDeviceLinkPhase.error;
      return false;
    }
    try {
      final minted = await _client.mintAssertion(
        accessToken: session.accessToken,
        serverId: server.id,
      );
      if (_disposed || generation != _generation) return false;
      final api = await _jellyfinApiProvider();
      if (_disposed || generation != _generation) return false;
      final jellyfin = await api.exchangeSoupAuth(
        serverUrl: JellyfinApi.parseServerUrl(serverUrl.toString()),
        assertion: minted.assertion,
      );
      if (_disposed || generation != _generation) return false;
      await _jellyfinSessionStore.write(jellyfin);
      if (_disposed || generation != _generation) return false;
      _jellyfinSession = jellyfin;
      _selectedServer = server;
      _exchangeError = null;
      return true;
    } on SoupIdentityException catch (error) {
      if (error.statusCode == 401) rethrow;
      _exchangeError = _friendlyError(error);
      _phase = SoupDeviceLinkPhase.error;
      return false;
    } on Object catch (error) {
      _exchangeError = _friendlyError(error);
      _phase = SoupDeviceLinkPhase.error;
      return false;
    }
  }

  Future<void> _forceGoogleSignIn() async {
    await _sessionStore.clear();
    await _jellyfinSessionStore.clear();
    if (_disposed) return;
    _session = null;
    _jellyfinSession = null;
    _roster = null;
    _selectedServer = null;
    _link = null;
    _transportConnected = false;
    _transportServerId = null;
    _transportError = null;
    _exchangeError = null;
    _error = 'Your Soup sign-in expired. Sign in with Google again.';
    _phase = SoupDeviceLinkPhase.needsGoogleSignIn;
    _notify();
  }

  String _friendlyError(Object error) {
    if (error is SoupIdentityException) {
      return 'Soup Identity is unavailable right now. Check the service, or enable SOUP_IDENTITY_MOCK.';
    }
    if (error is TailscaleException) {
      return redactSecrets(error.message);
    }
    if (error is JellyfinApiException) {
      return redactSecrets(error.message);
    }
    return 'Something went wrong talking to Soup Identity. Please try again.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _client.close();
    super.dispose();
  }
}
