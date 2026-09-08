import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';
import 'support/quick_connect_fixture.dart';
import 'widget_test.dart' show setup, FakeTvTextInput, nextToServer;

import 'support/onboarding_fonts.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.michaelishri.soup/tv_text_input');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  for (final size in [
    const Size(960, 540),
    const Size(1280, 720),
    const Size(412, 915),
    const Size(320, 568),
    const Size(740, 360),
  ]) {
    testWidgets('live sign-in panels fit and scroll at $size', (tester) async {
      final fixture = QuickConnectFixture();
      final (model, _) = await setup(
        tester,
        size: size,
        factory: fixture.factory,
      );
      await model.continueConnection();
      await model.checkServer('http://jellyfin:8096');
      await tester.pumpAndSettle();
      expect(find.text('123456'), findsOneWidget);
      final quick = tester.getRect(
        find.byKey(const ValueKey('quick-connect-panel')),
      );
      final password = tester.getRect(
        find.byKey(const ValueKey('password-panel')),
      );
      if (size.width >= 840) {
        expect(quick.width, password.width);
        expect(quick.right, lessThan(password.left));
      } else {
        expect(quick.bottom, lessThan(password.top));
      }
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('password-field')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('password-field')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('sign-in-button')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      model.pauseQuickConnect();
    });
  }
  testWidgets(
    'large text stacks panels and phone editing pauses without losing draft',
    (tester) async {
      final fixture = QuickConnectFixture();
      final (model, _) = await setup(
        tester,
        size: const Size(960, 540),
        factory: fixture.factory,
        accessibility: true,
      );
      await model.continueConnection();
      await model.checkServer('http://jellyfin:8096');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sign-in-split-layout')), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      final field = find.byKey(const ValueKey('username-field'));
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.enterText(field, 'My draft');
      await tester.pumpAndSettle();
      expect(model.quickConnectPhase, QuickConnectPhase.paused);
      fixture.approved = true;
      await tester.pump(const Duration(seconds: 20));
      expect(tester.widget<TextField>(field).controller!.text, 'My draft');
      expect(model.phase, SetupPhase.credentials);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TV focus and polling do not open IME; Select pauses; Back keeps draft',
    (tester) async {
      final fixture = QuickConnectFixture();
      final input = FakeTvTextInput();
      final (model, _) = await setup(
        tester,
        size: const Size(960, 540),
        factory: fixture.factory,
        tvTextInput: input,
      );
      await nextToServer(tester);
      await model.checkServer('http://jellyfin:8096');
      await tester.pumpAndSettle();
      final username = find.byKey(const ValueKey('username-field'));
      expect(tester.widget<TvTextField>(username).focusNode.hasFocus, isTrue);
      expect(input.calls, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(seconds: 5));
      expect(model.quickConnectPhase, QuickConnectPhase.waiting);
      expect(input.calls, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(model.quickConnectPhase, QuickConnectPhase.paused);
      expect(input.calls.last['label'], 'Username');
      input.complete('TV draft', submitted: false);
      await tester.pumpAndSettle();
      expect(model.phase, SetupPhase.credentials);
      expect(model.quickConnectPhase, QuickConnectPhase.paused);
      expect(tester.widget<TvTextField>(username).controller.text, 'TV draft');
      expect(tester.widget<TvTextField>(username).focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.text('Resume Quick Connect'))).hasFocus,
        isTrue,
      );
      // Activate using the public action to exercise the actual Resume button.
      fixture.approved = true;
      await tester.tap(find.text('Resume Quick Connect'));
      await tester.pumpAndSettle();
      expect(model.phase, SetupPhase.ready);
      expect(fixture.exchanges, 1);
    },
  );
  testWidgets('TV code refresh retains action focus after a delayed response', (
    tester,
  ) async {
    final fixture = QuickConnectFixture();
    final (model, _) = await setup(
      tester,
      factory: fixture.factory,
      tvTextInput: FakeTvTextInput(),
    );
    await model.continueConnection();
    await model.checkServer('http://jellyfin:8096');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(
      Focus.of(tester.element(find.text('Get a new code'))).hasFocus,
      isTrue,
    );
    fixture.pendingInitiation = Completer();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    fixture.pendingInitiation!.complete(fixture.state());
    await tester.pumpAndSettle();
    expect(
      Focus.of(tester.element(find.text('Get a new code'))).hasFocus,
      isTrue,
    );
    model.pauseQuickConnect();
  });
  testWidgets('late approval cannot close an active native credential editor', (
    tester,
  ) async {
    final fixture = QuickConnectFixture()..pendingPoll = Completer();
    final input = FakeTvTextInput();
    final (model, _) = await setup(
      tester,
      factory: fixture.factory,
      tvTextInput: input,
    );
    await model.continueConnection();
    await model.checkServer('http://jellyfin:8096');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    fixture.pendingPoll!.complete(fixture.state(authenticated: true));
    await tester.pumpAndSettle();
    expect(input.dismissals, 0);
    expect(input.pending, isNotNull);
    expect(model.quickConnectPhase, QuickConnectPhase.paused);
    input.complete('draft', submitted: false);
    await tester.pumpAndSettle();
  });
  testWidgets('disabled server keeps both panels and can be checked again', (
    tester,
  ) async {
    final fixture = QuickConnectFixture()..enabled = false;
    final (model, _) = await setup(tester, factory: fixture.factory);
    await model.continueConnection();
    await model.checkServer('http://jellyfin:8096');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-connect-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('password-panel')), findsOneWidget);
    expect(find.textContaining('disabled on this server'), findsOneWidget);
    fixture.enabled = true;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('123456'), findsOneWidget);
    model.pauseQuickConnect();
  });
}
