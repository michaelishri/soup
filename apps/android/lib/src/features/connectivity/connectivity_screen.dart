import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/services.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/platform/authorization_url_launcher.dart';
import 'package:soup_tailscale/soup_tailscale.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({
    required this.viewModel,
    this.authorizationUrlLauncher = const ExternalAuthorizationUrlLauncher(),
    super.key,
  });

  final ConnectivityViewModel viewModel;
  final AuthorizationUrlLauncher authorizationUrlLauncher;

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  final _authKeyController = TextEditingController();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _advancedAuthKeyExpanded = false;

  @override
  void dispose() {
    _authKeyController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connectWithAuthKey() async {
    final authKey = _authKeyController.text;
    _authKeyController.clear();
    await widget.viewModel.connectWithAuthKey(authKey);
  }

  Future<void> _connectInteractively() {
    return widget.viewModel.connectInteractively();
  }

  Future<void> _retryInteractive() async {
    await widget.viewModel.cancelTailscaleConnection();
    await widget.viewModel.connectInteractively();
  }

  Future<void> _openAuthorizationUrl() async {
    final url = widget.viewModel.status.authorizationUrl;
    if (url == null) return;
    final opened = await widget.authorizationUrlLauncher.open(url);
    if (mounted && !opened) {
      _showClipboardMessage(
        'No browser is available. Scan the QR code instead.',
      );
    }
  }

  Future<void> _pasteAuthKey() async {
    await _pasteText(
      controller: _authKeyController,
      emptyMessage: 'Clipboard does not contain an auth key.',
      successMessage: 'Auth key pasted.',
    );
  }

  Future<void> _pasteServerUrl() async {
    await _pasteText(
      controller: _serverController,
      emptyMessage: 'Clipboard does not contain a server address.',
      successMessage: 'Server address pasted.',
    );
  }

  Future<void> _pasteText({
    required TextEditingController controller,
    required String emptyMessage,
    required String successMessage,
  }) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;

      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        _showClipboardMessage(emptyMessage);
        return;
      }

      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _showClipboardMessage(successMessage);
    } on PlatformException {
      if (mounted) {
        _showClipboardMessage('Unable to read the clipboard.');
      }
    }
  }

  void _showClipboardMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _checkServer() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await widget.viewModel.checkServer(_serverController.text);
  }

  Future<void> _signIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
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
          advancedAuthKeyExpanded: _advancedAuthKeyExpanded,
          onAdvancedAuthKeyChanged: (value) {
            setState(() => _advancedAuthKeyExpanded = value);
          },
          onConnectInteractively: _connectInteractively,
          onConnectWithAuthKey: _connectWithAuthKey,
          onOpenAuthorizationUrl: _openAuthorizationUrl,
          onCancelConnection: widget.viewModel.cancelTailscaleConnection,
          onRetryInteractive: _retryInteractive,
          onPasteAuthKey: _pasteAuthKey,
          onPasteServerUrl: _pasteServerUrl,
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
              child: Icon(
                PhosphorIconsRegular.cookingPot,
                color: Color(0xFF08111F),
              ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.hasBoundedHeight && constraints.maxHeight < 400;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your Jellyfin library, without a separate VPN app.',
                  style: compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium,
                ),
                SizedBox(height: compact ? 10 : 16),
                Text(
                  'Soup creates an app-local Tailscale connection and keeps your media traffic private.',
                  style: compact
                      ? Theme.of(context).textTheme.bodyMedium
                      : Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: compact ? 16 : 28),
                Semantics(
                  label: 'Tailscale status ${status.label}',
                  child: Chip(
                    avatar: Icon(
                      status.icon,
                      color: colors.onSecondaryContainer,
                    ),
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
            );
          },
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
    required this.advancedAuthKeyExpanded,
    required this.onAdvancedAuthKeyChanged,
    required this.onConnectInteractively,
    required this.onConnectWithAuthKey,
    required this.onOpenAuthorizationUrl,
    required this.onCancelConnection,
    required this.onRetryInteractive,
    required this.onPasteAuthKey,
    required this.onPasteServerUrl,
    required this.onCheckServer,
    required this.onSignIn,
  });

  final TextEditingController authKeyController;
  final TextEditingController serverController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final ConnectivityViewModel viewModel;
  final bool busy;
  final bool advancedAuthKeyExpanded;
  final ValueChanged<bool> onAdvancedAuthKeyChanged;
  final VoidCallback onConnectInteractively;
  final VoidCallback onConnectWithAuthKey;
  final VoidCallback onOpenAuthorizationUrl;
  final VoidCallback onCancelConnection;
  final VoidCallback onRetryInteractive;
  final VoidCallback onPasteAuthKey;
  final VoidCallback onPasteServerUrl;
  final VoidCallback onCheckServer;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('setup-card'),
      color: const Color(0xFF101C2E),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phase = SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey(viewModel.phase),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _phaseContent(
                    context,
                    availableHeight: constraints.hasBoundedHeight
                        ? constraints.maxHeight
                        : null,
                  ),
                ),
              ),
            );
            final children = <Widget>[
              if (viewModel.error case final error?) ...[
                _ErrorBanner(message: error),
                const SizedBox(height: 16),
              ],
              if (constraints.hasBoundedHeight)
                Expanded(child: phase)
              else
                phase,
            ];
            return Column(
              mainAxisSize: constraints.hasBoundedHeight
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            );
          },
        ),
      ),
    );
  }

  List<Widget> _phaseContent(
    BuildContext context, {
    required double? availableHeight,
  }) => switch (viewModel.phase) {
    SetupPhase.tailscale => _tailscaleContent(
      context,
      availableHeight: availableHeight,
    ),
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
      const SizedBox(height: 12),
      FocusTraversalOrder(
        order: const NumericFocusOrder(2),
        child: OutlinedButton.icon(
          key: const ValueKey('paste-server-url-button'),
          onPressed: busy ? null : onPasteServerUrl,
          icon: const Icon(PhosphorIconsRegular.clipboardText),
          label: const Text('Paste server address'),
        ),
      ),
      const SizedBox(height: 16),
      _ActionButton(
        order: 3,
        keyValue: 'check-server-button',
        busy: busy,
        onPressed: onCheckServer,
        icon: PhosphorIconsRegular.database,
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
        icon: PhosphorIconsRegular.signIn,
        label: 'Sign in',
      ),
    ],
    SetupPhase.ready => [
      Icon(
        PhosphorIconsFill.checkCircle,
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
          icon: const Icon(PhosphorIconsRegular.signOut),
          label: const Text('Change server or account'),
        ),
      ),
    ],
  };

  List<Widget> _tailscaleContent(
    BuildContext context, {
    required double? availableHeight,
  }) {
    final status = viewModel.status;
    switch (status.phase) {
      case TailscaleConnectionPhase.awaitingLogin:
        final authorizationUrl = status.authorizationUrl;
        final compact = availableHeight != null && availableHeight < 460;
        final qrSize = compact
            ? (availableHeight - 186).clamp(110.0, 160.0).toDouble()
            : 230.0;
        final contentGap = compact ? 8.0 : 14.0;
        return [
          Text(
            'Finish signing in on another device',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: compact ? 6 : 10),
          const Text(
            'Scan this code with your phone and sign in to Tailscale.',
          ),
          if (authorizationUrl != null) ...[
            SizedBox(height: compact ? 8 : 16),
            Center(
              child: DecoratedBox(
                key: const ValueKey('tailscale-authorization-qr'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: authorizationUrl.toString(),
                  version: QrVersions.auto,
                  size: qrSize,
                  padding: const EdgeInsets.all(10),
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Tailscale sign-in QR code',
                ),
              ),
            ),
            SizedBox(height: contentGap),
            if (!compact)
              _ActionButton(
                order: 1,
                keyValue: 'open-tailscale-login-button',
                busy: false,
                onPressed: onOpenAuthorizationUrl,
                icon: PhosphorIconsRegular.arrowSquareOut,
                label: 'Open sign-in page',
              ),
          ],
          if (!compact) const SizedBox(height: 10),
          _TailscaleLoginActions(
            compact: compact,
            showOpenAction: authorizationUrl != null,
            onOpenAuthorizationUrl: onOpenAuthorizationUrl,
            onRetryInteractive: onRetryInteractive,
            onCancelConnection: onCancelConnection,
          ),
        ];
      case TailscaleConnectionPhase.awaitingApproval:
        return [
          Text(
            'Approve this TV',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your tailnet requires device approval. Approve this TV in the Tailscale admin console; Soup will continue automatically.',
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const ValueKey('cancel-tailscale-login-button'),
            onPressed: onCancelConnection,
            child: const Text('Cancel'),
          ),
        ];
      case TailscaleConnectionPhase.starting:
        return [
          Text(
            'Preparing secure sign-in…',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 20),
          OutlinedButton(
            key: const ValueKey('cancel-tailscale-login-button'),
            onPressed: onCancelConnection,
            child: const Text('Cancel'),
          ),
        ];
      case TailscaleConnectionPhase.disconnected:
      case TailscaleConnectionPhase.failed:
        return [
          Text(
            'Connect Soup to your tailnet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in on your phone by scanning a QR code. No auth key is needed.',
          ),
          const SizedBox(height: 22),
          _ActionButton(
            order: 1,
            keyValue: 'connect-interactively-button',
            busy: false,
            onPressed: onConnectInteractively,
            icon: PhosphorIconsRegular.qrCode,
            label: status.phase == TailscaleConnectionPhase.failed
                ? 'Try again'
                : 'Sign in with Tailscale',
          ),
          const SizedBox(height: 14),
          ExpansionTile(
            key: const ValueKey('advanced-auth-key'),
            initiallyExpanded: advancedAuthKeyExpanded,
            onExpansionChanged: onAdvancedAuthKeyChanged,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Advanced options'),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Use a one-time auth key for pre-approved or tagged-device setups. Soup never saves it.',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('auth-key-field'),
                controller: authKeyController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: busy ? null : (_) => onConnectWithAuthKey(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'One-time auth key',
                  hintText: 'tskey-auth-…',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('paste-auth-key-button'),
                      onPressed: busy ? null : onPasteAuthKey,
                      icon: const Icon(PhosphorIconsRegular.clipboardText),
                      label: const Text('Paste auth key'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('connect-button'),
                      onPressed: busy ? null : onConnectWithAuthKey,
                      icon: const Icon(PhosphorIconsRegular.key),
                      label: const Text('Use auth key'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ];
      case TailscaleConnectionPhase.connected:
        return const [];
    }
  }
}

class _TailscaleLoginActions extends StatelessWidget {
  const _TailscaleLoginActions({
    required this.compact,
    required this.showOpenAction,
    required this.onOpenAuthorizationUrl,
    required this.onRetryInteractive,
    required this.onCancelConnection,
  });

  final bool compact;
  final bool showOpenAction;
  final VoidCallback onOpenAuthorizationUrl;
  final VoidCallback onRetryInteractive;
  final VoidCallback onCancelConnection;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (compact && showOpenAction)
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('open-tailscale-login-button'),
            onPressed: onOpenAuthorizationUrl,
            icon: const Icon(PhosphorIconsRegular.arrowSquareOut),
            label: const Text('Open'),
          ),
        ),
      Expanded(
        child: OutlinedButton(
          key: const ValueKey('retry-tailscale-login-button'),
          onPressed: onRetryInteractive,
          child: Text(compact ? 'New code' : 'Get a new code'),
        ),
      ),
      Expanded(
        child: OutlinedButton(
          key: const ValueKey('cancel-tailscale-login-button'),
          onPressed: onCancelConnection,
          child: const Text('Cancel'),
        ),
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          actions[index],
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey('setup-error'),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PhosphorIconsRegular.warningCircle,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    TailscaleConnectionPhase.starting => 'Starting secure sign-in',
    TailscaleConnectionPhase.awaitingLogin => 'Waiting for sign-in',
    TailscaleConnectionPhase.awaitingApproval => 'Waiting for approval',
    TailscaleConnectionPhase.connected =>
      hostname == null ? 'Connected' : 'Connected as $hostname',
    TailscaleConnectionPhase.failed => 'Connection failed',
  };

  IconData get icon => switch (phase) {
    TailscaleConnectionPhase.disconnected => PhosphorIconsRegular.cloudSlash,
    TailscaleConnectionPhase.starting => PhosphorIconsRegular.arrowsClockwise,
    TailscaleConnectionPhase.awaitingLogin => PhosphorIconsRegular.qrCode,
    TailscaleConnectionPhase.awaitingApproval => PhosphorIconsRegular.clock,
    TailscaleConnectionPhase.connected => PhosphorIconsRegular.cloudCheck,
    TailscaleConnectionPhase.failed => PhosphorIconsRegular.warningCircle,
  };
}
