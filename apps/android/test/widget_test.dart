import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/app.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';
import 'support/quick_connect_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const inputChannel = MethodChannel('dev.michaelishri.soup/tv_text_input');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inputChannel, (call) async => false);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inputChannel, null);
  });

  for (final size in [
    const Size(412, 915),
    const Size(960, 540),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets('full-screen optional setup and QR fit at $size', (
      tester,
    ) async {
      final (model, client) = await setup(tester, size: size);
      final canvas = tester.getRect(find.byKey(const ValueKey('setup-canvas')));
      expect(canvas, Offset.zero & size);
      expect(find.byKey(const ValueKey('setup-card')), findsNothing);
      final intro = tester.getRect(find.byKey(const ValueKey('setup-intro')));
      final toggle = tester.getRect(
        find.byKey(const ValueKey('tailscale-toggle')),
      );
      if (size.width >= 840) {
        expect(intro.right, lessThan(toggle.left));
      } else {
        expect(intro.bottom, lessThan(toggle.top));
      }
      expect(find.text('Welcome to Soup'), findsOneWidget);
      expect(button(tester, 'connection-next-button').onPressed, isNotNull);
      final originalNext = tester.getRect(
        find.byKey(const ValueKey('connection-next-button')),
      );
      expect(client.restores, 0);
      expect(client.interactiveConnects, 0);
      expect(
        find.byKey(const ValueKey('tailscale-authorization-qr')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
      await tester.pumpAndSettle();
      expect(model.tailscaleEnabled, isTrue);
      expect(
        find.byKey(const ValueKey('tailscale-authorization-qr')),
        findsOneWidget,
      );
      expect(button(tester, 'connection-next-button').onPressed, isNull);
      expect(find.text('Advanced options'), findsNothing);
      expect(find.text('Open sign-in page'), findsNothing);
      final qr = find.byKey(const ValueKey('tailscale-authorization-qr'));
      await tester.ensureVisible(qr);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('setup-scroll')),
      );
      final retry = tester.getRect(
        find.byKey(const ValueKey('retry-tailscale-login-button')),
      );
      expect(retry.bottom, lessThanOrEqualTo(viewport.bottom + 1));
      final code = tester.getRect(qr);
      expect(code.top, greaterThanOrEqualTo(viewport.top - 1));
      expect(code.bottom, lessThanOrEqualTo(viewport.bottom + 1));
      final next = tester.getRect(
        find.byKey(const ValueKey('connection-next-button')),
      );
      expect(next.bottom, lessThan(size.height));
      expect(next, originalNext, reason: 'QR reveal must not move navigation');
      expect(next.overlaps(code), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('QR fades in when its URL arrives after preparation', (
    tester,
  ) async {
    final (_, client) = await setup(tester);
    client.preparing = true;
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsNothing,
    );
    client.showQr();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    final qr = find.byKey(const ValueKey('tailscale-authorization-qr'));
    final fades = tester.widgetList<FadeTransition>(
      find.ancestor(of: qr, matching: find.byType(FadeTransition)),
    );
    expect(
      fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsOneWidget,
    );
  });

  testWidgets('step motion keeps one form and stationary navigation', (
    tester,
  ) async {
    await setup(tester);
    final footer = find.byKey(const ValueKey('setup-footer'));
    final originalFooter = tester.getRect(footer);
    final transition = find.byKey(const ValueKey('setup-step-transition'));
    double opacity() => tester.widget<FadeTransition>(transition).opacity.value;
    double offset() => tester
        .widget<Transform>(find.byKey(const ValueKey('setup-step-offset')))
        .transform
        .getTranslation()
        .x;
    expect(opacity(), 1, reason: 'Do not animate the initial page');
    await tester.tap(find.byKey(const ValueKey('connection-next-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(opacity(), inExclusiveRange(0, 1));
    expect(offset(), inExclusiveRange(0, 12));
    expect(tester.getRect(footer), originalFooter);
    expect(find.byKey(const ValueKey('tailscale-toggle')), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server-url-field')))
          .focusNode!
          .hasFocus,
      isTrue,
    );

    // Back is usable during the entrance, without an outgoing form retaining
    // the same scroll controller or focus nodes.
    await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(opacity(), inExclusiveRange(0, 1));
    expect(offset(), inExclusiveRange(-12, 0));
    expect(tester.getRect(footer), originalFooter);
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('tailscale-toggle')),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    expect(offset(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR retires accessibly while success fades in without advancing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final (model, client) = await setup(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('connection-next-button'));
      final originalNext = tester.getRect(next);
      client.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final success = find.byKey(const ValueKey('tailscale-connected'));
      expect(success, findsOneWidget);
      expect(
        tester
            .widgetList<FadeTransition>(
              find.ancestor(of: success, matching: find.byType(FadeTransition)),
            )
            .any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
        isTrue,
      );
      final oldQr = find.byKey(const ValueKey('tailscale-authorization-qr'));
      expect(oldQr, findsOneWidget, reason: 'The old QR is still fading out');
      expect(
        tester
            .widgetList<ExcludeFocus>(
              find.ancestor(of: oldQr, matching: find.byType(ExcludeFocus)),
            )
            .any((widget) => widget.excluding),
        isTrue,
      );
      expect(find.semantics.byLabel('Tailscale sign-in QR code'), findsNothing);
      expect(find.semantics.byLabel('Get a new code'), findsNothing);
      expect(
        find.semantics.byLabel(RegExp('Connected to Tailscale')),
        findsOne,
      );
      expect(button(tester, 'connection-next-button').onPressed, isNotNull);
      expect(tester.getRect(next), originalNext);
      expect(model.phase, SetupPhase.connection);
      await tester.pumpAndSettle();
      expect(oldQr, findsNothing);
      expect(tester.getRect(next), originalNext);
      final toggle = find.byKey(const ValueKey('tailscale-toggle'));
      final material = tester
          .element(toggle)
          .findAncestorWidgetOfExactType<Material>()!;
      expect(material.key, const ValueKey('tailscale-tile-material'));
      expect(material.clipBehavior, Clip.antiAlias);
      expect(tester.getRect(find.byKey(material.key!)), tester.getRect(toggle));
      // The first Select after successful authorization must continue, without
      // toggling Tailscale off or requiring an extra Down press.
      expect(
        button(tester, 'connection-next-button').focusNode!.hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(model.phase, SetupPhase.server);
      expect(model.tailscaleEnabled, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('remote focus ring animates without resizing the toggle', (
    tester,
  ) async {
    await setup(tester);
    final ring = find.byKey(const ValueKey('tailscale-focus-ring'));
    final toggle = find.byKey(const ValueKey('tailscale-toggle'));
    final originalToggle = tester.getRect(toggle);
    Border border() {
      final paint = tester.widget<DecoratedBox>(
        find.descendant(of: ring, matching: find.byType(DecoratedBox)).first,
      );
      return (paint.decoration as BoxDecoration).border! as Border;
    }

    expect(border().top.width, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(border().top.width, inExclusiveRange(1, 2));
    expect(tester.getRect(toggle), originalToggle);
    expect(
      button(tester, 'connection-next-button').style!.animationDuration,
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(border().top.width, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(border().top.width, 2);
    expect(tester.getRect(toggle), originalToggle);
  });

  testWidgets('Back to an established connection focuses Next again', (
    tester,
  ) async {
    final (model, client) = await setup(tester);
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    client.complete();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(
      button(tester, 'connection-next-button').focusNode!.hasFocus,
      isTrue,
    );
    final disconnects = client.disconnects;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.phase, SetupPhase.server);
    expect(client.disconnects, disconnects);
  });

  testWidgets('connected status updates preserve intentional remote focus', (
    tester,
  ) async {
    final (_, client) = await setup(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    client.complete();
    await tester.pumpAndSettle();
    expect(
      button(tester, 'connection-next-button').focusNode!.hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    client.emit(FakeTailscaleClient.connectedStatus);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('tailscale-toggle')),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  testWidgets(
    'TV traversal does not open an editor and Select opens only one',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final input = FakeTvTextInput();
        final (model, _) = await setup(tester, tvTextInput: input);
        await nextToServer(tester);
        expect(find.byType(TextField), findsNothing);
        expect(find.bySemanticsLabel('Server address'), findsOneWidget);
        expect(input.calls, isEmpty);
        final field = find.byKey(const ValueKey('server-url-field'));
        expect(tester.widget<TvTextField>(field).focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(tester.widget<TvTextField>(field).focusNode.hasFocus, isFalse);
        expect(input.calls, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(input.calls, hasLength(1));
        input.complete('http://draft:8096', submitted: false);
        await tester.pumpAndSettle();
        expect(model.phase, SetupPhase.server);
        expect(
          tester.widget<TvTextField>(field).controller.text,
          'http://draft:8096',
        );
        expect(tester.widget<TvTextField>(field).focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        expect(input.calls.last['text'], 'http://draft:8096');
        input.complete('', submitted: false);
        await tester.pumpAndSettle();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'TV invalid server submission restores field focus without reopening IME',
    (tester) async {
      final input = FakeTvTextInput();
      final factory = FakeJellyfinClientFactory();
      final (model, _) = await setup(
        tester,
        tvTextInput: input,
        factory: factory,
      );
      await nextToServer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      input.complete('');
      await tester.pumpAndSettle();
      expect(model.error, isNotNull);
      expect(factory.requests, isEmpty);
      expect(input.calls, hasLength(1));
      expect(
        tester
            .widget<TvTextField>(find.byKey(const ValueKey('server-url-field')))
            .focusNode
            .hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'TV username Next opens password and failed sign-in clears its secret',
    (tester) async {
      final input = FakeTvTextInput();
      final factory = FakeJellyfinClientFactory(
        respond: (request) =>
            request.url.path.endsWith('/Users/AuthenticateByName')
            ? http.Response('Unauthorized', 401)
            : FakeJellyfinClientFactory.defaultResponse(request),
      );
      final (model, _) = await setup(
        tester,
        tvTextInput: input,
        factory: factory,
      );
      await nextToServer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      input.complete('http://jellyfin:8096');
      await tester.pumpAndSettle();
      expect(model.phase, SetupPhase.credentials);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(input.calls.last['label'], 'Username');
      input.complete('Test user');
      await tester.pumpAndSettle();
      expect(input.calls.last['label'], 'Password');
      expect(input.calls.last['obscureText'], isTrue);
      input.complete('wrong-password');
      await tester.pumpAndSettle();
      expect(model.phase, SetupPhase.credentials);
      expect(model.error, isNotNull);
      expect(
        tester
            .widget<TvTextField>(find.byKey(const ValueKey('password-field')))
            .controller
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TvTextField>(find.byKey(const ValueKey('username-field')))
            .controller
            .text,
        'Test user',
      );
      expect(
        tester
            .widget<TvTextField>(find.byKey(const ValueKey('password-field')))
            .focusNode
            .hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'TV pending edit is dismissed and cannot write into a later step',
    (tester) async {
      final input = FakeTvTextInput();
      final (model, _) = await setup(tester, tvTextInput: input);
      await nextToServer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      model.back();
      await tester.pumpAndSettle();
      expect(input.dismissals, 1);
      await nextToServer(tester);
      input.complete('http://stale:8096');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TvTextField>(find.byKey(const ValueKey('server-url-field')))
            .controller
            .text,
        isEmpty,
      );
      expect(model.phase, SetupPhase.server);
    },
  );

  testWidgets(
    'short wide layout handles long server names and exposes progress',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final factory = FakeJellyfinClientFactory(
          respond: (request) {
            final response = FakeJellyfinClientFactory.defaultResponse(request);
            return http.Response(
              response.body.replaceAll(
                'Living Room',
                'The very long name of our family films and television Jellyfin server',
              ),
              response.statusCode,
            );
          },
        );
        await setup(tester, size: const Size(840, 420), factory: factory);
        expect(
          find.bySemanticsLabel('Step 1 of 3: Connection'),
          findsOneWidget,
        );
        await nextToServer(tester);
        expect(find.bySemanticsLabel('Step 2 of 3: Server'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('server-url-field')),
          'http://localhost:8096',
        );
        await tester.tap(find.byKey(const ValueKey('check-server-button')));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Step 3 of 3: Sign in'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('username-field')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('sign-in-button')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('QR approval and success stay on connection until Next', (
    tester,
  ) async {
    final (model, client) = await setup(tester);
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('retry-tailscale-login-button')),
    );
    await tester.pumpAndSettle();
    expect(client.interactiveConnects, 2);
    client.emit(const TailscaleStatus.awaitingApproval());
    await tester.pump();
    expect(find.text('Waiting for device approval'), findsOneWidget);
    expect(button(tester, 'connection-next-button').onPressed, isNull);
    client.complete();
    await tester.pumpAndSettle();
    expect(find.text('Connected to Tailscale'), findsOneWidget);
    expect(model.phase, SetupPhase.connection);
    await tester.tap(find.byKey(const ValueKey('connection-next-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('server-url-field')), findsOneWidget);
  });

  testWidgets('disable pending Tailscale and continue directly', (
    tester,
  ) async {
    final (model, client) = await setup(tester);
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('connection-next-button')));
    await tester.pumpAndSettle();
    client.emit(const TailscaleStatus.failed('late error'));
    await tester.pump();
    expect(model.phase, SetupPhase.server);
    expect(model.mode, ConnectionMode.direct);
    expect(find.text('late error'), findsNothing);
  });

  testWidgets('Back preserves address and username but clears password', (
    tester,
  ) async {
    await setup(tester);
    await nextToServer(tester);
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'http://localhost:8096',
    );
    await tester.tap(find.byKey(const ValueKey('check-server-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'Michael',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-back-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server-url-field')))
          .controller!
          .text,
      'http://localhost:8096',
    );
    await tester.tap(find.byKey(const ValueKey('check-server-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('username-field')))
          .controller!
          .text,
      'Michael',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('password-field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('server paste trims text and reports empty clipboard', (
    tester,
  ) async {
    String clipboard = '  http://localhost:8096\n';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': clipboard} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await setup(tester);
    await nextToServer(tester);
    await tester.tap(find.byKey(const ValueKey('paste-server-url-button')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server-url-field')))
          .controller!
          .text,
      'http://localhost:8096',
    );
    clipboard = '';
    await tester.tap(find.byKey(const ValueKey('paste-server-url-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Clipboard does not contain a server address.'),
      findsOneWidget,
    );
  });

  testWidgets('sign-in failure remains visible above form on short TV', (
    tester,
  ) async {
    final factory = FakeJellyfinClientFactory(
      respond: (request) =>
          request.url.path.endsWith('/Users/AuthenticateByName')
          ? http.Response('Unauthorized', 401)
          : FakeJellyfinClientFactory.defaultResponse(request),
    );
    await setup(tester, size: const Size(960, 540), factory: factory);
    await nextToServer(tester);
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'http://localhost:8096',
    );
    await tester.tap(find.byKey(const ValueKey('check-server-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'Michael',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'bad-password',
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-button')));
    await tester.pumpAndSettle();
    final error = tester.getRect(
      find.byKey(const ValueKey('connection-error')),
    );
    final canvas = tester.getRect(find.byKey(const ValueKey('setup-canvas')));
    expect(canvas.contains(error.topLeft), isTrue);
    expect(canvas.contains(error.bottomRight), isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('password-field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final quickConnect in [false, true]) {
    for (final mode in ConnectionMode.values) {
      testWidgets(
        'complete $mode onboarding with Quick Connect=$quickConnect reaches appearance and library',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final client = FakeTailscaleClient()..immediateConnect = true;
          final store = MemorySessionStore();
          final preferences = MemoryConnectionPreferencesStore();
          final quickFixture = QuickConnectFixture();
          final factory = quickConnect
              ? quickFixture.factory
              : FakeJellyfinClientFactory();
          final database = SoupDatabase.forTesting(
            DatabaseConnection(
              NativeDatabase.memory(),
              closeStreamsSynchronously: true,
            ),
          );
          addTearDown(client.dispose);
          addTearDown(database.close);
          await tester.pumpWidget(
            SoupApp(
              tailscaleClient: client,
              jellyfinClientFactory: factory,
              sessionStore: store,
              connectionStore: preferences,
              appearanceStore: MemoryAppearanceStore(),
              database: database,
            ),
          );
          await tester.pumpAndSettle();
          if (mode == ConnectionMode.tailscale) {
            await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
            await tester.pumpAndSettle();
          }
          await nextToServer(tester);
          await tester.enterText(
            find.byKey(const ValueKey('server-url-field')),
            'http://jellyfin:8096',
          );
          await tester.tap(find.byKey(const ValueKey('check-server-button')));
          await tester.pumpAndSettle();
          if (quickConnect) {
            expect(tester.testTextInput.isVisible, isFalse);
            quickFixture.approved = true;
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
          } else {
            await tester.enterText(
              find.byKey(const ValueKey('username-field')),
              'Michael',
            );
            await tester.enterText(
              find.byKey(const ValueKey('password-field')),
              'not-stored',
            );
            await tester.tap(find.byKey(const ValueKey('sign-in-button')));
            await tester.pumpAndSettle();
          }
          expect(find.text('Make Soup yours'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('appearance-continue')));
          await tester.pumpAndSettle();
          expect(find.text('No playlists yet'), findsOneWidget);
          expect(preferences.mode, mode);
          expect(
            store.session?.accessToken,
            quickConnect ? 'test-token' : 'token',
          );
          expect(factory.modes, [mode]);
          if (mode == ConnectionMode.direct) expect(client.restores, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('D-pad can toggle Tailscale and reach Next after cancellation', (
    tester,
  ) async {
    final (model, _) = await setup(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.tailscaleEnabled, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.tailscaleEnabled, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(model.phase, SetupPhase.server);
  });

  testWidgets('reduced motion and enlarged text work with keyboard inset', (
    tester,
  ) async {
    await setup(tester, size: const Size(412, 915), accessibility: true);
    await tester.ensureVisible(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsOneWidget,
    );
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher).first,
    );
    expect(switcher.duration, Duration.zero);
    expect(
      tester
          .widget<AnimatedContainer>(
            find.byKey(const ValueKey('tailscale-focus-ring')),
          )
          .duration,
      Duration.zero,
    );
    expect(
      button(tester, 'connection-next-button').style!.animationDuration,
      Duration.zero,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('connection-next-button')));
    await tester.pump();
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('setup-step-transition')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<Transform>(find.byKey(const ValueKey('setup-step-offset')))
          .transform
          .getTranslation()
          .x,
      0,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('check-server-button'))).bottom,
      lessThan(595),
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(740, 360),
    const Size(412, 240),
  ]) {
    testWidgets('small viewport $size keeps setup controls reachable', (
      tester,
    ) async {
      await setup(tester, size: size);
      final toggle = find.byKey(const ValueKey('tailscale-toggle'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final qr = find.byKey(const ValueKey('tailscale-authorization-qr'));
      await tester.ensureVisible(qr);
      await tester.pumpAndSettle();
      expect(qr.hitTestable(), findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('connection-next-button'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('server-url-field')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

FilledButton button(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key)));

Future<void> nextToServer(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('connection-next-button')));
  await tester.pumpAndSettle();
}

Future<(ConnectivityViewModel, FakeTailscaleClient)> setup(
  WidgetTester tester, {
  Size size = const Size(1280, 720),
  FakeJellyfinClientFactory? factory,
  bool accessibility = false,
  TvTextInput tvTextInput = const TvTextInput(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = FakeTailscaleClient();
  final model = ConnectivityViewModel(
    client,
    jellyfinClientFactory: factory ?? FakeJellyfinClientFactory(),
    sessionStore: MemorySessionStore(),
    connectionStore: MemoryConnectionPreferencesStore(),
  );
  addTearDown(client.dispose);
  addTearDown(model.dispose);
  await model.initialize();
  await tester.pumpWidget(
    MaterialApp(
      theme: SoupTheme.onboarding,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: accessibility,
          textScaler: TextScaler.linear(accessibility ? 1.5 : 1),
        ),
        child: child!,
      ),
      home: ConnectivityScreen(viewModel: model, tvTextInput: tvTextInput),
    ),
  );
  await tester.pumpAndSettle();
  return (model, client);
}

class FakeTvTextInput extends TvTextInput {
  final calls = <Map<String, Object>>[];
  Completer<TvTextEdit?>? pending;
  int dismissals = 0;

  @override
  Future<bool> isTelevision() async => true;

  @override
  Future<TvTextEdit?> edit({
    required String label,
    required String text,
    required bool obscureText,
    required bool isUrl,
    required bool next,
  }) {
    calls.add({
      'label': label,
      'text': text,
      'obscureText': obscureText,
      'isUrl': isUrl,
      'next': next,
    });
    pending = Completer<TvTextEdit?>();
    return pending!.future;
  }

  void complete(String text, {bool submitted = true}) {
    final result = pending!;
    pending = null;
    result.complete(TvTextEdit(text: text, submitted: submitted));
  }

  @override
  Future<void> dismiss() async => dismissals++;
}
