import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';

void main() {
  test('onboarding text and focus contrast across the full-screen canvas', () {
    final colors = SoupTheme.onboarding.colorScheme;
    for (final background in [
      SoupTheme.onboardingBackground,
      SoupTheme.onboardingSurface,
      SoupTheme.onboardingSignal,
      colors.surfaceContainerHighest,
      SoupTheme.onboarding.inputDecorationTheme.fillColor!,
    ]) {
      expect(
        _contrast(colors.onSurface, background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.onSurfaceVariant, background),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrast(colors.primary, background), greaterThanOrEqualTo(4.5));
      expect(
        _contrast(colors.secondary, background),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(
      _contrast(SoupTheme.onboardingSignal, colors.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(SoupTheme.onboardingSignal, colors.onSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(colors.onPrimary, colors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test(
    'all preset and palette combinations provide accessible core colours',
    () {
      for (final preset in UiPreset.values) {
        for (final palette in PaletteFamily.values) {
          for (final brightness in AppearanceBrightness.values) {
            final theme = SoupTheme.authenticated(
              AppearanceSettings(
                preset: preset,
                palette: palette,
                brightness: brightness,
              ),
            );
            final colors = theme.colorScheme;
            final description =
                '${preset.name}/${palette.name}/${brightness.name}';

            expect(
              _contrast(colors.onSurface, colors.surface),
              greaterThanOrEqualTo(4.5),
              reason: '$description surface text',
            );
            expect(
              _contrast(colors.onPrimary, colors.primary),
              greaterThanOrEqualTo(4.5),
              reason: '$description primary controls',
            );
            expect(
              _contrast(colors.primary, colors.surfaceContainerHighest),
              greaterThanOrEqualTo(3),
              reason: '$description focus indicator',
            );
            expect(theme.extension<AuthenticatedThemeTokens>()?.preset, preset);
          }
        }
      }
    },
  );
}

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
