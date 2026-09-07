import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';

class SoupTheme {
  const SoupTheme._();

  static const onboardingBackground = Color(0xFF203C40);
  static const onboardingGlow = Color(0xFF355653);

  static ThemeData get onboarding {
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFEFB98F),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFEFB98F),
          onPrimary: const Color(0xFF293831),
          surface: onboardingBackground,
          surfaceContainerHighest: const Color(0xFF3B5557),
          onSurface: const Color(0xFFF5F0E8),
          onSurfaceVariant: const Color(0xFFC8D5D0),
          outlineVariant: const Color(0xFF69817E),
        );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colors,
      scaffoldBackgroundColor: onboardingBackground,
      useMaterial3: true,
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.onSurfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : colors.outlineVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF304C4F),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: colors.onSurface, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: colors.primary, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
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
