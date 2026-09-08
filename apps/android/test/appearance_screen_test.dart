import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/features/appearance/appearance_screen.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';

import 'support/onboarding_fonts.dart';

void main() {
  setUpAll(loadOnboardingFonts);
  for (final preset in UiPreset.values) {
    testWidgets('short TV starts at visible $preset and scrolls to Continue', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AppearanceSettings? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: SoupTheme.onboarding,
          home: AppearanceScreen(
            initialSettings: AppearanceSettings(preset: preset),
            saving: false,
            onContinue: (value) async => selected = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final layout = find.text(
        preset == UiPreset.fruity ? 'Fruity' : 'Blockbuster',
      );
      expect(Focus.of(tester.element(layout)).hasFocus, isTrue);
      expect(layout.hitTestable(), findsOneWidget);
      final proceed = find.text('Continue');
      for (
        var presses = 0;
        presses < 6 && !Focus.of(tester.element(proceed)).hasFocus;
        presses++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(Focus.of(tester.element(proceed)).hasFocus, isTrue);
      expect(proceed.hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected?.preset, preset);
    });
  }

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

  testWidgets('offers and saves the Blockbuster layout', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('blockbuster-layout-choice')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('appearance-continue')),
    );
    await tester.tap(find.byKey(const ValueKey('appearance-continue')));
    await tester.pump();

    expect(selected?.preset, UiPreset.blockbuster);
  });
}
