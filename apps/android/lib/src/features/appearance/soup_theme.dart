import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';

class SoupTheme {
  const SoupTheme._();

  static const onboardingBackground = Color(0xFFF5F3EB);
  static const onboardingSurface = Color(0xFFFFFEF8);
  static const onboardingSignal = Color(0xFFE8F35B);
  static const onboardingAccent = Color(0xFF2541C8);
  static const onboardingInk = Color(0xFF1C2027);
  static const onboardingMuted = Color(0xFF515867);

  static ThemeData get onboarding => _festival(Brightness.light);

  static ThemeData _festival(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: onboardingAccent,
          brightness: brightness,
        ).copyWith(
          primary: dark ? onboardingSignal : onboardingAccent,
          onPrimary: dark ? onboardingInk : onboardingSurface,
          primaryContainer: onboardingAccent,
          onPrimaryContainer: onboardingSurface,
          secondary: dark ? onboardingSignal : onboardingInk,
          onSecondary: dark ? onboardingInk : onboardingSurface,
          secondaryContainer: dark ? onboardingAccent : onboardingSignal,
          onSecondaryContainer: dark ? onboardingSurface : onboardingInk,
          surface: dark ? const Color(0xFF15181E) : onboardingBackground,
          surfaceDim: dark ? const Color(0xFF101318) : const Color(0xFFDBDCD5),
          surfaceBright: dark ? const Color(0xFF373C47) : onboardingSurface,
          surfaceContainerLowest: dark
              ? const Color(0xFF101318)
              : onboardingSurface,
          surfaceContainerLow: dark ? onboardingInk : onboardingSurface,
          surfaceContainer: dark
              ? const Color(0xFF242932)
              : const Color(0xFFEEEDE5),
          surfaceContainerHigh: dark
              ? const Color(0xFF2B313C)
              : const Color(0xFFE9E9E1),
          surfaceContainerHighest: dark
              ? const Color(0xFF343B48)
              : const Color(0xFFE5E7E9),
          onSurface: dark ? onboardingBackground : onboardingInk,
          onSurfaceVariant: dark ? const Color(0xFFC5CAD4) : onboardingMuted,
          outline: dark ? const Color(0xFF929BAA) : const Color(0xFF7C8391),
          outlineVariant: dark
              ? const Color(0xFF5B6474)
              : const Color(0xFFAEB2B9),
        );
    final base = ThemeData(
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 30,
          height: 1.1,
          fontFamily: 'BarlowCondensed',
          fontWeight: FontWeight.w800,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
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
              : colors.outline,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.primary, width: 2.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 54)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.focused)
                ? onboardingAccent
                : onboardingInk;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.disabled) ? null : onboardingSignal,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: colors.onSurface, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        selectedColor: colors.secondaryContainer,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
        ),
        checkmarkColor: colors.onSecondaryContainer,
        side: BorderSide(color: colors.outline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surfaceContainerLow,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? colors.primary
                  : colors.outline,
              width: states.contains(WidgetState.focused) ? 2 : 1,
            ),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
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
    if (settings.palette == PaletteFamily.festival) {
      final theme = _festival(brightness);
      return theme.copyWith(
        extensions: [
          AuthenticatedThemeTokens(
            preset: settings.preset,
            festival: true,
            heroScrimStart: theme.scaffoldBackgroundColor.withValues(
              alpha: 0.25,
            ),
            heroScrimEnd: theme.scaffoldBackgroundColor,
            playbackChrome: const Color(0xF215181E),
            focusGlow: theme.colorScheme.primary,
          ),
        ],
      );
    }
    final seed = switch (settings.palette) {
      PaletteFamily.festival => onboardingAccent,
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

  static bool isFestival(BuildContext context) =>
      Theme.of(context).extension<AuthenticatedThemeTokens>()?.festival ??
      false;

  static ThemeData playback(ThemeData theme) {
    final tokens = theme.extension<AuthenticatedThemeTokens>();
    if (tokens?.festival ?? false) {
      return authenticated(
        AppearanceSettings(
          preset: tokens!.preset,
          brightness: AppearanceBrightness.dark,
        ),
      );
    }
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.colorScheme.primary,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      extensions: [?tokens],
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
    this.festival = false,
  });

  final UiPreset preset;
  final bool festival;
  final Color heroScrimStart;
  final Color heroScrimEnd;
  final Color playbackChrome;
  final Color focusGlow;

  @override
  AuthenticatedThemeTokens copyWith({
    UiPreset? preset,
    bool? festival,
    Color? heroScrimStart,
    Color? heroScrimEnd,
    Color? playbackChrome,
    Color? focusGlow,
  }) {
    return AuthenticatedThemeTokens(
      preset: preset ?? this.preset,
      festival: festival ?? this.festival,
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
      festival: t < 0.5 ? festival : other.festival,
      heroScrimStart: Color.lerp(heroScrimStart, other.heroScrimStart, t)!,
      heroScrimEnd: Color.lerp(heroScrimEnd, other.heroScrimEnd, t)!,
      playbackChrome: Color.lerp(playbackChrome, other.playbackChrome, t)!,
      focusGlow: Color.lerp(focusGlow, other.focusGlow, t)!,
    );
  }
}
