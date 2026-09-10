import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/onboarding_backdrop.dart';
import 'package:soup/src/features/shared/soup_mark.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_view_model.dart';

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
    final wide = MediaQuery.sizeOf(context).width >= 840;
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
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 32 : 20,
              vertical: wide ? 16 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide) ...[
                      Expanded(child: _intro(theme)),
                      const SizedBox(width: 24),
                    ],
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SoupTheme.onboardingSurface,
                          border: Border.all(
                            color: SoupTheme.onboardingInk,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: SoupTheme.onboardingInk,
                              offset: Offset(6, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            wide ? 16 : 20,
                            20,
                            wide ? 12 : 16,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!wide) ...[
                                _intro(theme),
                                const SizedBox(height: 16),
                              ],
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: wide ? 12 : 16),
                              if (showGoogleCode && link != null) ...[
                                LayoutBuilder(
                                  builder: (context, cardConstraints) {
                                    // Keep QR + code side-by-side on TV
                                    // widths so the card fits the screen.
                                    final stacked =
                                        !wide &&
                                        cardConstraints.maxWidth < 440;
                                    final qr = _qr(
                                      link.verificationUriComplete.toString(),
                                      size: stacked
                                          ? 160
                                          : (wide ? 168 : 200),
                                    );
                                    final details = _codeDetails(
                                      theme,
                                      link.userCode,
                                      status,
                                    );
                                    if (stacked) {
                                      return Column(
                                        children: [
                                          qr,
                                          const SizedBox(height: 12),
                                          details,
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        qr,
                                        const SizedBox(width: 16),
                                        Expanded(child: details),
                                      ],
                                    );
                                  },
                                ),
                              ] else if (showGoogleCode &&
                                  (model.phase ==
                                          SoupDeviceLinkPhase.starting ||
                                      model.phase ==
                                          SoupDeviceLinkPhase.idle ||
                                      model.phase ==
                                          SoupDeviceLinkPhase
                                              .needsGoogleSignIn)) ...[
                                const SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  status,
                                  key: const ValueKey(
                                    'soup-device-link-status',
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ] else ...[
                                if (model.isBusy ||
                                    model.phase ==
                                        SoupDeviceLinkPhase.exchanging ||
                                    model.phase ==
                                        SoupDeviceLinkPhase
                                            .connectingTransport ||
                                    model.phase ==
                                        SoupDeviceLinkPhase.loadingRoster) ...[
                                  const SizedBox(
                                    height: 40,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    status,
                                    key: const ValueKey(
                                      'soup-device-link-status',
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                              SizedBox(height: wide ? 12 : 16),
                              if (canRetryExchange) ...[
                                FilledButton(
                                  key: const ValueKey(
                                    'soup-device-link-retry-exchange',
                                  ),
                                  autofocus: true,
                                  onPressed: model.isBusy
                                      ? null
                                      : () => unawaited(
                                          model.silentReExchange(),
                                        ),
                                  child: const Text(
                                    'Retry Jellyfin sign-in',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  key: const ValueKey(
                                    'soup-device-link-start-over',
                                  ),
                                  onPressed: model.isBusy
                                      ? null
                                      : () => unawaited(() async {
                                          await model.clearSession();
                                          await model.startDeviceLink(
                                            newCode: true,
                                          );
                                        }()),
                                  child: const Text('Start over'),
                                ),
                                if (widget.onUseDirectLogin != null)
                                  Align(
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
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Sign in with Jellyfin',
                                      ),
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
                                          key: const ValueKey(
                                            'soup-device-link-new-code',
                                          ),
                                          autofocus: true,
                                          onPressed: model.isBusy && waiting
                                              ? null
                                              : () => unawaited(
                                                  model.startDeviceLink(
                                                    newCode: true,
                                                  ),
                                                ),
                                          child: Text(
                                            model.phase ==
                                                    SoupDeviceLinkPhase
                                                        .starting
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Sign in with Jellyfin',
                                              ),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: SoupTheme.onboardingAccent,
        boxShadow: [
          BoxShadow(color: SoupTheme.onboardingInk, offset: Offset(6, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SoupMark(size: 48),
          const SizedBox(height: 16),
          Text(
            'SOUP ACCOUNT',
            style: theme.textTheme.labelSmall?.copyWith(
              color: SoupTheme.onboardingSignal,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SIGN IN ONCE.\nWATCH ANYWHERE.',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: SoupTheme.onboardingSurface,
              height: 0.98,
              fontSize: 44,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Link this TV to your Google account through Soup. If a home invite includes a Tailscale key, Soup joins automatically.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SoupTheme.onboardingSurface.withValues(alpha: 0.86),
              height: 1.35,
            ),
          ),
        ],
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
