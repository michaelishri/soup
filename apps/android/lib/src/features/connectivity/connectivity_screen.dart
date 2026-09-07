import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/shared/soup_mark.dart';
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
          final switchContext = _switchFocus.context;
          if (switchContext != null) {
            unawaited(
              Scrollable.ensureVisible(
                switchContext,
                alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              ),
            );
          }
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
            key: const ValueKey('setup-canvas'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SoupTheme.onboardingGlow,
                  SoupTheme.onboardingBackground,
                  SoupTheme.onboardingShade,
                ],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final short = constraints.maxHeight < 650;
                    final wide =
                        constraints.maxWidth >= 840 &&
                        constraints.maxHeight >= 420 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 22.4;
                    final horizontal = constraints.maxWidth < 600 ? 24.0 : 48.0;
                    // A keyboard or very short window can leave less space than
                    // the fixed chrome needs. Let the whole page scroll then.
                    final tiny = constraints.maxHeight < 280;
                    final page = Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                        vertical: short ? 20 : 36,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: FocusTraversalGroup(
                            key: const ValueKey('root-focus-traversal'),
                            policy: ReadingOrderTraversalPolicy(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _header(context),
                                SizedBox(height: short ? 24 : 48),
                                Expanded(
                                  child: wide
                                      ? Row(
                                          key: const ValueKey(
                                            'setup-wide-layout',
                                          ),
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              flex: 4,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: SingleChildScrollView(
                                                  child: _intro(
                                                    context,
                                                    wide: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 56),
                                            Expanded(
                                              flex: 6,
                                              child: _form(
                                                context,
                                                short,
                                                duration,
                                                includeIntro: false,
                                              ),
                                            ),
                                          ],
                                        )
                                      : _form(
                                          context,
                                          short,
                                          duration,
                                          includeIntro: true,
                                        ),
                                ),
                                SizedBox(height: short ? 20 : 32),
                                LayoutBuilder(
                                  builder: (context, bounds) => Align(
                                    alignment: Alignment.centerRight,
                                    child: SizedBox(
                                      width: wide
                                          ? (bounds.maxWidth - 56) * 0.6
                                          : bounds.maxWidth,
                                      child: _footer(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    return tiny
                        ? SingleChildScrollView(
                            child: SizedBox(height: 600, child: page),
                          )
                        : page;
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = switch (model.phase) {
      SetupPhase.connection => 1,
      SetupPhase.server => 2,
      SetupPhase.credentials || SetupPhase.ready => 3,
    };
    final label = switch (model.phase) {
      SetupPhase.connection => 'Connection',
      SetupPhase.server => 'Server',
      SetupPhase.credentials || SetupPhase.ready => 'Sign in',
    };
    return Row(
      children: [
        const SoupMark(),
        const SizedBox(width: 10),
        Text(
          'Soup',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              label: 'Step $step of 3: $label',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$label · $step / 3',
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 1; index <= 3; index++)
                          Container(
                            width: 24,
                            height: 3,
                            margin: EdgeInsets.only(left: index == 1 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: index <= step
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _intro(BuildContext context, {required bool wide}) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('setup-intro'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (model.phase) {
            SetupPhase.connection => 'A LITTLE SETUP. A LOT TO WATCH.',
            SetupPhase.server => 'YOUR LIBRARY STARTS HERE.',
            SetupPhase.credentials ||
            SetupPhase.ready => 'MAKE YOURSELF AT HOME.',
          },
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.6,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            switch (model.phase) {
              SetupPhase.connection => 'Welcome to Soup',
              SetupPhase.server => 'Find your Jellyfin server',
              SetupPhase.credentials =>
                'Sign in to ${model.serverInfo?.name ?? 'Jellyfin'}',
              SetupPhase.ready => 'You’re all set',
            },
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: wide ? 44 : 36,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.3,
              height: 1.12,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          switch (model.phase) {
            SetupPhase.connection =>
              'Your films, shows and favourites.\nLet’s bring them a little closer.',
            SetupPhase.server =>
              model.tailscaleEnabled
                  ? 'Connect to your Jellyfin server through your Tailscale network.'
                  : 'Connect to a Jellyfin server reachable from this device.',
            SetupPhase.credentials =>
              'Use your Jellyfin account. Your next favourite is waiting.',
            SetupPhase.ready => 'Your library is ready.',
          },
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _form(
    BuildContext context,
    bool short,
    Duration duration, {
    required bool includeIntro,
  }) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisAlignment: includeIntro
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          if (model.error case final error?) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.3,
              ),
              child: SingleChildScrollView(
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('connection-error'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: colors.onErrorContainer),
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
                  if (includeIntro) ...[
                    _intro(context, wide: false),
                    SizedBox(height: short ? 28 : 40),
                  ],
                  ..._fields(context, short, duration),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fields(BuildContext context, bool short, Duration duration) {
    final colors = Theme.of(context).colorScheme;
    final caption = TextStyle(color: colors.onSurfaceVariant, height: 1.45);
    return switch (model.phase) {
      SetupPhase.connection => [
        ListenableBuilder(
          listenable: _switchFocus,
          builder: (context, _) => SwitchListTile.adaptive(
            key: const ValueKey('tailscale-toggle'),
            focusNode: _switchFocus,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            tileColor: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _switchFocus.hasFocus
                    ? colors.primary
                    : colors.outlineVariant.withValues(alpha: 0.65),
                width: _switchFocus.hasFocus ? 2 : 1,
              ),
            ),
            title: const Text(
              'Use Tailscale',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Optional · Connect through your private network',
            ),
            value: model.tailscaleEnabled,
            onChanged: model.initialized && !model.isBusy
                ? (value) => unawaited(model.setTailscaleEnabled(value))
                : null,
          ),
        ),
        if (!model.tailscaleEnabled) ...[
          const SizedBox(height: 20),
          Text(
            'No Tailscale? No problem. Select Next to connect directly to Jellyfin.',
            style: caption,
          ),
        ],
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
    final stacked = MediaQuery.sizeOf(context).width < 840;
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
          size: short
              ? 176
              : stacked
              ? 200
              : 220,
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
