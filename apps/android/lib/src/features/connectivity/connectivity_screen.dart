import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({required this.viewModel, super.key});
  final ConnectivityViewModel viewModel;

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _switchFocus = FocusNode(debugLabel: 'use Tailscale');
  final _serverFocus = FocusNode(debugLabel: 'Jellyfin server');
  final _usernameFocus = FocusNode(debugLabel: 'Jellyfin username');
  final _scroll = ScrollController();
  late SetupPhase _lastPhase;
  ConnectivityViewModel get model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _lastPhase = model.phase;
    _server.text = model.serverUrl?.toString() ?? '';
    model.addListener(_changed);
    _focusStep();
  }

  @override
  void didUpdateWidget(covariant ConnectivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != model) {
      oldWidget.viewModel.removeListener(_changed);
      model.addListener(_changed);
      _changed();
    }
  }

  void _changed() {
    if (model.phase == _lastPhase) return;
    _password.clear();
    _lastPhase = model.phase;
    if (_server.text.isEmpty && model.serverUrl != null) {
      _server.text = model.serverUrl.toString();
    }
    _focusStep();
  }

  void _focusStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      switch (model.phase) {
        case SetupPhase.connection:
          _switchFocus.requestFocus();
        case SetupPhase.server:
          _serverFocus.requestFocus();
        case SetupPhase.credentials:
          _usernameFocus.requestFocus();
        case SetupPhase.ready:
          break;
      }
    });
  }

  void _back() {
    if (model.isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _password.clear();
    model.back();
  }

  Future<void> _pasteServer() async {
    try {
      final text =
          (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
      if (!mounted) return;
      if (text.isEmpty) {
        _message('Clipboard does not contain a server address.');
        return;
      }
      _server.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _message('Server address pasted.');
    } on PlatformException {
      if (mounted) _message('Unable to read the clipboard.');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _next() async {
    FocusManager.instance.primaryFocus?.unfocus();
    switch (model.phase) {
      case SetupPhase.connection:
        await model.continueConnection();
      case SetupPhase.server:
        await model.checkServer(_server.text);
      case SetupPhase.credentials:
        final password = _password.text;
        _password.clear();
        await model.signIn(username: _username.text, password: password);
      case SetupPhase.ready:
        break;
    }
  }

  @override
  void dispose() {
    model.removeListener(_changed);
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _switchFocus.dispose();
    _serverFocus.dispose();
    _usernameFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250);
      return PopScope(
        canPop: model.phase == SetupPhase.connection && !model.isBusy,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -0.8),
                radius: 1.5,
                colors: [Color(0xFF241A13), Color(0xFF11100F)],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final short = constraints.maxHeight < 650;
                  final inset = short ? 12.0 : 24.0;
                  final padding = short ? 20.0 : 32.0;
                  final content = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/branding/soup-sidebar-mark.png',
                            width: 26,
                            height: 26,
                            color: colors.primary,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Soup',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              switch (model.phase) {
                                SetupPhase.connection => 'Connection · 1 / 3',
                                SetupPhase.server => 'Server · 2 / 3',
                                SetupPhase.credentials ||
                                SetupPhase.ready => 'Sign in · 3 / 3',
                              },
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: short ? 16 : 28),
                      if (model.error case final error?) ...[
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * 0.25,
                          ),
                          child: SingleChildScrollView(
                            child: Semantics(
                              liveRegion: true,
                              child: Container(
                                key: const ValueKey('connection-error'),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: colors.onErrorContainer,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Flexible(
                        child: SingleChildScrollView(
                          key: const ValueKey('setup-scroll'),
                          controller: _scroll,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  switch (model.phase) {
                                    SetupPhase.connection => 'Welcome to Soup',
                                    SetupPhase.server =>
                                      'Find your Jellyfin server',
                                    SetupPhase.credentials =>
                                      'Sign in to ${model.serverInfo?.name ?? 'Jellyfin'}',
                                    SetupPhase.ready => 'You’re all set',
                                  },
                                  style:
                                      (short
                                              ? Theme.of(
                                                  context,
                                                ).textTheme.headlineSmall
                                              : Theme.of(
                                                  context,
                                                ).textTheme.headlineMedium)
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.6,
                                          ),
                                ),
                              ),
                              SizedBox(height: short ? 12 : 20),
                              ..._fields(context, short, duration),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: short ? 16 : 24),
                      _footer(),
                    ],
                  );
                  return Padding(
                    padding: EdgeInsets.all(inset),
                    child: Center(
                      child: FocusTraversalGroup(
                        key: const ValueKey('root-focus-traversal'),
                        policy: ReadingOrderTraversalPolicy(),
                        child: Container(
                          key: const ValueKey('setup-card'),
                          constraints: const BoxConstraints(maxWidth: 640),
                          padding: EdgeInsets.all(padding),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(
                              color: colors.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x24000000),
                                blurRadius: 48,
                                offset: Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: constraints.maxHeight < 280
                                ? SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxHeight: 480,
                                      ),
                                      child: content,
                                    ),
                                  )
                                : content,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _fields(BuildContext context, bool short, Duration duration) {
    final colors = Theme.of(context).colorScheme;
    final caption = TextStyle(color: colors.onSurfaceVariant, height: 1.45);
    return switch (model.phase) {
      SetupPhase.connection => [
        if (!short) ...[
          Text('Your Jellyfin library, ready when you are.', style: caption),
          const SizedBox(height: 24),
        ],
        ListenableBuilder(
          listenable: _switchFocus,
          builder: (context, _) => SwitchListTile.adaptive(
            key: const ValueKey('tailscale-toggle'),
            focusNode: _switchFocus,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _switchFocus.hasFocus
                    ? colors.primary
                    : colors.outlineVariant,
                width: _switchFocus.hasFocus ? 2 : 1,
              ),
            ),
            title: const Text('Use Tailscale'),
            subtitle: const Text(
              'Optional · For a server on your Tailscale network',
            ),
            value: model.tailscaleEnabled,
            onChanged: model.initialized && !model.isBusy
                ? (value) => unawaited(model.setTailscaleEnabled(value))
                : null,
          ),
        ),
        _AnimatedReveal(
          duration: duration,
          child: AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, _) => ExcludeFocus(
                excluding: animation.status == AnimationStatus.reverse,
                child: ExcludeSemantics(
                  excluding: animation.status == AnimationStatus.reverse,
                  child: IgnorePointer(
                    ignoring: animation.status == AnimationStatus.reverse,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                ),
              ),
            ),
            child: model.tailscaleEnabled
                ? Padding(
                    key: ValueKey(
                      Object.hash(
                        model.status.phase,
                        model.status.authorizationUrl,
                      ),
                    ),
                    padding: const EdgeInsets.only(top: 16),
                    child: _tailscaleArea(context, short),
                  )
                : const SizedBox.shrink(key: ValueKey('direct-connection')),
          ),
        ),
      ],
      SetupPhase.server => [
        Text(
          model.tailscaleEnabled
              ? 'Enter the address of your server on Tailscale.'
              : 'Enter the address of a Jellyfin server reachable from this device.',
          style: caption,
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('server-url-field'),
          controller: _server,
          focusNode: _serverFocus,
          enabled: !model.isBusy,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: model.isBusy ? null : (_) => _next(),
          decoration: InputDecoration(
            labelText: 'Server address',
            hintText: model.tailscaleEnabled
                ? 'http://jellyfin:8096'
                : 'http://192.168.1.10:8096',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('paste-server-url-button'),
            onPressed: model.isBusy ? null : _pasteServer,
            icon: const Icon(PhosphorIconsRegular.clipboardText, size: 18),
            label: const Text('Paste server address'),
          ),
        ),
      ],
      SetupPhase.credentials => [
        Text(model.serverUrl?.toString() ?? '', style: caption),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('username-field'),
          controller: _username,
          focusNode: _usernameFocus,
          enabled: !model.isBusy,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('password-field'),
          controller: _password,
          enabled: !model.isBusy,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: model.isBusy ? null : (_) => _next(),
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ],
      SetupPhase.ready => [Text('Your library is ready.', style: caption)],
    };
  }

  Widget _tailscaleArea(BuildContext context, bool short) {
    final status = model.status;
    final url = status.authorizationUrl;
    if (status.phase == TailscaleConnectionPhase.awaitingLogin && url != null) {
      final qr = Container(
        key: const ValueKey('tailscale-authorization-qr'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: QrImageView(
          data: url.toString(),
          size: short ? 176 : 220,
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
          semanticsLabel: 'Tailscale sign-in QR code',
        ),
      );
      final instructions = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan to sign in',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan this code with another device and sign in to Tailscale.',
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: const Text(
              'Waiting for sign-in',
              key: ValueKey('connection-status'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('retry-tailscale-login-button'),
            onPressed: model.isBusy ? null : model.retryTailscale,
            child: const Text('Get a new code'),
          ),
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 440
            ? Row(
                children: [
                  qr,
                  const SizedBox(width: 24),
                  Expanded(child: instructions),
                ],
              )
            : Column(children: [qr, const SizedBox(height: 16), instructions]),
      );
    }
    final connected = model.tailscaleConnected;
    final failed =
        status.phase == TailscaleConnectionPhase.failed ||
        status.phase == TailscaleConnectionPhase.disconnected;
    final approval = status.phase == TailscaleConnectionPhase.awaitingApproval;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (connected || failed)
              Icon(
                connected
                    ? PhosphorIconsRegular.checkCircle
                    : PhosphorIconsRegular.warningCircle,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected
                        ? 'Connected to Tailscale'
                        : failed
                        ? 'Unable to connect'
                        : approval
                        ? 'Waiting for device approval'
                        : 'Preparing sign-in…',
                    key: const ValueKey('connection-status'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    connected
                        ? 'Select Next to continue.'
                        : failed
                        ? 'Try again, or turn off Tailscale to connect directly.'
                        : approval
                        ? 'Ask your administrator to approve this device in Tailscale. You can continue once it is approved.'
                        : 'Your sign-in code will appear here.',
                  ),
                  if (failed)
                    TextButton(
                      key: const ValueKey('retry-tailscale-login-button'),
                      onPressed: model.isBusy ? null : model.retryTailscale,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final connection = model.phase == SetupPhase.connection;
    final enabled = connection
        ? model.canContinueConnection
        : model.initialized && !model.isBusy;
    return Row(
      children: [
        if (!connection) ...[
          TextButton(
            key: const ValueKey('onboarding-back-button'),
            onPressed: model.isBusy ? null : _back,
            child: const Text('Back'),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: FilledButton(
            key: ValueKey(switch (model.phase) {
              SetupPhase.connection => 'connection-next-button',
              SetupPhase.server => 'check-server-button',
              SetupPhase.credentials || SetupPhase.ready => 'sign-in-button',
            }),
            onPressed: enabled ? _next : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (model.isBusy) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    model.isBusy
                        ? switch (model.phase) {
                            SetupPhase.connection => 'Preparing…',
                            SetupPhase.server => 'Checking…',
                            _ => 'Signing in…',
                          }
                        : model.phase == SetupPhase.credentials
                        ? 'Sign in'
                        : 'Next',
                  ),
                ),
                if (!model.isBusy) ...[
                  const SizedBox(width: 10),
                  const Icon(PhosphorIconsRegular.arrowRight, size: 18),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedReveal extends StatelessWidget {
  const _AnimatedReveal({required this.duration, required this.child});
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => duration == Duration.zero
      ? child
      : AnimatedSize(
          duration: duration,
          alignment: Alignment.topCenter,
          curve: Curves.easeInOutCubic,
          child: child,
        );
}
