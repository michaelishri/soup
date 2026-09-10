import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/soup/soup_session_store.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_screen.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_view_model.dart';
import 'package:soup_identity/soup_identity.dart';

import 'support/connectivity_fakes.dart';

void main() {
  testWidgets('shows QR and user code while waiting', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockSoupIdentityClient(pollsUntilApproved: 100);
    final model = SoupDeviceLinkViewModel(
      client: client,
      sessionStore: MemorySoupSessionStore(),
      jellyfinSessionStore: MemorySessionStore(),
      jellyfinApiProvider: () async => JellyfinApi(
        MockClient((_) async => http.Response('{}', 404)),
        deviceId: 'device',
      ),
      performJellyfinExchange: false,
    );
    await model.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: SoupDeviceLinkScreen(
          viewModel: model,
          onUseDirectLogin: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('soup-device-link-qr')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('soup-device-link-user-code')),
      findsOneWidget,
    );
    expect(find.textContaining('MOCK-'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('soup-device-link-direct-login')),
      findsOneWidget,
    );
    expect(find.text('Sign in with Jellyfin'), findsOneWidget);

    final jellyfinRect = tester.getRect(
      find.byKey(const ValueKey('soup-device-link-direct-login')),
    );
    final newCodeRect = tester.getRect(
      find.byKey(const ValueKey('soup-device-link-new-code')),
    );
    final cardRight = tester
        .getRect(find.byKey(const ValueKey('soup-device-link-qr')))
        .right;
    // New code bottom-left; Jellyfin opt-out bottom-right on the same row.
    expect(jellyfinRect.left, greaterThan(newCodeRect.right));
    expect(
      (jellyfinRect.center.dy - newCodeRect.center.dy).abs(),
      lessThan(24),
    );
    expect(jellyfinRect.right, greaterThan(cardRight - 24));

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}

class MemorySoupSessionStore implements SoupSessionStore {
  MemorySoupSessionStore([this.session]);

  SoupSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<SoupSession?> read() async => session;

  @override
  Future<void> write(SoupSession value) async => session = value;
}
