import 'package:flutter/material.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({required this.viewModel, super.key});

  final ConnectivityViewModel viewModel;

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  final _authKeyController = TextEditingController();

  @override
  void dispose() {
    _authKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final authKey = _authKeyController.text;
    _authKeyController.clear();
    await widget.viewModel.connect(authKey);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 840;
        final introduction = _IntroductionCard(status: widget.viewModel.status);
        final setup = _SetupCard(
          authKeyController: _authKeyController,
          busy: widget.viewModel.isBusy,
          onConnect: _connect,
        );

        return Scaffold(
          body: SafeArea(
            child: FocusTraversalGroup(
              key: const ValueKey('root-focus-traversal'),
              policy: OrderedTraversalPolicy(),
              child: Padding(
                padding: EdgeInsets.all(wide ? 48 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandHeader(),
                    SizedBox(height: wide ? 40 : 24),
                    Expanded(
                      key: ValueKey(wide ? 'wide-layout' : 'compact-layout'),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: introduction),
                                const SizedBox(width: 24),
                                Expanded(child: setup),
                              ],
                            )
                          : ListView(
                              children: [
                                introduction,
                                const SizedBox(height: 16),
                                setup,
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.soup_kitchen, color: Color(0xFF08111F)),
            ),
          ),
          const SizedBox(width: 12),
          Text('Soup', style: Theme.of(context).textTheme.headlineSmall),
          if (constraints.maxWidth >= 520) ...[
            const Spacer(),
            const Text('Jellyfin over Tailscale'),
          ],
        ],
      ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard({required this.status});

  final TailscaleStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: const Color(0xFF101C2E),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your Jellyfin library, without a separate VPN app.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Soup creates an app-local Tailscale connection and keeps your media traffic private.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Semantics(
              label: 'Tailscale status ${status.label}',
              child: Chip(
                avatar: Icon(status.icon, color: colors.onSecondaryContainer),
                label: Text(
                  status.label,
                  key: const ValueKey('connection-status'),
                ),
              ),
            ),
            if (status.detail case final detail?) ...[
              const SizedBox(height: 12),
              Text(detail, key: const ValueKey('connection-detail')),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.authKeyController,
    required this.busy,
    required this.onConnect,
  });

  final TextEditingController authKeyController;
  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101C2E),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Connect Soup to your tailnet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter a one-time auth key. Soup uses it once and does not save it.',
            ),
            const SizedBox(height: 24),
            FocusTraversalOrder(
              order: const NumericFocusOrder(1),
              child: TextField(
                key: const ValueKey('auth-key-field'),
                controller: authKeyController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: busy ? null : (_) => onConnect(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'One-time auth key',
                  hintText: 'tskey-auth-…',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FocusTraversalOrder(
              order: const NumericFocusOrder(2),
              child: FilledButton.icon(
                key: const ValueKey('connect-button'),
                onPressed: busy ? null : onConnect,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline),
                label: Text(busy ? 'Connecting…' : 'Connect securely'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on TailscaleStatus {
  String get label => switch (phase) {
    TailscaleConnectionPhase.disconnected => 'Not connected',
    TailscaleConnectionPhase.connecting => 'Connecting',
    TailscaleConnectionPhase.connected =>
      hostname == null ? 'Connected' : 'Connected as $hostname',
    TailscaleConnectionPhase.failed => 'Connection failed',
  };

  IconData get icon => switch (phase) {
    TailscaleConnectionPhase.disconnected => Icons.cloud_off_outlined,
    TailscaleConnectionPhase.connecting => Icons.sync,
    TailscaleConnectionPhase.connected => Icons.cloud_done_outlined,
    TailscaleConnectionPhase.failed => Icons.error_outline,
  };
}
