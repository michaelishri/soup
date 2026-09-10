import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/onboarding_backdrop.dart';
import 'package:soup/src/features/connectivity/onboarding_intro_panel.dart';
import 'package:soup/src/features/shared/soup_mark.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_view_model.dart';
import 'package:soup_identity/soup_identity.dart';

/// TV-first Soup Identity device-link step (feature-flagged Wave 1B shell).
class SoupDeviceLinkScreen extends StatefulWidget {
  const SoupDeviceLinkScreen({
    required this.viewModel,
    this.onUseDirectLogin,
    super.key,
  });

  final SoupDeviceLinkViewModel viewModel;

  /// Opt into legacy Jellyfin login (with or without Tailscale). Not the default.
  final VoidCallback? onUseDirectLogin;

  @override
  State<SoupDeviceLinkScreen> createState() => _SoupDeviceLinkScreenState();
}

class _SoupDeviceLinkScreenState extends State<SoupDeviceLinkScreen>
    with WidgetsBindingObserver {
  SoupDeviceLinkViewModel get model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Keep a valid Soup session on the retry path — don't restart Google link.
      if (model.session != null &&
          (model.phase == SoupDeviceLinkPhase.error ||
              model.phase == SoupDeviceLinkPhase.ready)) {
        return;
      }
      if (model.phase == SoupDeviceLinkPhase.idle ||
          model.phase == SoupDeviceLinkPhase.error ||
          model.phase == SoupDeviceLinkPhase.expired ||
          model.phase == SoupDeviceLinkPhase.needsGoogleSignIn) {
        unawaited(model.startDeviceLink());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_onChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    model.setForeground(state == AppLifecycleState.resumed);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = model.link;
    final waiting =
        model.phase == SoupDeviceLinkPhase.waiting ||
        model.phase == SoupDeviceLinkPhase.starting;
    final status = switch (model.phase) {
      SoupDeviceLinkPhase.idle ||
      SoupDeviceLinkPhase.starting => 'Preparing a Soup sign-in code…',
      SoupDeviceLinkPhase.waiting => 'Waiting for Google sign-in on your phone',
      SoupDeviceLinkPhase.loadingRoster => 'Signed in. Loading your servers…',
      SoupDeviceLinkPhase.connectingTransport =>
        'Joining your home network with a Soup Tailscale key…',
      SoupDeviceLinkPhase.exchanging =>
        'Signing into Jellyfin with your Soup invite…',
      SoupDeviceLinkPhase.refreshing => 'Refreshing your Soup session…',
      SoupDeviceLinkPhase.ready => model.jellyfinSession != null
          ? 'Soup and Jellyfin sign-in saved.'
          : model.transportConnected
          ? 'Soup sign-in saved. Home network connected.'
          : 'Soup sign-in saved.',
      SoupDeviceLinkPhase.needsGoogleSignIn =>
        model.error ?? 'Your Soup sign-in expired. Sign in with Google again.',
      SoupDeviceLinkPhase.expired =>
        model.error ?? 'This code has expired. Get a new code to continue.',
      SoupDeviceLinkPhase.error =>
        model.exchangeError ??
            model.transportError ??
            model.error ??
            'Unable to start Soup sign-in.',
    };

    final showGoogleCode =
        model.session == null ||
        model.phase == SoupDeviceLinkPhase.needsGoogleSignIn ||
        model.phase == SoupDeviceLinkPhase.waiting ||
        model.phase == SoupDeviceLinkPhase.starting ||
        model.phase == SoupDeviceLinkPhase.expired;

    final canRetryExchange =
        model.session != null &&
        model.jellyfinSession == null &&
        (model.phase == SoupDeviceLinkPhase.error ||
            model.phase == SoupDeviceLinkPhase.ready);

    return Scaffold(
      body: OnboardingBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final short = constraints.maxHeight < 650;
              final wide =
                  constraints.maxWidth >= 840 &&
                  constraints.maxHeight >= 420 &&
                  MediaQuery.textScalerOf(context).scale(16) <= 22.4;
              final horizontal = constraints.maxWidth < 600 ? 24.0 : 48.0;
              final card = _card(
                theme: theme,
                wide: wide,
                expand: wide,
                showGoogleCode: showGoogleCode,
                canRetryExchange: canRetryExchange,
                waiting: waiting,
                status: status,
                link: link,
              );
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal,
                  vertical: short ? 20 : 36,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context),
                        SizedBox(height: short ? 24 : 48),
                        Expanded(
                          child: wide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Expanded(
                                      flex: 4,
                                      child: OnboardingIntroPanel(
                                        eyebrow: 'SOUP ACCOUNT',
                                        headline:
                                            'SIGN IN ONCE.\nWATCH ANYWHERE.',
                                        body:
                                            'Link this TV to your Google account through Soup. If a home invite includes a Tailscale key, Soup joins automatically.',
                                        wide: true,
                                        fillHeight: true,
                                      ),
                                    ),
                                    const SizedBox(width: 56),
                                    Expanded(
                                      flex: 6,
                                      child: SizedBox.expand(child: card),
                                    ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const OnboardingIntroPanel(
                                        eyebrow: 'SOUP ACCOUNT',
                                        headline:
                                            'SIGN IN ONCE.\nWATCH ANYWHERE.',
                                        body:
                                            'Link this TV to your Google account through Soup. If a home invite includes a Tailscale key, Soup joins automatically.',
                                        wide: false,
                                      ),
                                      const SizedBox(height: 16),
                                      card,
                                    ],
                                  ),
                                ),
                        ),
                        // Match Jellyfin setup footer band so the blue panel
                        // shares the same vertical budget.
                        SizedBox(height: short ? 20 : 32),
                        const SizedBox(height: 54),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SoupMark(size: 46),
        const SizedBox(width: 10),
        Text(
          'SOUP',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            // Match connectivity header height (label + progress track).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Account',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({
    required ThemeData theme,
    required bool wide,
    required bool expand,
    required bool showGoogleCode,
    required bool canRetryExchange,
    required bool waiting,
    required String status,
    required DeviceLinkStart? link,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SoupTheme.onboardingSurface,
        border: Border.all(color: SoupTheme.onboardingInk, width: 2),
        boxShadow: const [
          BoxShadow(color: SoupTheme.onboardingInk, offset: Offset(6, 6)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, wide ? 16 : 20, 20, wide ? 12 : 16),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showGoogleCode
                  ? 'Scan to sign in with Google'
                  : 'Finishing Soup invite',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              showGoogleCode
                  ? 'Use your phone to complete Google sign-in with Soup. This TV keeps polling until you’re approved.'
                  : 'Connecting to your invited Jellyfin server. This usually finishes in under a minute.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
            ),
            SizedBox(height: wide ? 12 : 16),
            if (showGoogleCode && link != null) ...[
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  // Keep QR + code side-by-side on TV widths so the card
                  // fits the screen.
                  final stacked = !wide && cardConstraints.maxWidth < 440;
                  final qr = _qr(
                    link.verificationUriComplete.toString(),
                    size: stacked ? 160 : (wide ? 168 : 200),
                  );
                  final details = _codeDetails(theme, link.userCode, status);
                  if (stacked) {
                    return Column(
                      children: [qr, const SizedBox(height: 12), details],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      qr,
                      const SizedBox(width: 16),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
            ] else if (showGoogleCode &&
                (model.phase == SoupDeviceLinkPhase.starting ||
                    model.phase == SoupDeviceLinkPhase.idle ||
                    model.phase == SoupDeviceLinkPhase.needsGoogleSignIn)) ...[
              const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                key: const ValueKey('soup-device-link-status'),
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              if (model.isBusy ||
                  model.phase == SoupDeviceLinkPhase.exchanging ||
                  model.phase == SoupDeviceLinkPhase.connectingTransport ||
                  model.phase == SoupDeviceLinkPhase.loadingRoster) ...[
                const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 8),
              ],
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  key: const ValueKey('soup-device-link-status'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            if (expand) const Spacer() else SizedBox(height: wide ? 12 : 16),
            if (canRetryExchange) ...[
              FilledButton(
                key: const ValueKey('soup-device-link-retry-exchange'),
                autofocus: true,
                onPressed: model.isBusy
                    ? null
                    : () => unawaited(model.silentReExchange()),
                child: const Text('Retry Jellyfin sign-in'),
              ),
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey('soup-device-link-start-over'),
                onPressed: model.isBusy
                    ? null
                    : () => unawaited(() async {
                        await model.clearSession();
                        await model.startDeviceLink(newCode: true);
                      }()),
                child: const Text('Start over'),
              ),
              if (widget.onUseDirectLogin != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('soup-device-link-direct-login'),
                    onPressed: model.isBusy ? null : widget.onUseDirectLogin,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sign in with Jellyfin'),
                  ),
                ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: FilledButton(
                        key: const ValueKey('soup-device-link-new-code'),
                        autofocus: true,
                        onPressed: model.isBusy && waiting
                            ? null
                            : () => unawaited(
                                model.startDeviceLink(newCode: true),
                              ),
                        child: Text(
                          model.phase == SoupDeviceLinkPhase.starting
                              ? 'Preparing…'
                              : 'Get a new code',
                        ),
                      ),
                    ),
                    if (widget.onUseDirectLogin != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            key: const ValueKey(
                              'soup-device-link-direct-login',
                            ),
                            onPressed: model.isBusy
                                ? null
                                : widget.onUseDirectLogin,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Sign in with Jellyfin'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _qr(String data, {required double size}) {
    return Container(
      key: const ValueKey('soup-device-link-qr'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        semanticsLabel: 'Soup sign-in QR code',
      ),
    );
  }

  Widget _codeDetails(ThemeData theme, String userCode, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Or enter this code', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Semantics(
          label: 'Soup user code: ${userCode.split('').join(' ')}',
          child: ExcludeSemantics(
            child: Text(
              userCode,
              key: const ValueKey('soup-device-link-user-code'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 36,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            key: const ValueKey('soup-device-link-status'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
