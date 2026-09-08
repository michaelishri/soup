import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/appearance/appearance_screen.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/shared/soup_mark.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';

import 'support/connectivity_fakes.dart';
import 'support/quick_connect_fixture.dart';
import 'support/review_fonts.dart';
import 'widget_test.dart' show FakeTvTextInput;

// Explicitly opt in to generating review artifacts. Ordinary QA never rewrites
// screenshots. Uses real widgets, bundled SDK fonts, and fake network data.
const captureScreenshots = bool.fromEnvironment(
  'UPDATE_ONBOARDING_SCREENSHOTS',
);

void main() {
  if (!captureScreenshots) return;
  setUpAll(loadReviewFonts);

  for (final (label, size) in [
    ('tv', const Size(960, 540)),
    ('phone', const Size(412, 915)),
  ]) {
    testWidgets('render $label onboarding review screenshots', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = FakeTailscaleClient();
      final fixture = QuickConnectFixture();
      final model = ConnectivityViewModel(
        client,
        jellyfinClientFactory: fixture.factory,
        sessionStore: MemorySessionStore(),
        connectionStore: MemoryConnectionPreferencesStore(),
      );
      addTearDown(client.dispose);
      addTearDown(model.dispose);
      await model.initialize();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('screenshot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SoupTheme.onboarding,
            home: ConnectivityScreen(
              viewModel: model,
              tvTextInput: label == 'tv'
                  ? FakeTvTextInput()
                  : const TvTextInput(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(SoupMark.assetName),
          tester.element(find.byType(ConnectivityScreen)),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String state) async {
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('screenshot')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '../../docs/screenshots/onboarding/$state-$label.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('welcome');
      await tester.tap(find.byKey(const ValueKey('tailscale-toggle')));
      await tester.pumpAndSettle();
      await capture('tailscale-qr');
      client.complete();
      await tester.pumpAndSettle();
      await capture('tailscale-connected');
      await tester.tap(find.byKey(const ValueKey('connection-next-button')));
      await tester.pumpAndSettle();
      await capture('jellyfin-server');
      await model.checkServer('http://jellyfin:8096');
      await tester.pumpAndSettle();
      await capture('jellyfin-sign-in');
      model.pauseQuickConnect();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('screenshot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SoupTheme.onboarding,
            home: AppearanceScreen(
              initialSettings: const AppearanceSettings(),
              saving: false,
              onContinue: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture('appearance');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
