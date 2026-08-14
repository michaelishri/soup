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
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _authKeyController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final authKey = _authKeyController.text;
    _authKeyController.clear();
    await widget.viewModel.connect(authKey);
  }

  Future<void> _checkServer() =>
      widget.viewModel.checkServer(_serverController.text);

  Future<void> _signIn() async {
    final password = _passwordController.text;
    _passwordController.clear();
    await widget.viewModel.signIn(
      username: _usernameController.text,
      password: password,
    );
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
          serverController: _serverController,
          usernameController: _usernameController,
          passwordController: _passwordController,
          viewModel: widget.viewModel,
          busy: widget.viewModel.isBusy,
          onConnect: _connect,
          onCheckServer: _checkServer,
          onSignIn: _signIn,
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
    required this.serverController,
    required this.usernameController,
    required this.passwordController,
    required this.viewModel,
    required this.busy,
    required this.onConnect,
    required this.onCheckServer,
    required this.onSignIn,
  });

  final TextEditingController authKeyController;
  final TextEditingController serverController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final ConnectivityViewModel viewModel;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onCheckServer;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101C2E),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Column(
              key: ValueKey(viewModel.phase),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ..._phaseContent(context),
                if (viewModel.error case final error?) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    key: const ValueKey('setup-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _phaseContent(BuildContext context) => switch (viewModel.phase) {
    SetupPhase.tailscale => [
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
      _ActionButton(
        order: 2,
        keyValue: 'connect-button',
        busy: busy,
        onPressed: onConnect,
        icon: Icons.lock_outline,
        label: 'Connect securely',
      ),
    ],
    SetupPhase.server => [
      Text(
        'Find your Jellyfin server',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Use its Tailscale name or IP. Soup sends this check through its private proxy.',
      ),
      const SizedBox(height: 24),
      FocusTraversalOrder(
        order: const NumericFocusOrder(1),
        child: TextField(
          key: const ValueKey('server-url-field'),
          controller: serverController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: busy ? null : (_) => onCheckServer(),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Jellyfin server',
            hintText: 'http://jellyfin:8096',
          ),
        ),
      ),
      const SizedBox(height: 16),
      _ActionButton(
        order: 2,
        keyValue: 'check-server-button',
        busy: busy,
        onPressed: onCheckServer,
        icon: Icons.dns_outlined,
        label: 'Check server',
      ),
    ],
    SetupPhase.credentials => [
      Text(
        'Sign in to ${viewModel.serverInfo?.name ?? 'Jellyfin'}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Text('Server ${viewModel.serverInfo?.version ?? ''} is ready.'),
      const SizedBox(height: 24),
      FocusTraversalOrder(
        order: const NumericFocusOrder(1),
        child: TextField(
          key: const ValueKey('username-field'),
          controller: usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Username',
          ),
        ),
      ),
      const SizedBox(height: 14),
      FocusTraversalOrder(
        order: const NumericFocusOrder(2),
        child: TextField(
          key: const ValueKey('password-field'),
          controller: passwordController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: busy ? null : (_) => onSignIn(),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Password',
          ),
        ),
      ),
      const SizedBox(height: 16),
      _ActionButton(
        order: 3,
        keyValue: 'sign-in-button',
        busy: busy,
        onPressed: onSignIn,
        icon: Icons.login,
        label: 'Sign in',
      ),
    ],
    SetupPhase.ready => [
      Icon(
        Icons.check_circle,
        size: 42,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Ready for your library',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Text('Signed in as ${viewModel.session?.userName ?? 'Jellyfin user'}'),
      const SizedBox(height: 4),
      Text(viewModel.serverUrl?.toString() ?? ''),
      const SizedBox(height: 20),
      FocusTraversalOrder(
        order: const NumericFocusOrder(1),
        child: OutlinedButton.icon(
          key: const ValueKey('sign-out-button'),
          onPressed: busy ? null : viewModel.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Change server or account'),
        ),
      ),
    ],
  };
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.order,
    required this.keyValue,
    required this.busy,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final double order;
  final String keyValue;
  final bool busy;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: FilledButton.icon(
        key: ValueKey(keyValue),
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(busy ? 'Working…' : label),
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
