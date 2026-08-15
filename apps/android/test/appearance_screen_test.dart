import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/features/appearance/appearance_screen.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';

void main() {
  testWidgets('selects a palette and brightness before continuing', (
    tester,
  ) async {
    AppearanceSettings? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: SoupTheme.onboarding,
        home: AppearanceScreen(
          initialSettings: AppearanceSettings.defaults,
          saving: false,
          onContinue: (value) async => selected = value,
        ),
      ),
    );

    expect(find.text('Fruity'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('palette-ocean')));
    await tester.tap(find.text('Light'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('appearance-continue')),
    );
    await tester.tap(find.byKey(const ValueKey('appearance-continue')));
    await tester.pump();

    expect(selected?.preset, UiPreset.fruity);
    expect(selected?.palette, PaletteFamily.ocean);
    expect(selected?.brightness, AppearanceBrightness.light);
  });

  testWidgets('fits the appearance step on Android TV', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoupTheme.onboarding,
        home: AppearanceScreen(
          initialSettings: AppearanceSettings.defaults,
          saving: false,
          onContinue: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('appearance-continue')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
