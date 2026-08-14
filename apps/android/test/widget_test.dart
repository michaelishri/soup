import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/app.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/session/session_store.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

void main() {
  testWidgets('uses the compact setup layout on a phone', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(SoupApp(tailscaleClient: client));
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
    await tester.pumpWidget(SoupApp(tailscaleClient: client));
    await tester.pump();

    expect(find.byKey(const ValueKey('wide-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('root-focus-traversal')), findsOneWidget);
  });

  testWidgets('connects without retaining the one-time auth key in the field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = FakeTailscaleClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(SoupApp(tailscaleClient: client));
    await tester.pump();

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
    String? submittedPassword;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/System/Info/Public')) {
        return http.Response(
          '{"ServerName":"Living Room","Version":"10.11.2","Id":"server-1"}',
          200,
        );
      }
      submittedPassword = (request.body);
      return http.Response(
        '{"AccessToken":"token","ServerId":"server-1","User":{"Id":"user-1","Name":"Michael"}}',
        200,
      );
    });
    addTearDown(client.dispose);
    addTearDown(httpClient.close);
    await tester.pumpWidget(
      SoupApp(
        tailscaleClient: client,
        jellyfinClientFactory: FakeJellyfinClientFactory(httpClient),
        sessionStore: store,
      ),
    );
    await tester.pump();

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

    expect(find.text('Ready for your library'), findsOneWidget);
    expect(passwordField.controller?.text, isEmpty);
    expect(submittedPassword, contains('not-stored'));
    expect(store.session?.accessToken, 'token');
  });
}

class FakeJellyfinClientFactory implements JellyfinClientFactory {
  const FakeJellyfinClientFactory(this.client);

  final http.Client client;

  @override
  http.Client create(TailscaleProxy proxy) => client;
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

  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;

  @override
  TailscaleStatus get status => _status;

  @override
  Future<void> restore() async {}

  @override
  Future<void> connect({required String authKey}) async {
    receivedAuthKey = authKey;
    _status = const TailscaleStatus.connected(
      hostname: 'soup-test',
      tailnetIp: '100.64.0.1',
      proxy: TailscaleProxy(host: '127.0.0.1', port: 32145, password: 'secret'),
    );
    _statuses.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _status = const TailscaleStatus.disconnected();
    _statuses.add(_status);
  }

  void dispose() => _statuses.close();
}
