import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as tabs;
import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:url_launcher/url_launcher.dart' as urls;

abstract interface class TailscaleAuthorizationBrowser {
  Future<bool> supportsCustomTabs();
  Future<void> openCustomTab(Uri url);
  Future<bool> openExternal(Uri url);
  Future<void> closeCustomTab();
}

class PlatformTailscaleAuthorizationBrowser
    implements TailscaleAuthorizationBrowser {
  const PlatformTailscaleAuthorizationBrowser();

  @override
  Future<bool> supportsCustomTabs() =>
      urls.supportsLaunchMode(urls.LaunchMode.inAppBrowserView);

  @override
  Future<void> openCustomTab(Uri url) => tabs.launchUrl(
    url,
    customTabsOptions: const tabs.CustomTabsOptions(
      showTitle: true,
      urlBarHidingEnabled: false,
      browser: tabs.CustomTabsBrowserConfiguration(prefersDefaultBrowser: true),
    ),
  );

  @override
  Future<bool> openExternal(Uri url) =>
      urls.launchUrl(url, mode: urls.LaunchMode.externalApplication);

  @override
  Future<void> closeCustomTab() => tabs.closeCustomTabs();
}

/// Owns the browser beyond the lifetime of either sign-in screen. Native node
/// status, never the web page, determines when authorisation has completed.
class TailscaleAuthorizationController extends ChangeNotifier
    with WidgetsBindingObserver {
  TailscaleAuthorizationController({
    this.browser = const PlatformTailscaleAuthorizationBrowser(),
  });

  final TailscaleAuthorizationBrowser browser;
  Uri? _url;
  int? _attempt;
  _BrowserSession? _session;
  bool _pending = false;
  bool _disposed = false;
  bool _observing = false;
  bool failed = false;
  bool externalBrowser = false;
  bool closeFailed = false;

  bool get canOpen =>
      !_disposed && _url != null && !_pending && _session == null;

  void update(TailscaleStatus status, {required int attempt}) {
    if (_disposed) return;
    if (status.phase == TailscaleConnectionPhase.connected &&
        status.proxy == null &&
        _attempt == attempt) {
      return;
    }
    final url = status.phase == TailscaleConnectionPhase.awaitingLogin
        ? status.authorizationUrl
        : null;
    if (_attempt == attempt && _url == url) return;
    _attempt = attempt;
    _url = url;
    failed = false;
    externalBrowser = false;
    final session = _session;
    if (session != null) {
      // Includes success, awaiting admin approval, cancellation and a new link.
      // Serialise dismissal with a pending launch so it cannot close a new tab.
      session.retired = true;
      if (!_pending) unawaited(_dismiss(session));
    }
    _notify();
  }

  Future<void> open() async {
    if (!canOpen) return;
    final session = _BrowserSession(_url!);
    _session = session;
    _pending = true;
    failed = false;
    closeFailed = false;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _notify();
    try {
      var supported = false;
      try {
        supported = await browser.supportsCustomTabs();
      } on Exception {
        // Capability checks can fail on devices without a browser provider.
      }
      if (!_current(session)) return;
      if (supported) {
        try {
          await browser.openCustomTab(session.url);
          session.customTab = true;
        } on Exception {
          // Fall back only while this registration still needs sign-in.
        }
      }
      if (!session.customTab && _current(session)) {
        externalBrowser = true;
        _notify();
        final opened = await browser.openExternal(session.url);
        if (_current(session)) failed = !opened;
      }
    } on Exception {
      if (_current(session)) failed = true;
    } finally {
      if (session.customTab && session.retired && !session.returned) {
        await _close(session);
      }
      _pending = false;
      if (!session.customTab || session.retired || session.returned) {
        _release(session);
      }
      _notify();
    }
  }

  bool _current(_BrowserSession session) =>
      !_disposed && !session.retired && !session.returned;

  Future<void> _dismiss(_BrowserSession session) async {
    _pending = true;
    await _close(session);
    _pending = false;
    _release(session);
    _notify();
  }

  Future<void> _close(_BrowserSession session) async {
    if (!session.customTab || session.returned || session.closing) return;
    session.closing = true;
    try {
      await browser.closeCustomTab();
    } on Exception {
      // The node remains connected. The browser's Back/close still works.
      closeFailed = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = _session;
    if (session == null || session.closing) return;
    if (state == AppLifecycleState.paused) session.departed = true;
    if (state == AppLifecycleState.resumed && session.departed) {
      // Manual Back/close does not cancel the native registration. Permit the
      // same link to reopen, and don't later dismiss an unrelated browser tab.
      session.returned = true;
      if (!_pending) _release(session);
      _notify();
    }
  }

  void _release(_BrowserSession session) {
    if (_session == session) _session = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final session = _session;
    if (session != null) {
      session.retired = true;
      if (!_pending) unawaited(_dismiss(session));
    }
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    super.dispose();
  }
}

class _BrowserSession {
  _BrowserSession(this.url);
  final Uri url;
  bool customTab = false;
  bool retired = false;
  bool departed = false;
  bool returned = false;
  bool closing = false;
}
