import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({
    required this.message,
    required this.onRetry,
    this.retrying = false,
    super.key,
  });

  final String message;
  final Future<void> Function() onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('stale-data-banner'),
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.cloudWarning,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                key: const ValueKey('stale-data-retry'),
                onPressed: retrying ? null : onRetry,
                child: Text(retrying ? 'Retrying…' : 'Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
