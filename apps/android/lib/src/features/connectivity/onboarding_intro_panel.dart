import 'package:flutter/material.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/shared/soup_mark.dart';

/// Shared blue onboarding hero used by Soup Account and Jellyfin setup.
class OnboardingIntroPanel extends StatelessWidget {
  const OnboardingIntroPanel({
    required this.eyebrow,
    required this.headline,
    required this.body,
    this.wide = true,
    this.fillHeight = false,
    super.key,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final bool wide;

  /// When true, the panel expands to the parent's height (wide split layouts).
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('setup-intro'),
      width: double.infinity,
      height: fillHeight ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: SoupTheme.onboardingAccent,
        boxShadow: [
          BoxShadow(color: SoupTheme.onboardingInk, offset: Offset(6, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SoupMark(size: 48),
          const SizedBox(height: 16),
          Text(
            eyebrow,
            style: theme.textTheme.labelSmall?.copyWith(
              color: SoupTheme.onboardingSignal,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            label: headline.replaceAll('\n', ' '),
            child: ExcludeSemantics(
              child: Text(
                headline,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: SoupTheme.onboardingSurface,
                  height: 0.98,
                  fontSize: wide ? 44 : 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SoupTheme.onboardingSurface.withValues(alpha: 0.86),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
