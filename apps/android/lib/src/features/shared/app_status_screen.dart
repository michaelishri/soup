import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soup/src/features/shared/soup_mark.dart';

/// Startup and connection recovery are separate from first-time setup.
class AppStatusScreen extends StatelessWidget {
  const AppStatusScreen({
    required this.title,
    required this.message,
    this.busy = false,
    this.onRetry,
    this.authorizationUrl,
    super.key,
  });

  final String title;
  final String message;
  final bool busy;
  final VoidCallback? onRetry;
  final Uri? authorizationUrl;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SoupMark(size: 64),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (authorizationUrl case final url?) ...[
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'Scan to reconnect to Tailscale: $url',
                    child: QrImageView(
                      data: url.toString(),
                      size: 160,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  Text(url.toString(), textAlign: TextAlign.center),
                ] else if (busy) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    autofocus: true,
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
