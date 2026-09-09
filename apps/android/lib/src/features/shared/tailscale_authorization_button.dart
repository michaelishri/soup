import 'package:flutter/material.dart';
import 'package:soup/src/features/connectivity/tailscale_authorization_controller.dart';

/// Presents the connection model's long-lived browser session.
class TailscaleAuthorizationButton extends StatelessWidget {
  const TailscaleAuthorizationButton({
    required this.controller,
    this.style,
    super.key,
  });

  final TailscaleAuthorizationController controller;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          controller.externalBrowser
              ? 'Sign in to Tailscale in your browser, then return to Soup.'
              : 'Sign in to Tailscale. Soup will return automatically when you’re done.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('tailscale-authorization-button'),
          style: style,
          onPressed: controller.canOpen ? controller.open : null,
          child: const Text(
            'Authorise device on Tailscale',
            textAlign: TextAlign.center,
          ),
        ),
        if (controller.failed) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              'Couldn’t open the Tailscale sign-in page. Try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    ),
  );
}
