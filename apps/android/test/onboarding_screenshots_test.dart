import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/connectivity_screen.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/shared/soup_mark.dart';

import 'support/connectivity_fakes.dart';

// Explicitly opt in to generating review artifacts. Ordinary QA never rewrites
// screenshots. Uses real widgets, bundled SDK fonts, and fake network data.
const captureScreenshots = bool.fromEnvironment(
  'UPDATE_ONBOARDING_SCREENSHOTS',
);

void main() {
  if (!captureScreenshots) return;
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await config.readAsString())
                as Map<String, dynamic>)['packages']
            as List<dynamic>;
    final flutter = packages.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['name'] == 'flutter',
    );
    final root = config.absolute.uri.resolve('${flutter['rootUri']}/');
    final directory = root.resolve('../../bin/cache/artifacts/material_fonts/');
    final loader = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      loader.addFont(
        File.fromUri(
          directory.resolve(name),
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
    final icons = FontLoader('packages/phosphoricons_flutter/PhosphorRegular');
    icons.addFont(
      rootBundle.load('packages/phosphoricons_flutter/lib/fonts/Phosphor.ttf'),
    );
    await icons.load();
  });

  for (final (label, size) in [
    ('tv', const Size(960, 540)),
    ('phone', const Size(412, 915)),
  ]) {
    testWidgets('render $label onboarding review screenshots', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = FakeTailscaleClient();
      final model = ConnectivityViewModel(
        client,
        jellyfinClientFactory: FakeJellyfinClientFactory(),
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
            home: ConnectivityScreen(viewModel: model),
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
      await tester.tap(find.byKey(const ValueKey('connection-next-button')));
      await tester.pumpAndSettle();
      await capture('jellyfin-server');
      await tester.enterText(
        find.byKey(const ValueKey('server-url-field')),
        'http://jellyfin:8096',
      );
      await tester.tap(find.byKey(const ValueKey('check-server-button')));
      await tester.pumpAndSettle();
      await capture('jellyfin-sign-in');
    });
  }
}
