import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/app.dart';
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
    await tester.tap(find.byKey(const ValueKey('connect-button')));
    await tester.pumpAndSettle();

    expect(client.receivedAuthKey, 'tskey-auth-test');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('auth-key-field')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('Connected as soup-test'), findsOneWidget);
  });
}

class FakeTailscaleClient implements TailscaleClient {
  final _statuses = StreamController<TailscaleStatus>.broadcast();
  TailscaleStatus _status = const TailscaleStatus.disconnected();
  String? receivedAuthKey;

  @override
  Stream<TailscaleStatus> get statuses => _statuses.stream;

  @override
  Future<TailscaleStatus> currentStatus() async => _status;

  @override
  Future<void> connect({required String authKey}) async {
    receivedAuthKey = authKey;
    _status = const TailscaleStatus.connected(
      hostname: 'soup-test',
      tailnetIp: '100.64.0.1',
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
