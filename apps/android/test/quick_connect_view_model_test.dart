import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup_tailscale/soup_tailscale.dart';
import 'support/connectivity_fakes.dart';
import 'support/quick_connect_fixture.dart';

void main() {
  late QuickConnectFixture fixture;
  late FakeTailscaleClient tailscale;
  late DelayedSessionStore store;
  late ConnectivityViewModel model;
  void initializeFixture() {
    fixture = QuickConnectFixture();
    tailscale = FakeTailscaleClient()..immediateConnect = true;
    store = DelayedSessionStore();
    model = ConnectivityViewModel(
      tailscale,
      jellyfinClientFactory: fixture.factory,
      sessionStore: store,
      connectionStore: MemoryConnectionPreferencesStore(),
    );
  }

  void qcTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      initializeFixture();
      try {
        await body(tester);
      } finally {
        if (!store.modelDisposed) {
          model.dispose();
          store.modelDisposed = true;
        }
      }
    });
  }

  tearDown(() {
    if (!store.modelDisposed) model.dispose();
    tailscale.dispose();
  });
  Future<void> start(WidgetTester tester, {bool privateNetwork = false}) async {
    await model.initialize();
    if (privateNetwork) await model.setTailscaleEnabled(true);
    await model.continueConnection();
    await model.checkServer('http://jellyfin:8096/base/');
    await tester.pump();
  }

  for (final privateNetwork in [false, true]) {
    qcTest('approval advances through transport private=$privateNetwork', (
      tester,
    ) async {
      await start(tester, privateNetwork: privateNetwork);
      expect(model.quickConnectPhase, QuickConnectPhase.waiting);
      expect(model.quickConnectCode, '123456');
      expect(model.isBusy, isFalse);
      await tester.pump(const Duration(seconds: 4));
      expect(fixture.polls, 0);
      fixture.approved = true;
      await tester.pump(const Duration(seconds: 1));
      expect(fixture.polls, 1);
      expect(fixture.exchanges, 1);
      expect(model.phase, SetupPhase.ready);
      expect(model.session?.userName, 'Quick user');
      expect(store.session, model.session);
      expect(model.quickConnectCode, isNull);
      expect(model.isBusy, isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(fixture.polls, 1);
    });
  }
  qcTest('slow polling is serial with five seconds after each response', (
    tester,
  ) async {
    fixture.pendingPoll = Completer();
    await start(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 9));
    expect(fixture.polls, 1);
    fixture.pendingPoll!.complete(fixture.state());
    fixture.pendingPoll = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(fixture.polls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(fixture.polls, 2);
  });
  qcTest('editing discards late approval; Resume checks retained code', (
    tester,
  ) async {
    fixture.pendingPoll = Completer();
    await start(tester);
    await tester.pump(const Duration(seconds: 5));
    model.pauseQuickConnect();
    fixture.pendingPoll!.complete(fixture.state(authenticated: true));
    fixture.pendingPoll = null;
    await tester.pump(const Duration(seconds: 30));
    expect(model.quickConnectPhase, QuickConnectPhase.paused);
    expect(fixture.exchanges, 0);
    expect(store.session, isNull);
    fixture.approved = true;
    await model.startQuickConnect();
    expect(fixture.initiations, 1);
    expect(model.phase, SetupPhase.ready);
  });
  qcTest('Resume queues behind an unfinished poll without overlapping', (
    tester,
  ) async {
    fixture.pendingPoll = Completer();
    await start(tester);
    await tester.pump(const Duration(seconds: 5));
    model.pauseQuickConnect();
    final resume = model.startQuickConnect();
    await tester.pump();
    expect(fixture.polls, 1);
    fixture.pendingPoll!.complete(fixture.state());
    fixture.pendingPoll = null;
    await resume;
    expect(fixture.polls, 2);
    expect(model.quickConnectPhase, QuickConnectPhase.waiting);
  });
  qcTest('foreground resumes only previously active requests', (tester) async {
    fixture.pendingPoll = Completer();
    await start(tester);
    await tester.pump(const Duration(seconds: 5));
    model.setForeground(false);
    fixture.pendingPoll!.complete(fixture.state(authenticated: true));
    fixture.pendingPoll = null;
    await tester.pump(const Duration(seconds: 30));
    expect(fixture.exchanges, 0);
    model.setForeground(true);
    await tester.pump();
    expect(fixture.polls, 2);
    model.pauseQuickConnect();
    model.setForeground(false);
    model.setForeground(true);
    await tester.pump(const Duration(seconds: 30));
    expect(fixture.polls, 2);
    expect(model.quickConnectPhase, QuickConnectPhase.paused);
  });
  qcTest(
    'expiry stops polling and explicit Resume replaces an expired request',
    (tester) async {
      await start(tester);
      fixture.pollStatus = 404;
      await tester.pump(const Duration(seconds: 5));
      expect(model.quickConnectPhase, QuickConnectPhase.expired);
      expect(model.quickConnectCode, isNull);
      await tester.pump(const Duration(seconds: 30));
      expect(fixture.polls, 1);
      await model.startQuickConnect(newCode: true);
      model.pauseQuickConnect();
      await model.startQuickConnect();
      expect(fixture.initiations, 3);
      expect(model.quickConnectPhase, QuickConnectPhase.waiting);
    },
  );
  qcTest('disabled and temporary errors keep password fallback usable', (
    tester,
  ) async {
    fixture.enabled = false;
    await start(tester);
    expect(model.quickConnectPhase, QuickConnectPhase.unavailable);
    expect(fixture.initiations, 0);
    fixture.enabled = true;
    await model.startQuickConnect();
    fixture.pollStatus = 503;
    await tester.pump(const Duration(seconds: 5));
    expect(model.quickConnectPhase, QuickConnectPhase.error);
    expect(model.quickConnectError, isNot(contains('test-secret')));
    await tester.pump(const Duration(seconds: 30));
    expect(fixture.polls, 1);
    await model.signIn(username: 'Michael', password: 'password');
    expect(model.phase, SetupPhase.ready);
    expect(store.session?.userName, 'Michael');
  });
  qcTest('15-second timeout stops polling and ignores its late response', (
    tester,
  ) async {
    fixture.pendingPoll = Completer();
    await start(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 15));
    expect(model.quickConnectPhase, QuickConnectPhase.error);
    expect(model.quickConnectError, isNot(contains('test-secret')));
    fixture.pendingPoll!.complete(fixture.state(authenticated: true));
    fixture.pendingPoll = null;
    await tester.pump();
    expect(fixture.exchanges, 0);
    await model.startQuickConnect();
    expect(model.quickConnectPhase, QuickConnectPhase.waiting);
  });
  qcTest('server verified in background starts Quick Connect on foreground', (
    tester,
  ) async {
    await model.initialize();
    await model.continueConnection();
    model.setForeground(false);
    await model.checkServer('http://jellyfin:8096');
    expect(fixture.initiations, 0);
    model.setForeground(true);
    await tester.pump();
    expect(model.quickConnectPhase, QuickConnectPhase.waiting);
    expect(fixture.initiations, 1);
  });
  qcTest('new server discards an old initiation and creates its own code', (
    tester,
  ) async {
    fixture.pendingInitiation = Completer();
    await start(tester);
    model.back();
    await model.checkServer('http://new-server:8096/other/');
    fixture.pendingInitiation!.complete(fixture.state());
    fixture.pendingInitiation = null;
    await tester.pump();
    expect(fixture.initiations, 2);
    expect(model.serverUrl?.host, 'new-server');
    expect(model.quickConnectCode, '654321');
  });
  for (final interruption in ['back', 'background', 'transport', 'dispose']) {
    qcTest('$interruption during token exchange cannot persist', (
      tester,
    ) async {
      await start(tester, privateNetwork: interruption == 'transport');
      fixture.approved = true;
      fixture.pendingExchange = Completer();
      await tester.pump(const Duration(seconds: 5));
      expect(model.quickConnectPhase, QuickConnectPhase.completing);
      switch (interruption) {
        case 'back':
          model.back();
        case 'background':
          model.setForeground(false);
        case 'transport':
          tailscale.emit(const TailscaleStatus.disconnected());
        case 'dispose':
          model.dispose();
          store.modelDisposed = true;
      }
      fixture.pendingExchange!.complete(QuickConnectFixture.session());
      await tester.pump();
      expect(store.session, isNull);
      expect(store.writes, 0);
      expect(model.session, isNull);
    });
  }
  qcTest('stale write clears before a newer password login commits', (
    tester,
  ) async {
    await start(tester);
    store.pendingWrite = Completer();
    fixture.approved = true;
    await tester.pump(const Duration(seconds: 5));
    expect(store.writes, 1);
    model.back();
    await model.checkServer('http://second-server:8096');
    final signIn = model.signIn(username: 'Michael', password: 'password');
    await tester.pump();
    expect(store.writes, 1);
    store.pendingWrite!.complete();
    store.pendingWrite = null;
    await signIn;
    expect(store.events, [
      'clear',
      'write:Quick user',
      'clear',
      'write:Michael',
    ]);
    expect(store.session?.serverUrl.host, 'second-server');
    expect(store.session?.userName, 'Michael');
    expect(model.phase, SetupPhase.ready);
  });
  qcTest('disposal during storage clears a stale session', (tester) async {
    await start(tester);
    store.pendingWrite = Completer();
    fixture.approved = true;
    await tester.pump(const Duration(seconds: 5));
    model.dispose();
    store.modelDisposed = true;
    store.pendingWrite!.complete();
    await tester.pump();
    expect(store.session, isNull);
  });
  qcTest('partial storage failure clears session and permits retry', (
    tester,
  ) async {
    await start(tester);
    store.failWrite = true;
    fixture.approved = true;
    await tester.pump(const Duration(seconds: 5));
    expect(store.session, isNull);
    expect(model.phase, SetupPhase.credentials);
    expect(model.quickConnectPhase, QuickConnectPhase.error);
    expect(model.isBusy, isFalse);
    store.failWrite = false;
    await model.startQuickConnect();
    expect(model.phase, SetupPhase.ready);
  });
}

class DelayedSessionStore extends MemorySessionStore {
  Completer<void>? pendingWrite;
  bool modelDisposed = false;
  bool failWrite = false;
  int writes = 0;
  final events = <String>[];
  @override
  Future<void> write(JellyfinSession value) async {
    writes++;
    events.add('write:${value.userName}');
    if (pendingWrite != null) await pendingWrite!.future;
    await super.write(value);
    if (failWrite) throw StateError('test storage failure');
  }

  @override
  Future<void> clear() async {
    events.add('clear');
    await super.clear();
  }
}
