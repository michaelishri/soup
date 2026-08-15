import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';

class SoupTheme {
  const SoupTheme._();

  static ThemeData get onboarding {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7DD3FC),
      brightness: Brightness.dark,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFF08111F),
      useMaterial3: true,
    );
  }

  static ThemeData authenticated(AppearanceSettings settings) {
    final brightness = settings.brightness == AppearanceBrightness.dark
        ? Brightness.dark
        : Brightness.light;
    final seed = switch (settings.palette) {
      PaletteFamily.soup => const Color(0xFFFC7814),
      PaletteFamily.ocean => const Color(0xFF1E88E5),
      PaletteFamily.grove => const Color(0xFF2E7D32),
      PaletteFamily.mono => const Color(0xFF6B7280),
    };
    final colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    final background = dark
        ? Color.alphaBlend(
            seed.withValues(alpha: 0.06),
            const Color(0xFF07090D),
          )
        : Color.alphaBlend(
            seed.withValues(alpha: 0.035),
            const Color(0xFFF7F7F5),
          );
    final tokens = AuthenticatedThemeTokens(
      preset: settings.preset,
      heroScrimStart: dark ? const Color(0x16000000) : const Color(0x0AFFFFFF),
      heroScrimEnd: dark ? const Color(0xF207090D) : const Color(0xE6F7F7F5),
      playbackChrome: settings.preset == UiPreset.blockbuster
          ? const Color(0xF2000000)
          : const Color(0xD9000000),
      focusGlow: colors.primary.withValues(alpha: dark ? 0.36 : 0.26),
    );
    return ThemeData(
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      extensions: [tokens],
    );
  }
}

@immutable
class AuthenticatedThemeTokens
    extends ThemeExtension<AuthenticatedThemeTokens> {
  const AuthenticatedThemeTokens({
    required this.preset,
    required this.heroScrimStart,
    required this.heroScrimEnd,
    required this.playbackChrome,
    required this.focusGlow,
  });

  final UiPreset preset;
  final Color heroScrimStart;
  final Color heroScrimEnd;
  final Color playbackChrome;
  final Color focusGlow;

  @override
  AuthenticatedThemeTokens copyWith({
    UiPreset? preset,
    Color? heroScrimStart,
    Color? heroScrimEnd,
    Color? playbackChrome,
    Color? focusGlow,
  }) {
    return AuthenticatedThemeTokens(
      preset: preset ?? this.preset,
      heroScrimStart: heroScrimStart ?? this.heroScrimStart,
      heroScrimEnd: heroScrimEnd ?? this.heroScrimEnd,
      playbackChrome: playbackChrome ?? this.playbackChrome,
      focusGlow: focusGlow ?? this.focusGlow,
    );
  }

  @override
  AuthenticatedThemeTokens lerp(
    covariant AuthenticatedThemeTokens? other,
    double t,
  ) {
    if (other == null) return this;
    return AuthenticatedThemeTokens(
      preset: t < 0.5 ? preset : other.preset,
      heroScrimStart: Color.lerp(heroScrimStart, other.heroScrimStart, t)!,
      heroScrimEnd: Color.lerp(heroScrimEnd, other.heroScrimEnd, t)!,
      playbackChrome: Color.lerp(playbackChrome, other.playbackChrome, t)!,
      focusGlow: Color.lerp(focusGlow, other.focusGlow, t)!,
    );
  }
}
