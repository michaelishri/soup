import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_discovery.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';
import 'support/discovery_fakes.dart';
import 'support/review_fonts.dart';
import 'tv_navigation_test.dart' show focused;
import 'widget_test.dart' show FakeTvTextInput;

void main() {
  setUpAll(loadReviewFonts);

  ConnectivityViewModel makeModel(
    FakeDiscoveryService discovery, {
    MemorySessionStore? sessions,
    FakeTailscaleClient? tailscale,
    ConnectionMode? savedMode,
    ConnectionPreferencesStore? connectionStore,
    FakeJellyfinClientFactory? clients,
  }) {
    final client = tailscale ?? FakeTailscaleClient();
    final model = ConnectivityViewModel(
      client,
      jellyfinClientFactory: clients ?? FakeJellyfinClientFactory(),
      sessionStore: sessions ?? MemorySessionStore(),
      connectionStore:
          connectionStore ?? MemoryConnectionPreferencesStore(savedMode),
      discoveryService: discovery,
    );
    addTearDown(model.dispose);
    addTearDown(client.dispose);
    addTearDown(discovery.dispose);
    return model;
  }

  test(
    'direct discovery begins on server step and does not block manual entry',
    () async {
      final discovery = FakeDiscoveryService();
      final model = makeModel(discovery);
      await model.initialize();
      expect(discovery.runs, isEmpty);
      await model.continueConnection();
      expect(discovery.modes, [ConnectionMode.direct]);
      expect(model.isBusy, isFalse);
      model.enterServerManually();
      expect(discovery.runs.single.cancelled, isTrue);
      expect(model.showingServerDiscovery, isFalse);
      model.back();
      expect(model.showingServerDiscovery, isTrue);
      model.back();
      expect(model.phase, SetupPhase.connection);
    },
  );

  test(
    'connecting Tailscale starts discovery without advancing onboarding',
    () async {
      final discovery = FakeDiscoveryService();
      final tailscale = FakeTailscaleClient()..immediateConnect = true;
      final model = makeModel(discovery, tailscale: tailscale);
      await model.initialize();
      await model.setTailscaleEnabled(true);
      expect(model.phase, SetupPhase.connection);
      expect(model.canContinueConnection, isTrue);
      expect(discovery.modes, [ConnectionMode.tailscale]);
      await model.continueConnection();
      expect(discovery.runs, hasLength(1));
    },
  );

  for (final fail in [false, true]) {
    test(
      'discovery ${fail ? 'failure' : 'completion'} survives saving Next',
      () async {
        final store = _PausedConnectionStore();
        final discovery = FakeDiscoveryService();
        final model = makeModel(
          discovery,
          tailscale: FakeTailscaleClient()..immediateConnect = true,
          connectionStore: store,
        );
        await model.initialize();
        await model.setTailscaleEnabled(true);
        final next = model.continueConnection();
        await store.started.future;
        expect(model.isBusy, isTrue);
        final run = discovery.runs.single;
        if (fail) {
          run.events.addError(StateError('Discovery failed'));
        } else {
          run.emit(
            JellyfinDiscoverySnapshot(
              phase: DiscoveryPhase.complete,
              servers: [discoveryServer()],
            ),
          );
          run.cancel();
        }
        await Future<void>.delayed(Duration.zero);
        store.release.complete();
        await next;
        expect(model.phase, SetupPhase.server);
        expect(
          model.discovery.phase,
          fail ? DiscoveryPhase.unavailable : DiscoveryPhase.complete,
        );
        expect(model.discovery.servers, hasLength(fail ? 0 : 1));
        expect(discovery.runs, hasLength(1));
        model.searchServers(again: true);
        expect(discovery.runs, hasLength(2));
      },
    );
  }

  for (final mode in ConnectionMode.values) {
    test('saved $mode session never starts discovery', () async {
      final discovery = FakeDiscoveryService();
      final model = makeModel(
        discovery,
        sessions: MemorySessionStore(testSession),
        tailscale: FakeTailscaleClient()..restoreConnected = true,
        savedMode: mode,
      );
      await model.initialize();
      expect(model.phase, SetupPhase.ready);
      model.setForeground(false);
      model.setForeground(true);
      expect(discovery.runs, isEmpty);
    });
  }

  test(
    'background cancels and resumes only an active discovery view',
    () async {
      final discovery = FakeDiscoveryService();
      final model = makeModel(discovery);
      await model.initialize();
      await model.continueConnection();
      model.setForeground(false);
      expect(discovery.runs.single.cancelled, isTrue);
      model.setForeground(true);
      expect(discovery.runs, hasLength(2));
      model.enterServerManually();
      model.setForeground(false);
      model.setForeground(true);
      expect(discovery.runs, hasLength(2));
    },
  );

  test(
    'changing transport cancels discovery and discards old results',
    () async {
      final discovery = FakeDiscoveryService();
      final tailscale = FakeTailscaleClient()..immediateConnect = true;
      final model = makeModel(discovery, tailscale: tailscale);
      await model.initialize();
      await model.setTailscaleEnabled(true);
      discovery.runs.single.emit(
        JellyfinDiscoverySnapshot(servers: [discoveryServer()]),
      );
      await Future<void>.delayed(Duration.zero);
      await model.setTailscaleEnabled(false);
      expect(discovery.runs.single.cancelled, isTrue);
      expect(model.discovery.servers, isEmpty);
      await model.continueConnection();
      expect(discovery.modes, [
        ConnectionMode.tailscale,
        ConnectionMode.direct,
      ]);
    },
  );

  test(
    'discovered selection rechecks identity before authentication',
    () async {
      final discovery = FakeDiscoveryService();
      final clients = FakeJellyfinClientFactory(
        respond: (_) => http.Response(
          '{"ServerName":"Different","Version":"10.11.2","Id":"other"}',
          200,
        ),
      );
      final model = makeModel(discovery, clients: clients);
      await model.initialize();
      await model.continueConnection();
      await model.connectDiscoveredServer(discoveryServer());
      expect(model.phase, SetupPhase.server);
      expect(model.error, contains('different server'));
      expect(clients.requests, hasLength(1));
      expect(discovery.runs.single.cancelled, isTrue);
    },
  );

  test('discovered server follows normal login and persistence path', () async {
    final discovery = FakeDiscoveryService();
    final sessions = MemorySessionStore();
    final model = makeModel(discovery, sessions: sessions);
    await model.initialize();
    await model.continueConnection();
    await model.connectDiscoveredServer(discoveryServer());
    expect(model.phase, SetupPhase.credentials);
    await model.signIn(username: 'demo', password: 'test-only');
    expect(model.phase, SetupPhase.ready);
    expect(sessions.session!.serverUrl, discoveryServer().url);
    expect(discovery.runs, hasLength(1));
  });

  test('proxy replacement invalidates an in-flight server selection', () async {
    final response = Completer<http.Response>();
    final discovery = FakeDiscoveryService();
    final tailscale = FakeTailscaleClient()..immediateConnect = true;
    final clients = FakeJellyfinClientFactory(respond: (_) => response.future);
    final model = makeModel(discovery, tailscale: tailscale, clients: clients);
    await model.initialize();
    await model.setTailscaleEnabled(true);
    await model.continueConnection();
    final selection = model.connectDiscoveredServer(discoveryServer());
    await Future<void>.delayed(Duration.zero);
    tailscale.emit(
      const TailscaleStatus.connected(
        hostname: 'new',
        tailnetIp: '100.64.0.1',
        proxy: TailscaleProxy(
          host: '127.0.0.1',
          port: 40000,
          password: 'new-secret',
        ),
      ),
    );
    response.complete(
      http.Response(
        '{"ServerName":"Cinema","Version":"10.11.2","Id":"server-1"}',
        200,
      ),
    );
    await selection;
    expect(model.phase, SetupPhase.server);
    expect(model.isBusy, isFalse);
    expect(model.session, isNull);
    expect(discovery.runs, hasLength(2));
  });

  Future<void> mount(
    WidgetTester tester,
    ConnectivityViewModel model, {
    Size size = const Size(960, 540),
    bool tv = true,
    bool reducedMotion = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SoupTheme.onboarding,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: ConnectivityScreen(
          viewModel: model,
          tvTextInput: tv ? FakeTvTextInput() : const TvTextInput(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
  }

  Future<void> arrow(
    WidgetTester tester,
    LogicalKeyboardKey key, [
    int times = 1,
  ]) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets('results arrive without stealing focus or advancing to sign-in', (
    tester,
  ) async {
    final discovery = FakeDiscoveryService();
    final model = makeModel(discovery);
    await model.initialize();
    await model.continueConnection();
    await mount(tester, model);
    expect(
      focused(find.byKey(const ValueKey('enter-server-manually'))),
      isTrue,
    );
    discovery.runs.single.emit(
      JellyfinDiscoverySnapshot(servers: [discoveryServer()]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      focused(find.byKey(const ValueKey('enter-server-manually'))),
      isTrue,
    );
    await arrow(tester, LogicalKeyboardKey.arrowUp);
    expect(
      focused(find.byKey(const ValueKey('discovered-server-server-1'))),
      isTrue,
    );
    expect(model.phase, SetupPhase.server);
  });

  testWidgets(
    'ready result takes initial focus; credentials Back restores selected card',
    (tester) async {
      final discovery = FakeDiscoveryService();
      final model = makeModel(discovery);
      await model.initialize();
      await model.continueConnection();
      discovery.runs.single.emit(
        JellyfinDiscoverySnapshot(
          servers: [discoveryServer()],
          phase: DiscoveryPhase.complete,
        ),
      );
      await mount(tester, model);
      expect(
        focused(find.byKey(const ValueKey('discovered-server-server-1'))),
        isTrue,
      );
      await arrow(tester, LogicalKeyboardKey.enter);
      expect(model.phase, SetupPhase.credentials);
      model.back();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        focused(find.byKey(const ValueKey('discovered-server-server-1'))),
        isTrue,
      );
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'long server list restores first card visibility (reduced motion: $reduced)',
      (tester) async {
        final discovery = FakeDiscoveryService();
        final model = makeModel(discovery);
        await model.initialize();
        await model.continueConnection();
        discovery.runs.single.emit(
          JellyfinDiscoverySnapshot(
            servers: List.generate(12, (i) => discoveryServer(i + 1)),
            phase: DiscoveryPhase.complete,
          ),
        );
        await mount(tester, model, reducedMotion: reduced);
        await arrow(tester, LogicalKeyboardKey.arrowDown, 10);
        expect(
          focused(find.byKey(const ValueKey('discovered-server-server-11'))),
          isTrue,
        );
        await arrow(tester, LogicalKeyboardKey.arrowUp, 10);
        final first = find.byKey(const ValueKey('discovered-server-server-1'));
        expect(focused(first), isTrue);
        final viewport = tester.getRect(
          find.byKey(const ValueKey('setup-scroll')),
        );
        expect(tester.getRect(first).top, greaterThanOrEqualTo(viewport.top));
        expect(
          tester.getRect(first).bottom,
          lessThanOrEqualTo(viewport.bottom),
        );
        await arrow(tester, LogicalKeyboardKey.arrowUp);
        expect(focused(first), isTrue);
      },
    );
  }

  testWidgets('manual entry preserves address, protocol and Down to Next', (
    tester,
  ) async {
    final discovery = FakeDiscoveryService();
    final model = makeModel(discovery);
    await model.initialize();
    await model.continueConnection();
    await mount(tester, model, tv: false);
    await tester.tap(find.byKey(const ValueKey('enter-server-manually')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'http://cinema.local:8096',
    );
    await tester.pump();
    expect(find.text('http://'), findsOneWidget);
    await arrow(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(find.byKey(const ValueKey('check-server-button'))), isTrue);
    model.back();
    await tester.pump();
    model.enterServerManually();
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server-url-field')))
          .controller!
          .text,
      'cinema.local:8096',
    );
    expect(find.text('http://'), findsOneWidget);
  });

  testWidgets(
    'phone and large text show unsupported and empty states without overflow',
    (tester) async {
      final discovery = FakeDiscoveryService();
      final model = makeModel(discovery);
      await model.initialize();
      await model.continueConnection();
      discovery.runs.single.emit(
        JellyfinDiscoverySnapshot(
          servers: [discoveryServer(1, '10.10.1')],
          phase: DiscoveryPhase.complete,
        ),
      );
      await mount(
        tester,
        model,
        size: const Size(412, 915),
        tv: false,
        textScale: 1.5,
      );
      expect(find.text('Requires Jellyfin 10.11 or newer'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('discovered-server-server-1')),
            )
            .onPressed,
        isNull,
      );
      model.searchServers(again: true);
      discovery.runs.last.emit(
        const JellyfinDiscoverySnapshot(phase: DiscoveryPhase.complete),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Search again'), findsOneWidget);
      expect(find.textContaining('No servers found.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PausedConnectionStore extends MemoryConnectionPreferencesStore {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(ConnectionMode value) async {
    started.complete();
    await release.future;
    await super.write(value);
  }
}
