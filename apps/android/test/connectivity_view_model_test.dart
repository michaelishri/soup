import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';

void main() {
  late FakeTailscaleClient client;
  late MemoryConnectionPreferencesStore preferences;
  late MemorySessionStore sessions;
  late FakeJellyfinClientFactory factory;
  late ConnectivityViewModel model;
  setUp(() {
    client = FakeTailscaleClient();
    preferences = MemoryConnectionPreferencesStore();
    sessions = MemorySessionStore();
    factory = FakeJellyfinClientFactory();
    model = ConnectivityViewModel(
      client,
      jellyfinClientFactory: factory,
      sessionStore: sessions,
      connectionStore: preferences,
    );
  });
  tearDown(() {
    model.dispose();
    client.dispose();
  });

  test(
    'fresh installation does not start Tailscale and persists direct Next',
    () async {
      await model.initialize();
      expect(model.mode, ConnectionMode.direct);
      expect(model.phase, SetupPhase.connection);
      expect(model.canContinueConnection, isTrue);
      expect(client.restores, 0);
      await model.continueConnection();
      expect(preferences.mode, ConnectionMode.direct);
      expect(model.phase, SetupPhase.server);
      await model.checkServer('http://localhost:8096');
      await model.signIn(username: 'Michael', password: 'secret');
      expect(model.phase, SetupPhase.ready);
      expect(factory.modes, [ConnectionMode.direct]);
    },
  );

  test('direct session restores without touching native Tailscale', () async {
    preferences.mode = ConnectionMode.direct;
    sessions.session = testSession;
    await model.initialize();
    expect(model.phase, SetupPhase.ready);
    expect(model.session, testSession);
    expect(client.restores, 0);
    expect(client.disconnects, 0);
    client.emit(const TailscaleStatus.failed('unrelated'));
    expect(model.phase, SetupPhase.ready);
    expect(model.error, isNull);
  });

  test('legacy session restores through Tailscale', () async {
    sessions.session = testSession;
    client.restoreConnected = true;
    await model.initialize();
    expect(model.mode, ConnectionMode.tailscale);
    expect(model.phase, SetupPhase.ready);
    expect(client.restores, 1);
    await model.authenticatedApi();
    expect(factory.modes, [ConnectionMode.tailscale]);
  });

  test(
    'failed restoration reconnects with the saved node and account automatically',
    () async {
      preferences.mode = ConnectionMode.tailscale;
      sessions.session = testSession;
      await model.initialize();
      expect(model.phase, SetupPhase.connection);
      expect(model.tailscaleEnabled, isTrue);
      expect(model.canContinueConnection, isFalse);
      expect(model.error, isNotNull);
      client.restoreConnected = true;
      await model.reconnectSession();
      expect(client.restores, 2);
      expect(client.interactiveConnects, 0);
      expect(model.phase, SetupPhase.ready);
      expect(model.session, testSession);
    },
  );

  test('restored node needs no QR when enabled', () async {
    await model.initialize();
    client.restoreConnected = true;
    await model.setTailscaleEnabled(true);
    expect(model.tailscaleConnected, isTrue);
    expect(client.interactiveConnects, 0);
    expect(model.phase, SetupPhase.connection);
  });

  for (final phase in [
    TailscaleConnectionPhase.starting,
    TailscaleConnectionPhase.awaitingLogin,
    TailscaleConnectionPhase.awaitingApproval,
    TailscaleConnectionPhase.connected,
  ]) {
    test(
      'turning off during $phase allows direct Next and ignores old completion',
      () async {
        await model.initialize();
        client.delayCancellation = true;
        final pending = model.setTailscaleEnabled(true);
        await tick();
        if (phase == TailscaleConnectionPhase.connected) {
          client.emit(FakeTailscaleClient.connectedStatus);
        } else if (phase != TailscaleConnectionPhase.awaitingLogin) {
          client.emit(TailscaleStatus(phase: phase));
        }
        final off = model.setTailscaleEnabled(false);
        expect(model.canContinueConnection, isTrue);
        await model.continueConnection();
        client.complete();
        await Future.wait([pending, off]);
        expect(model.mode, ConnectionMode.direct);
        expect(model.phase, SetupPhase.server);
        expect(model.error, isNull);
        expect(model.status.phase, TailscaleConnectionPhase.disconnected);
      },
    );
  }

  test(
    'rapid toggles serialize startup and only latest attempt can connect',
    () async {
      await model.initialize();
      client.delayCancellation = true;
      final first = model.setTailscaleEnabled(true);
      await tick();
      final off = model.setTailscaleEnabled(false);
      final second = model.setTailscaleEnabled(true);
      await tick();
      expect(client.interactiveConnects, 1);
      client.finishPending();
      await tick();
      expect(client.interactiveConnects, 2);
      expect(model.canContinueConnection, isFalse);
      client.complete();
      await Future.wait([first, off, second]);
      expect(model.canContinueConnection, isTrue);
      expect(model.phase, SetupPhase.connection);
    },
  );

  test('retry replaces a failed attempt', () async {
    await model.initialize();
    client.connectError = StateError('native unavailable');
    await model.setTailscaleEnabled(true);
    expect(model.error, contains('native unavailable'));
    expect(model.canContinueConnection, isFalse);
    client.connectError = null;
    final retry = model.retryTailscale();
    await tick();
    client.complete();
    await retry;
    expect(model.error, isNull);
    expect(model.canContinueConnection, isTrue);
  });

  test(
    'changing mode invalidates server validation and closes old transport',
    () async {
      await model.initialize();
      await model.continueConnection();
      await model.checkServer('http://localhost:8096');
      expect(model.serverInfo, isNotNull);
      model.back();
      model.back();
      client.immediateConnect = true;
      await model.setTailscaleEnabled(true);
      expect(model.serverInfo, isNull);
      expect(factory.closed, 1);
      await model.continueConnection();
      await model.checkServer('http://jellyfin:8096');
      expect(factory.modes, [ConnectionMode.direct, ConnectionMode.tailscale]);
    },
  );

  test(
    'switching a failed restored account to direct clears its stored session',
    () async {
      preferences.mode = ConnectionMode.tailscale;
      sessions.session = testSession;
      await model.initialize();
      await model.setTailscaleEnabled(false);
      await model.continueConnection();
      expect(sessions.session, isNull);
      expect(preferences.mode, ConnectionMode.direct);
      expect(model.phase, SetupPhase.server);
    },
  );

  test(
    'lost Tailscale connection returns to recovery without direct fallback',
    () async {
      preferences.mode = ConnectionMode.tailscale;
      sessions.session = testSession;
      client.restoreConnected = true;
      await model.initialize();
      await model.authenticatedApi();
      client.emit(const TailscaleStatus.disconnected());
      expect(model.phase, SetupPhase.connection);
      expect(factory.closed, 1);
      await expectLater(model.authenticatedApi(), throwsA(isA<Exception>()));
      expect(factory.modes, [ConnectionMode.tailscale]);
      client.emit(FakeTailscaleClient.connectedStatus);
      expect(model.phase, SetupPhase.ready);
      expect(model.session, testSession);
      await model.authenticatedApi();
      expect(factory.modes, [
        ConnectionMode.tailscale,
        ConnectionMode.tailscale,
      ]);
      expect(sessions.clears, 0);
    },
  );

  test(
    'slow restore cannot change transport or erase a saved session',
    () async {
      sessions.session = testSession;
      client.restoreGate = Completer<void>();
      client.restoreConnected = true;
      final loading = model.initialize();
      await tick();
      expect(model.isBusy, isTrue);
      expect(model.canContinueConnection, isFalse);
      await model.setTailscaleEnabled(false);
      await model.continueConnection();
      expect(sessions.session, testSession);
      expect(sessions.clears, 0);
      client.restoreGate!.complete();
      await loading;
      expect(model.phase, SetupPhase.ready);
      expect(model.mode, ConnectionMode.tailscale);
    },
  );

  test(
    'storage error blocks setup and retries without clearing the account',
    () async {
      sessions.session = testSession;
      sessions.readError = StateError('temporarily unavailable');
      preferences.mode = ConnectionMode.direct;
      await model.initialize();
      expect(model.initialized, isFalse);
      expect(model.initializationError, isNotNull);
      await model.continueConnection();
      expect(sessions.clears, 0);
      sessions.readError = null;
      await model.initialize();
      expect(model.phase, SetupPhase.ready);
      expect(model.session, testSession);
      expect(model.initializationError, isNull);
    },
  );
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
