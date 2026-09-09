import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the existing registration without starting another Tailscale attempt.
class TailscaleAuthorizationButton extends StatefulWidget {
  const TailscaleAuthorizationButton({
    required this.authorizationUrl,
    this.style,
    super.key,
  });

  final Uri authorizationUrl;
  final ButtonStyle? style;

  @override
  State<TailscaleAuthorizationButton> createState() =>
      _TailscaleAuthorizationButtonState();
}

class _TailscaleAuthorizationButtonState
    extends State<TailscaleAuthorizationButton> {
  bool _opening = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant TailscaleAuthorizationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorizationUrl != widget.authorizationUrl) {
      _generation++;
      _opening = false;
      _failed = false;
    }
  }

  Future<void> _open() async {
    if (_opening) return;
    final generation = ++_generation;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await launchUrl(
        widget.authorizationUrl,
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      // Keep platform details and the registration URL out of error messages.
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _opening = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sign in to Tailscale in your browser, then return to Soup.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        key: const ValueKey('tailscale-authorization-button'),
        style: widget.style,
        onPressed: _opening ? null : _open,
        child: const Text(
          'Authorise device on Tailscale',
          textAlign: TextAlign.center,
        ),
      ),
      if (_failed) ...[
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
  );
}
