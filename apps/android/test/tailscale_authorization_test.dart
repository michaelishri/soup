import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/connectivity/tailscale_authorization_controller.dart';
import 'package:soup/src/features/shared/tailscale_authorization_button.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';
import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/onboarding_fonts.dart';
import 'support/url_launcher_fake.dart';
import 'support/custom_tabs_fake.dart';
import 'widget_test.dart' show setup, button;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadOnboardingFonts);
  const inputChannel = MethodChannel('dev.michaelishri.soup/tv_text_input');
  late FakeUrlLauncher launcher;
  late FakeCustomTabs tabs;
  late UrlLauncherPlatform previousLauncher;
  final action = find.byKey(const ValueKey('tailscale-authorization-button'));
  TailscaleAuthorizationController controller(String code) {
    final value = TailscaleAuthorizationController()
      ..update(
        TailscaleStatus.awaitingLogin(
          Uri.parse('https://login.tailscale.com/a/$code'),
        ),
        attempt: 1,
      );
    addTearDown(value.dispose);
    return value;
  }

  const error = 'Couldn’t open the Tailscale sign-in page. Try again.';

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inputChannel, (_) async => false);
    tabs = FakeCustomTabs()..install();
    previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher = FakeUrlLauncher();
  });
  tearDown(() {
    tabs.uninstall();
    UrlLauncherPlatform.instance = previousLauncher;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(inputChannel, null);
  });

  testWidgets('mobile opens current link and survives the browser round trip', (
    tester,
  ) async {
    launcher.customTabsSupported = true;
    final (model, client) = await setup(tester, size: const Size(412, 915));
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    expect(launcher.launches, isEmpty);
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsNothing,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(launcher.launches, isEmpty);
    expect(tabs.launches, [client.status.authorizationUrl.toString()]);
    expect(client.interactiveConnects, 1);
    final disconnects = client.disconnects;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(client.disconnects, disconnects);
    expect(find.text('Waiting for sign-in'), findsOneWidget);
    expect(button(tester, 'connection-next-button').onPressed, isNull);

    final newLink = find.byKey(const ValueKey('retry-tailscale-login-button'));
    await tester.ensureVisible(newLink);
    await tester.pumpAndSettle();
    await tester.tap(newLink);
    await tester.pumpAndSettle();
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(client.interactiveConnects, 2);
    expect(tabs.launches.last, client.status.authorizationUrl.toString());
    expect(tabs.launches.last, isNot(tabs.launches.first));

    client.emit(const TailscaleStatus.awaitingApproval());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(action, findsNothing);
    expect(button(tester, 'connection-next-button').onPressed, isNull);
    expect(tabs.closes, 1);
    client.complete();
    await tester.pumpAndSettle();
    expect(model.phase, SetupPhase.connection);
    expect(button(tester, 'connection-next-button').onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('connection-next-button')));
    await tester.pumpAndSettle();
    expect(model.phase, SetupPhase.server);
  });

  for (final throws in [false, true]) {
    testWidgets('launch failure is retryable (platform exception: $throws)', (
      tester,
    ) async {
      launcher.handleLaunch = () async {
        if (throws) throw PlatformException(code: 'no_browser');
        return false;
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TailscaleAuthorizationButton(controller: controller('test')),
          ),
        ),
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text(error), findsOneWidget);
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      launcher.handleLaunch = null;
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text(error), findsNothing);
      expect(launcher.launches, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending launch prevents double taps and ignores stale results', (
    tester,
  ) async {
    final pending = Completer<bool>();
    launcher.handleLaunch = () => pending.future;
    final auth = controller('first');
    Future<void> mount() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TailscaleAuthorizationButton(controller: auth)),
      ),
    );
    await mount();
    await tester.tap(action);
    await tester.pump();
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    await tester.tap(action);
    expect(launcher.launches, hasLength(1));
    auth.update(
      TailscaleStatus.awaitingLogin(
        Uri.parse('https://login.tailscale.com/a/second'),
      ),
      attempt: 2,
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    pending.complete(false);
    await tester.pumpAndSettle();
    launcher.handleLaunch = null;
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text(error), findsNothing);
    expect(launcher.launches.last.$1, 'https://login.tailscale.com/a/second');

    final afterDisposal = Completer<bool>();
    launcher.handleLaunch = () => afterDisposal.future;
    await tester.tap(action);
    await tester.pumpWidget(const SizedBox.shrink());
    afterDisposal.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile action retires from semantics during connection success',
    (tester) async {
      launcher.customTabsSupported = true;
      final semantics = tester.ensureSemantics();
      try {
        final (_, client) = await setup(tester);
        await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        client.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(action, findsOneWidget);
        expect(
          find.semantics.byLabel('Authorise device on Tailscale'),
          findsNothing,
        );
        expect(find.semantics.byLabel('Get a new link'), findsNothing);
        await tester.pumpAndSettle();
        expect(action, findsNothing);
        expect(tabs.closes, 1);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('waits for device detection before choosing authorisation UI', (
    tester,
  ) async {
    final input = _PendingDeviceType();
    await setup(tester, tvTextInput: input);
    await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
    await tester.pumpAndSettle();
    expect(action, findsNothing);
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsNothing,
    );
    input.television.complete(true);
    await tester.pumpAndSettle();
    expect(action, findsNothing);
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsOneWidget,
    );
  });
}

class _PendingDeviceType extends TvTextInput {
  final television = Completer<bool>();
  @override
  Future<bool> isTelevision() => television.future;
}
