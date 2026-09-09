import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/features/connectivity/tailscale_authorization_controller.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final first = Uri.parse('https://login.tailscale.com/a/first');
  final second = Uri.parse('https://login.tailscale.com/a/second');
  late _Browser browser;
  late TailscaleAuthorizationController controller;

  setUp(() {
    browser = _Browser();
    controller = TailscaleAuthorizationController(browser: browser)
      ..update(TailscaleStatus.awaitingLogin(first), attempt: 1);
  });
  tearDown(() => controller.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  for (final status in [
    FakeTailscaleClient.connectedStatus,
    const TailscaleStatus.awaitingApproval(),
  ]) {
    test(
      'dismisses once on ${status.phase}, without a button mounted',
      () async {
        await controller.open();
        expect(browser.tabs, [first]);
        expect(controller.canOpen, isFalse);
        controller.update(status, attempt: 1);
        await flush();
        controller.update(status, attempt: 1);
        expect(browser.closes, 1);
        expect(browser.external, isEmpty);
      },
    );
    test(
      'waits for launch acknowledgement before closing ${status.phase}',
      () async {
        browser.launchGate = Completer<void>();
        final launch = controller.open();
        await flush();
        controller.update(status, attempt: 1);
        expect(browser.closes, 0);
        browser.launchGate!.complete();
        await launch;
        expect(browser.closes, 1);
        expect(browser.external, isEmpty);
      },
    );
  }

  test('waits for a usable proxy before returning', () async {
    await controller.open();
    controller.update(
      const TailscaleStatus(phase: TailscaleConnectionPhase.connected),
      attempt: 1,
    );
    expect(browser.closes, 0);
    controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
    await flush();
    expect(browser.closes, 1);
  });

  test(
    'transient starting retains the tab until the native connection is usable',
    () async {
      await controller.open();
      controller.update(const TailscaleStatus.starting(), attempt: 1);
      await flush();
      expect(browser.closes, 0);
      controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
      await flush();
      expect(browser.closes, 1);
    },
  );

  test(
    'double taps and refreshed links cannot overlap browser operations',
    () async {
      browser.launchGate = Completer<void>();
      browser.closeGate = Completer<void>();
      final opening = controller.open();
      await flush();
      await controller.open();
      controller.update(TailscaleStatus.awaitingLogin(second), attempt: 2);
      await controller.open();
      expect(browser.tabs, [first]);
      browser.launchGate!.complete();
      await flush();
      expect(browser.closes, 1);
      expect(controller.canOpen, isFalse);
      browser.closeGate!.complete();
      await opening;
      browser.launchGate = null;
      browser.closeGate = null;
      await controller.open();
      expect(browser.tabs, [first, second]);
      expect(browser.closes, 1);
    },
  );

  test('manual return permits reopening the same registration', () async {
    await controller.open();
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.canOpen, isFalse);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(controller.canOpen, isTrue);
    await controller.open();
    expect(browser.tabs, [first, first]);
    controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
    await flush();
    expect(browser.closes, 1);
  });

  test(
    'manual return before launch acknowledgement prevents stale close',
    () async {
      browser.launchGate = Completer<void>();
      final opening = controller.open();
      await flush();
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
      browser.launchGate!.complete();
      await opening;
      expect(browser.closes, 0);
    },
  );

  for (final throws in [false, true]) {
    test('external fallback for unavailable/failed tabs ($throws)', () async {
      browser.supported = throws;
      browser.launchFails = throws;
      await controller.open();
      expect(browser.external, [first]);
      expect(controller.externalBrowser, isTrue);
      controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
      await flush();
      expect(browser.closes, 0);
    });
  }

  test('failed external launch is retryable', () async {
    browser.supported = false;
    browser.externalSucceeds = false;
    await controller.open();
    expect(controller.failed, isTrue);
    expect(controller.canOpen, isTrue);
    browser.externalSucceeds = true;
    await controller.open();
    expect(controller.failed, isFalse);
    expect(browser.external, [first, first]);
  });

  test('completion during preflight never opens a browser', () async {
    browser.supportGate = Completer<bool>();
    final opening = controller.open();
    controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
    browser.supportGate!.complete(true);
    await opening;
    expect(browser.tabs, isEmpty);
    expect(browser.external, isEmpty);
  });

  test('a retired failed launch cannot fall back to the old link', () async {
    browser.launchGate = Completer<void>();
    final opening = controller.open();
    await flush();
    controller.update(TailscaleStatus.awaitingLogin(second), attempt: 2);
    browser.launchGate!.completeError(Exception('launch failed'));
    await opening;
    expect(browser.external, isEmpty);
    expect(controller.failed, isFalse);
    expect(controller.canOpen, isTrue);
  });

  test(
    'dismissal errors preserve completion and do not retry dismissal',
    () async {
      browser.closeFails = true;
      await controller.open();
      controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
      await flush();
      expect(controller.closeFailed, isTrue);
      expect(controller.failed, isFalse);
      expect(controller.canOpen, isFalse);
      controller.update(FakeTailscaleClient.connectedStatus, attempt: 1);
      expect(browser.closes, 1);
    },
  );

  test('cancelling a pending launch closes it after acknowledgement', () async {
    browser.launchGate = Completer<void>();
    final opening = controller.open();
    await flush();
    controller.update(const TailscaleStatus.disconnected(), attempt: 2);
    browser.launchGate!.complete();
    await opening;
    expect(browser.closes, 1);
    expect(controller.canOpen, isFalse);
  });

  test('disposal invalidates pending launch callbacks', () async {
    final disposed = TailscaleAuthorizationController(browser: browser)
      ..update(TailscaleStatus.awaitingLogin(first), attempt: 1);
    browser.launchGate = Completer<void>();
    final opening = disposed.open();
    await flush();
    disposed.dispose();
    browser.launchGate!.complete();
    await opening;
    expect(browser.closes, 1);
    expect(browser.external, isEmpty);
    expect(disposed.canOpen, isFalse);
  });
}

class _Browser implements TailscaleAuthorizationBrowser {
  bool supported = true;
  bool launchFails = false;
  bool externalSucceeds = true;
  bool closeFails = false;
  Completer<bool>? supportGate;
  Completer<void>? launchGate;
  Completer<void>? closeGate;
  final tabs = <Uri>[];
  final external = <Uri>[];
  int closes = 0;

  @override
  Future<bool> supportsCustomTabs() async =>
      supportGate == null ? supported : await supportGate!.future;
  @override
  Future<void> openCustomTab(Uri url) async {
    tabs.add(url);
    if (launchGate != null) await launchGate!.future;
    if (launchFails) throw Exception('launch failed');
  }

  @override
  Future<bool> openExternal(Uri url) async {
    external.add(url);
    return externalSucceeds;
  }

  @override
  Future<void> closeCustomTab() async {
    closes++;
    if (closeGate != null) await closeGate!.future;
    if (closeFails) throw Exception('close failed');
  }
}
