import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/app.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/appearance/appearance_controller.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/shared/app_status_screen.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';
import 'support/onboarding_fonts.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  late FakeTailscaleClient client;
  late MemorySessionStore sessions;
  late MemoryConnectionPreferencesStore connection;
  late _AppearanceStore appearance;
  late SoupDatabase database;

  setUp(() {
    client = FakeTailscaleClient()..restoreConnected = true;
    sessions = MemorySessionStore(testSession);
    connection = MemoryConnectionPreferencesStore(ConnectionMode.direct);
    appearance = _AppearanceStore();
    database = SoupDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() async {
    client.dispose();
    await database.close();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        jellyfinClientFactory: FakeJellyfinClientFactory(),
        sessionStore: sessions,
        connectionStore: connection,
        appearanceStore: appearance,
        database: database,
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('slow storage and native restore never show onboarding', (
    tester,
  ) async {
    connection.mode = ConnectionMode.tailscale;
    sessions.readGate = Completer<void>();
    client.restoreGate = Completer<void>();
    await mount(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Opening Soup'), findsOneWidget);
    expect(find.byType(ConnectivityScreen), findsNothing);
    sessions.readGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Reconnecting to Tailscale'), findsOneWidget);
    expect(find.byType(ConnectivityScreen), findsNothing);
    client.restoreGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('No playlists yet'), findsOneWidget);
    expect(sessions.clears, 0);
  });

  for (final failedStore in ['session', 'appearance', 'connection']) {
    testWidgets('$failedStore read failure retries without repeating setup', (
      tester,
    ) async {
      if (failedStore == 'session') {
        sessions.readError = StateError('storage busy');
      }
      if (failedStore == 'appearance') appearance.fail = true;
      if (failedStore == 'connection') connection = _ConnectionStore();
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(ConnectivityScreen), findsNothing);
      expect(find.text('Make Soup yours'), findsNothing);
      sessions.readError = null;
      appearance.fail = false;
      if (connection case final _ConnectionStore store) store.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No playlists yet'), findsOneWidget);
      expect(sessions.session, testSession);
      expect(sessions.clears, 0);
    });
  }

  testWidgets(
    'reconnect removes obsolete routes and reopens the saved library',
    (tester) async {
      connection.mode = ConnectionMode.tailscale;
      await mount(tester);
      await tester.pumpAndSettle();
      final context = tester.element(find.text('No playlists yet'));
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Old detail route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      client.emit(const TailscaleStatus.failed('connection interrupted'));
      await tester.pumpAndSettle();
      expect(find.text('Old detail route'), findsNothing);
      expect(find.text('Reconnecting to Tailscale'), findsOneWidget);
      expect(find.byType(ConnectivityScreen), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No playlists yet'), findsOneWidget);
      expect(client.interactiveConnects, 0);
      expect(sessions.clears, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('library startup failure offers a working retry', (tester) async {
    sessions.deviceIdError = StateError('key store busy');
    await mount(tester);
    await tester.pumpAndSettle();
    expect(find.text('Could not open your library'), findsOneWidget);
    sessions.deviceIdError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No playlists yet'), findsOneWidget);
  });

  testWidgets('Back from Settings returns Home and keeps sign-in', (
    tester,
  ) async {
    await mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('No playlists yet'), findsOneWidget);
    expect(sessions.session, testSession);
  });

  testWidgets('pending startup can be disposed safely', (tester) async {
    appearance.gate = Completer<void>();
    sessions.readGate = Completer<void>();
    await mount(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    appearance.gate!.complete();
    sessions.readGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('appearance controller preserves load failure and can retry', () async {
    appearance.fail = true;
    final controller = AppearanceController(appearance);
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.initialized, isFalse);
    expect(controller.loadError, isNotNull);
    appearance.fail = false;
    await controller.initialize();
    expect(controller.settings, AppearanceSettings.defaults);
    expect(controller.loadError, isNull);
  });

  testWidgets('reconnection QR remains usable on small and TV screens', (
    tester,
  ) async {
    for (final size in [const Size(320, 480), const Size(960, 540)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: AppStatusScreen(
            title: 'Reconnecting to Tailscale',
            message: 'Scan to reconnect. Your Jellyfin sign-in is saved.',
            authorizationUrl: Uri.parse(
              'https://login.tailscale.com/a/example',
            ),
            busy: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    tester.view.reset();
  });
}

class _AppearanceStore extends MemoryAppearanceStore {
  _AppearanceStore() : super(AppearanceSettings.defaults);
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<AppearanceSettings?> read() async {
    await gate?.future;
    if (fail) throw StateError('preferences unavailable');
    return super.read();
  }
}

class _ConnectionStore extends MemoryConnectionPreferencesStore {
  _ConnectionStore() : super(ConnectionMode.direct);
  bool fail = true;
  @override
  Future<ConnectionMode?> read() async {
    if (fail) throw StateError('preferences unavailable');
    return super.read();
  }
}
