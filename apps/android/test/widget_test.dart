import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/app.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/data/appearance/appearance_store.dart';
import 'package:soup/src/data/cache/soup_database.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/platform/authorization_url_launcher.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

void main() {
  testWidgets('uses the compact setup layout on a phone', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('compact-layout')), findsOneWidget);
    expect(find.text('Connect Soup to your tailnet'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
  });

  testWidgets('uses the wide setup layout on Android TV', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('wide-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('root-focus-traversal')), findsOneWidget);
    expect(find.byKey(const ValueKey('advanced-auth-key')), findsOneWidget);
  });

  testWidgets('pastes and trims an auth key without exposing it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': '  tskey-auth-from-clipboard\n'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    await _openAdvancedAuthKey(tester);
    await tester.tap(find.byKey(const ValueKey('paste-auth-key-button')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-key-field')),
    );
    expect(field.controller?.text, 'tskey-auth-from-clipboard');
    expect(field.obscureText, isTrue);
    expect(find.text('Auth key pasted.'), findsOneWidget);
  });

  testWidgets('reports when the clipboard contains no auth key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': '  \n'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    await _openAdvancedAuthKey(tester);
    await tester.tap(find.byKey(const ValueKey('paste-auth-key-button')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-key-field')),
    );
    expect(field.controller?.text, isEmpty);
    expect(
      find.text('Clipboard does not contain an auth key.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'pastes a server address and preserves it for an empty clipboard',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var clipboardText = '  http://100.64.44.52:8097/\n';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': clipboardText}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final client = FakeTailscaleClient();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        SoupApp(
          tailscaleClient: client,
          appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
        ),
      );
      await tester.pump();
      await _openAdvancedAuthKey(tester);
      await tester.enterText(
        find.byKey(const ValueKey('auth-key-field')),
        'tskey-auth-test',
      );
      await tester.tap(find.byKey(const ValueKey('connect-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paste-server-url-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('server-url-field')),
      );
      expect(field.controller?.text, 'http://100.64.44.52:8097/');
      expect(find.text('Server address pasted.'), findsOneWidget);

      clipboardText = ' \n ';
      await tester.tap(find.byKey(const ValueKey('paste-server-url-button')));
      await tester.pumpAndSettle();

      expect(field.controller?.text, 'http://100.64.44.52:8097/');
      expect(
        find.text('Clipboard does not contain a server address.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('connects without retaining the one-time auth key in the field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    await _openAdvancedAuthKey(tester);
    await tester.enterText(
      find.byKey(const ValueKey('auth-key-field')),
      'tskey-auth-test',
    );
    final authKeyField = tester.widget<TextField>(
      find.byKey(const ValueKey('auth-key-field')),
    );
    await tester.tap(find.byKey(const ValueKey('connect-button')));
    await tester.pumpAndSettle();

    expect(client.receivedAuthKey, 'tskey-auth-test');
    expect(authKeyField.controller?.text, isEmpty);
    expect(find.text('Connected as soup-test'), findsOneWidget);
    expect(find.text('Find your Jellyfin server'), findsOneWidget);
  });

  testWidgets('discovers Jellyfin and clears the password after sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    final store = MemorySessionStore();
    final database = SoupDatabase.forTesting(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    String? submittedPassword;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/System/Info/Public')) {
        return http.Response(
          '{"ServerName":"Living Room","Version":"10.11.2","Id":"server-1"}',
          200,
        );
      }
      if (request.url.path.endsWith('/Users/AuthenticateByName')) {
        submittedPassword = (request.body);
        return http.Response(
          '{"AccessToken":"token","ServerId":"server-1","User":{"Id":"user-1","Name":"Michael"}}',
          200,
        );
      }
      if (request.url.path.endsWith('/Items/Latest')) {
        return http.Response('[]', 200);
      }
      return http.Response('{"Items":[]}', 200);
    });
    addTearDown(client.dispose);
    addTearDown(httpClient.close);
    addTearDown(database.close);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        jellyfinClientFactory: FakeJellyfinClientFactory(httpClient),
        sessionStore: store,
        appearanceStore: MemoryAppearanceStore(),
        database: database,
      ),
    );
    await tester.pump();

    await _openAdvancedAuthKey(tester);
    await tester.enterText(
      find.byKey(const ValueKey('auth-key-field')),
      'tskey-auth-test',
    );
    await tester.tap(find.byKey(const ValueKey('connect-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'http://jellyfin:8096',
    );
    await tester.tap(find.byKey(const ValueKey('check-server-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Living Room'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'Michael',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'not-stored',
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey('password-field')),
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-button')));
    await tester.pumpAndSettle();

    expect(find.text('Make Soup yours'), findsOneWidget);
    expect(find.text('Fruity'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('appearance-continue')));
    await tester.pumpAndSettle();

    expect(find.text('No playlists yet'), findsOneWidget);
    expect(passwordField.controller?.text, isEmpty);
    expect(submittedPassword, contains('not-stored'));
    expect(store.session?.accessToken, 'token');
  });

  testWidgets('keeps a Jellyfin sign-in error inside the TV setup card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/System/Info/Public')) {
        return http.Response(
          '{"ServerName":"Living Room","Version":"10.11.2","Id":"server-1"}',
          200,
        );
      }
      return http.Response('', 401);
    });
    addTearDown(client.dispose);
    addTearDown(httpClient.close);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        jellyfinClientFactory: FakeJellyfinClientFactory(httpClient),
        sessionStore: MemorySessionStore(),
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    await _openAdvancedAuthKey(tester);
    await tester.enterText(
      find.byKey(const ValueKey('auth-key-field')),
      'tskey-auth-test',
    );
    await tester.tap(find.byKey(const ValueKey('connect-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('server-url-field')),
      'http://jellyfin:8096',
    );
    await tester.tap(find.byKey(const ValueKey('check-server-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'Michael',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'incorrect',
    );
    final passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey('password-field')),
    );
    await tester.tap(find.byKey(const ValueKey('sign-in-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not sign in. Check your username and password.'),
      findsOneWidget,
    );
    expect(passwordField.controller?.text, isEmpty);
    final errorRect = tester.getRect(find.byKey(const ValueKey('setup-error')));
    final cardRect = tester.getRect(find.byKey(const ValueKey('setup-card')));
    expect(errorRect.top, greaterThanOrEqualTo(cardRect.top));
    expect(errorRect.bottom, lessThanOrEqualTo(cardRect.bottom));
  });

  testWidgets('shows QR login and opens the authorization URL', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = FakeTailscaleClient()..pauseInteractiveLogin = true;
    final launcher = FakeAuthorizationUrlLauncher();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        authorizationUrlLauncher: launcher,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('connect-interactively-button')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsOneWidget,
    );
    expect(find.text('Waiting for sign-in'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-tailscale-login-button')));
    await tester.pump();
    expect(launcher.opened, [
      Uri.parse('https://login.tailscale.com/a/soup-test'),
    ]);

    await tester.tap(
      find.byKey(const ValueKey('retry-tailscale-login-button')),
    );
    await tester.pump();
    expect(client.interactiveConnects, 2);
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsOneWidget,
    );

    client.emitApprovalRequired();
    await tester.pump();
    expect(find.text('Approve this TV'), findsOneWidget);
    expect(find.text('Waiting for approval'), findsOneWidget);

    client.completeInteractiveLogin();
    await tester.pumpAndSettle();
    expect(find.text('Find your Jellyfin server'), findsOneWidget);
  });

  testWidgets('keeps QR login content inside a short TV card', (tester) async {
    tester.view.physicalSize = const Size(2048, 1152);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final client = FakeTailscaleClient()..pauseInteractiveLogin = true;
    final launcher = FakeAuthorizationUrlLauncher();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        authorizationUrlLauncher: launcher,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('connect-interactively-button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-tailscale-login-button')));
    await tester.pump();

    final cardRect = tester.getRect(find.byKey(const ValueKey('setup-card')));
    final contentFinders = [
      find.text('Finish signing in on another device'),
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      find.byKey(const ValueKey('open-tailscale-login-button')),
      find.byKey(const ValueKey('retry-tailscale-login-button')),
      find.byKey(const ValueKey('cancel-tailscale-login-button')),
    ];
    for (final finder in contentFinders) {
      final contentRect = tester.getRect(finder);
      expect(contentRect.top, greaterThanOrEqualTo(cardRect.top));
      expect(contentRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    }
    final qrRect = tester.getRect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
    );
    expect(qrRect.width, qrRect.height);
    expect(qrRect.width, inInclusiveRange(110, 160));
    expect(launcher.opened, [
      Uri.parse('https://login.tailscale.com/a/soup-test'),
    ]);
  });

  testWidgets('falls back to QR when no Android browser is available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = FakeTailscaleClient()..pauseInteractiveLogin = true;
    final launcher = FakeAuthorizationUrlLauncher(result: false);
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        authorizationUrlLauncher: launcher,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('connect-interactively-button')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('open-tailscale-login-button')));
    await tester.pump();

    expect(
      find.text('No browser is available. Scan the QR code instead.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tailscale-authorization-qr')),
      findsOneWidget,
    );
    client.completeInteractiveLogin();
    await tester.pumpAndSettle();
  });

  testWidgets('cancels an interactive registration attempt', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = FakeTailscaleClient()..pauseInteractiveLogin = true;
    addTearDown(client.dispose);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        appearanceStore: MemoryAppearanceStore(AppearanceSettings.defaults),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('connect-interactively-button')),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('cancel-tailscale-login-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('connect-interactively-button')),
      findsOneWidget,
    );
  });
}

Future<void> _openAdvancedAuthKey(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('advanced-auth-key')));
  await tester.pumpAndSettle();
}

class FakeJellyfinClientFactory implements JellyfinClientFactory {
  const FakeJellyfinClientFactory(this.client);

  final http.Client client;

  @override
  http.Client create({required ConnectionMode mode, TailscaleProxy? proxy}) =>
      client;
}

class MemorySessionStore implements SessionStore {
  JellyfinSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<String> deviceId() async => 'device-1';

  @override
  Future<JellyfinSession?> read() async => session;

  @override
  Future<void> write(JellyfinSession value) async => session = value;
}

class FakeTailscaleClient implements TailscaleClient {
  final _statuses = StreamController<TailscaleStatus>.broadcast();
  TailscaleStatus _status = const TailscaleStatus.disconnected();
  String? receivedAuthKey;
  bool pauseInteractiveLogin = false;
  int interactiveConnects = 0;
  Completer<void>? _interactiveLogin;

  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;

  @override
  TailscaleStatus get status => _status;

  @override
  Future<void> restore() async {}

  @override
  Future<void> connectInteractively() async {
    interactiveConnects++;
    if (pauseInteractiveLogin) {
      _interactiveLogin = Completer<void>();
      _setStatus(
        TailscaleStatus.awaitingLogin(
          Uri.parse('https://login.tailscale.com/a/soup-test'),
        ),
      );
      await _interactiveLogin!.future;
      return;
    }
    _connect();
  }

  @override
  Future<void> connectWithAuthKey({required String authKey}) async {
    receivedAuthKey = authKey;
    _connect();
  }

  void emitApprovalRequired() {
    _setStatus(const TailscaleStatus.awaitingApproval());
  }

  void completeInteractiveLogin() {
    _connect();
    final pending = _interactiveLogin;
    _interactiveLogin = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void _connect() {
    _setStatus(
      const TailscaleStatus.connected(
        hostname: 'soup-test',
        tailnetIp: '100.64.0.1',
        proxy: TailscaleProxy(
          host: '127.0.0.1',
          port: 32145,
          password: 'secret',
        ),
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    final pending = _interactiveLogin;
    _interactiveLogin = null;
    if (pending != null && !pending.isCompleted) pending.complete();
    _setStatus(const TailscaleStatus.disconnected());
  }

  void _setStatus(TailscaleStatus value) {
    _status = value;
    _statuses.add(_status);
  }

  void dispose() {
    final pending = _interactiveLogin;
    if (pending != null && !pending.isCompleted) pending.complete();
    _statuses.close();
  }
}

class FakeAuthorizationUrlLauncher implements AuthorizationUrlLauncher {
  FakeAuthorizationUrlLauncher({this.result = true});

  final bool result;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return result;
  }
}
