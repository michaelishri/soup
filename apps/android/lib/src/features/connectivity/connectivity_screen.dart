import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';
import 'package:soup/src/features/connectivity/onboarding_backdrop.dart';
import 'package:soup/src/features/shared/soup_mark.dart';
import 'package:soup/src/features/shared/tv_text_input.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

class ConnectivityScreen extends StatefulWidget {
  const ConnectivityScreen({
    required this.viewModel,
    this.tvTextInput = const TvTextInput(),
    super.key,
  });
  final ConnectivityViewModel viewModel;
  final TvTextInput tvTextInput;

  @override
  State<ConnectivityScreen> createState() => _ConnectivityScreenState();
}

class _ConnectivityScreenState extends State<ConnectivityScreen>
    with WidgetsBindingObserver {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _switchFocus = FocusNode(debugLabel: 'use Tailscale');
  final _serverFocus = FocusNode(debugLabel: 'Jellyfin server');
  final _protocolFocus = FocusNode(debugLabel: 'server protocol');
  String _serverProtocol = 'https';
  final _usernameFocus = FocusNode(debugLabel: 'Jellyfin username');
  final _passwordFocus = FocusNode(debugLabel: 'Jellyfin password');
  final _nextFocus = FocusNode(debugLabel: 'setup Next');
  final _scroll = ScrollController();
  late SetupPhase _lastPhase;
  late bool _wasConnected;
  late bool _wasInitialized;
  bool _tv = false;
  bool _inputReady = false;
  bool _editingTv = false;
  int _focusGeneration = 0;
  int _editGeneration = 0;
  ConnectivityViewModel get model => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _lastPhase = model.phase;
    _wasConnected = model.tailscaleConnected;
    _wasInitialized = model.initialized;
    _server.addListener(_serverChanged);
    _server.text = model.serverUrl?.toString() ?? '';
    _serverFocus.onKeyEvent = (_, event) => _serverKey(event);
    _protocolFocus.onKeyEvent = (_, event) => _serverKey(event);
    _nextFocus.onKeyEvent = (_, event) {
      if (model.phase == SetupPhase.server &&
          (event is KeyDownEvent || event is KeyRepeatEvent) &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _serverFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    model.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _usernameFocus.addListener(_credentialFocusChanged);
    _passwordFocus.addListener(_credentialFocusChanged);
    unawaited(_initializeInput());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    model.setForeground(state == AppLifecycleState.resumed);
  }

  void _credentialFocusChanged() {
    if (!_tv && (_usernameFocus.hasFocus || _passwordFocus.hasFocus)) {
      model.pauseQuickConnect();
    }
  }

  void _resumeQuickConnect({bool newCode = false}) {
    if (!_tv) FocusManager.instance.primaryFocus?.unfocus();
    unawaited(model.startQuickConnect(newCode: newCode));
  }

  Future<void> _initializeInput() async {
    final tv = await widget.tvTextInput.isTelevision();
    if (!mounted) return;
    setState(() {
      _tv = tv;
      _inputReady = true;
    });
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
    final phaseChanged = model.phase != _lastPhase;
    final connectionChanged = model.tailscaleConnected != _wasConnected;
    final initialized = model.initialized && !_wasInitialized;
    _lastPhase = model.phase;
    _wasConnected = model.tailscaleConnected;
    _wasInitialized = model.initialized;
    if (phaseChanged) {
      _editGeneration++;
      _password.clear();
      if (_editingTv) unawaited(widget.tvTextInput.dismiss());
      if (_server.text.isEmpty && model.serverUrl != null) {
        _server.text = model.serverUrl.toString();
      }
    }
    if (phaseChanged ||
        initialized ||
        (connectionChanged && model.phase == SetupPhase.connection)) {
      _focusStep();
    }
  }

  void _focusStep({bool retry = false}) {
    final generation = ++_focusGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inputReady || generation != _focusGeneration) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      switch (model.phase) {
        case SetupPhase.connection:
          if (model.tailscaleConnected && model.canContinueConnection) {
            _nextFocus.requestFocus();
            return;
          }
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
          if (!_tv && !retry) return;
          (retry && _username.text.trim().isNotEmpty
                  ? _passwordFocus
                  : _usernameFocus)
              .requestFocus();
        case SetupPhase.ready:
          break;
      }
    });
  }

  void _back() {
    if (model.isBusy && model.phase != SetupPhase.credentials) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _password.clear();
    model.back();
  }

  void _serverChanged() {
    final value = _server.value;
    final prefix = RegExp(
      r'^\s*(https?)://',
      caseSensitive: false,
    ).firstMatch(value.text);
    if (prefix == null) return;
    final protocol = prefix.group(1)!.toLowerCase();
    final removed = prefix.end;
    final address = value.text.substring(removed);
    _server.value = TextEditingValue(
      text: address,
      selection: value.selection.isValid
          ? TextSelection(
              baseOffset: (value.selection.baseOffset - removed).clamp(
                0,
                address.length,
              ),
              extentOffset: (value.selection.extentOffset - removed).clamp(
                0,
                address.length,
              ),
            )
          : TextSelection.collapsed(offset: address.length),
    );
    if (_serverProtocol != protocol) {
      setState(() => _serverProtocol = protocol);
    }
  }

  KeyEventResult _serverKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _nextFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (_protocolFocus.hasFocus &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _serverFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (_tv &&
        _serverFocus.hasFocus &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _protocolFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _next() async {
    if (model.isBusy) return;
    final phase = model.phase;
    FocusManager.instance.primaryFocus?.unfocus();
    switch (model.phase) {
      case SetupPhase.connection:
        await model.continueConnection();
      case SetupPhase.server:
        final address = _server.text.trim();
        await model.checkServer(
          address.isEmpty || address.contains('://')
              ? address
              : '$_serverProtocol://$address',
        );
      case SetupPhase.credentials:
        final password = _password.text;
        _password.clear();
        await model.signIn(username: _username.text, password: password);
      case SetupPhase.ready:
        break;
    }
    // Validation or network failures leave the step in place. Restore a useful
    // remote focus stop instead of dropping focus into the root scope.
    if (mounted && model.phase == phase) _focusStep(retry: true);
  }

  Future<void> _editTvField({
    required TextEditingController controller,
    required FocusNode focus,
    required String label,
    bool password = false,
    bool url = false,
    bool next = false,
  }) async {
    if (_editingTv || model.isBusy) return;
    final phase = model.phase;
    if (phase == SetupPhase.credentials) model.pauseQuickConnect();
    _editingTv = true;
    final generation = _editGeneration;
    TvTextEdit? result;
    try {
      result = await widget.tvTextInput.edit(
        label: label,
        text: controller.text,
        obscureText: password,
        isUrl: url,
        next: next,
      );
    } on PlatformException {
      if (mounted) {
        _message('Unable to open the keyboard. Select the field to retry.');
      }
    } finally {
      _editingTv = false;
    }
    if (!mounted || model.phase != phase || generation != _editGeneration) {
      return;
    }
    focus.requestFocus();
    if (result == null) return;
    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.text.length),
    );
    if (!result.submitted) return;
    if (next) {
      _passwordFocus.requestFocus();
      await _editTvField(
        controller: _password,
        focus: _passwordFocus,
        label: 'Password',
        password: true,
      );
    } else {
      await _next();
    }
  }

  @override
  void dispose() {
    if (_editingTv) unawaited(widget.tvTextInput.dismiss());
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_changed);
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _switchFocus.dispose();
    _serverFocus.dispose();
    _protocolFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _nextFocus.dispose();
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
          resizeToAvoidBottomInset: !_tv,
          body: OnboardingBackdrop(
            key: const ValueKey('setup-canvas'),
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
                                  child: _StepTransition(
                                    phase: model.phase,
                                    duration: duration,
                                    child: model.phase == SetupPhase.credentials
                                        ? _signInForm(
                                            context,
                                            wide: wide,
                                            short: short,
                                            duration: duration,
                                          )
                                        : wide
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
                                                  alignment:
                                                      Alignment.centerLeft,
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
                                ),
                                SizedBox(height: short ? 20 : 32),
                                LayoutBuilder(
                                  builder: (context, bounds) => Align(
                                    alignment: Alignment.centerRight,
                                    child: SizedBox(
                                      width: wide
                                          ? model.phase ==
                                                    SetupPhase.credentials
                                                ? (bounds.maxWidth - 24) * 0.5
                                                : (bounds.maxWidth - 56) * 0.6
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
        const SoupMark(size: 46),
        const SizedBox(width: 10),
        Text(
          'SOUP',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
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
                            width: 28,
                            height: 5,
                            margin: EdgeInsets.only(left: index == 1 ? 0 : 6),
                            decoration: BoxDecoration(
                              color: index <= step
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.zero,
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
    final title = switch (model.phase) {
      SetupPhase.connection => 'Welcome to Soup',
      SetupPhase.server => 'Find your Jellyfin server',
      SetupPhase.credentials =>
        'Sign in to ${model.serverInfo?.name ?? 'Jellyfin'}',
      SetupPhase.ready => 'You’re all set',
    };
    return Container(
      key: const ValueKey('setup-intro'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: SoupTheme.onboardingAccent,
        boxShadow: [
          BoxShadow(color: SoupTheme.onboardingInk, offset: Offset(6, 6)),
        ],
      ),
      child: Column(
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
              color: SoupTheme.onboardingSignal,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            label: title,
            child: ExcludeSemantics(
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: SoupTheme.onboardingSurface,
                  fontSize: wide ? 60 : 48,
                  letterSpacing: -0.5,
                  height: 0.98,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(width: 44, height: 4, color: SoupTheme.onboardingSignal),
          const SizedBox(height: 16),
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
              color: SoupTheme.onboardingSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
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
                    SizedBox(height: short ? 28 : 32),
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
          builder: (context, _) => AnimatedContainer(
            key: const ValueKey('tailscale-focus-ring'),
            duration: _focusDuration,
            curve: Curves.easeOutCubic,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _switchFocus.hasFocus
                    ? colors.primary
                    : colors.outlineVariant.withValues(alpha: 0.65),
                width: _switchFocus.hasFocus ? 2 : 1,
              ),
            ),
            // Give ink a local canvas so it follows the tile when the QR area
            // changes height or the whole step slides into place.
            child: Material(
              key: const ValueKey('tailscale-tile-material'),
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile.adaptive(
                key: const ValueKey('tailscale-toggle'),
                focusNode: _switchFocus,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                tileColor: SoupTheme.onboardingSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                title: const Text(
                  'Use Tailscale',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Optional · Use your private network'),
                value: model.tailscaleEnabled,
                onChanged: model.initialized && !model.isBusy
                    ? (value) => unawaited(model.setTailscaleEnabled(value))
                    : null,
              ),
            ),
          ),
        ),
        if (!model.tailscaleEnabled) ...[
          const SizedBox(height: 20),
          Text('Select Next to connect directly to Jellyfin.', style: caption),
        ],
        _AnimatedReveal(
          duration: duration,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: 'Server protocol',
              child: OutlinedButton(
                key: const ValueKey('server-protocol-button'),
                focusNode: _protocolFocus,
                style: _buttonMotion.copyWith(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                onPressed: model.isBusy
                    ? null
                    : () => setState(() {
                        _serverProtocol = _serverProtocol == 'https'
                            ? 'http'
                            : 'https';
                      }),
                child: Text('$_serverProtocol://'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tv
                  ? TvTextField(
                      key: const ValueKey('server-url-field'),
                      controller: _server,
                      focusNode: _serverFocus,
                      enabled: !model.isBusy,
                      label: 'Server address',
                      hint: model.tailscaleEnabled
                          ? 'jellyfin:8096'
                          : 'jellyfin.example.com',
                      onEdit: () => _editTvField(
                        controller: _server,
                        focus: _serverFocus,
                        label: 'Server address',
                        url: true,
                      ),
                    )
                  : TextField(
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
                            ? 'jellyfin:8096'
                            : 'jellyfin.example.com',
                      ),
                    ),
            ),
          ],
        ),
      ],
      SetupPhase.credentials => [
        if (_tv)
          TvTextField(
            key: const ValueKey('username-field'),
            controller: _username,
            focusNode: _usernameFocus,
            enabled: !model.isBusy,
            label: 'Username',
            onEdit: () => _editTvField(
              controller: _username,
              focus: _usernameFocus,
              label: 'Username',
              next: true,
            ),
          )
        else
          TextField(
            key: const ValueKey('username-field'),
            controller: _username,
            focusNode: _usernameFocus,
            onTap: model.pauseQuickConnect,
            onChanged: (_) => model.pauseQuickConnect(),
            enabled: !model.isBusy,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Username'),
          ),
        const SizedBox(height: 16),
        if (_tv)
          TvTextField(
            key: const ValueKey('password-field'),
            controller: _password,
            focusNode: _passwordFocus,
            enabled: !model.isBusy,
            label: 'Password',
            obscureText: true,
            onEdit: () => _editTvField(
              controller: _password,
              focus: _passwordFocus,
              label: 'Password',
              password: true,
            ),
          )
        else
          TextField(
            key: const ValueKey('password-field'),
            controller: _password,
            focusNode: _passwordFocus,
            onTap: model.pauseQuickConnect,
            onChanged: (_) => model.pauseQuickConnect(),
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

  Widget _signInForm(
    BuildContext context, {
    required bool wide,
    required bool short,
    required Duration duration,
  }) {
    final theme = Theme.of(context);
    Widget panel(String key, List<Widget> children) => Container(
      key: ValueKey(key),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: key == 'quick-connect-panel'
            ? SoupTheme.onboardingSignal
            : SoupTheme.onboardingSurface,
        border: Border.all(color: theme.colorScheme.onSurface, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    final quick = panel('quick-connect-panel', _quickConnectContent(context));
    final password = panel('password-panel', [
      Text('Username and password', style: theme.textTheme.titleLarge),
      const SizedBox(height: 16),
      ..._fields(context, short, duration),
      if (model.error case final error?) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            error,
            key: const ValueKey('connection-error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ],
    ]);
    return SingleChildScrollView(
      key: const ValueKey('setup-scroll'),
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign in to ${model.serverInfo?.name ?? 'Jellyfin'}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            model.serverUrl?.toString() ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(
              key: const ValueKey('sign-in-split-layout'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: quick),
                const SizedBox(width: 24),
                Expanded(child: password),
              ],
            )
          else ...[
            quick,
            const SizedBox(height: 16),
            password,
          ],
        ],
      ),
    );
  }

  List<Widget> _quickConnectContent(BuildContext context) {
    final theme = Theme.of(context);
    final phase = model.quickConnectPhase;
    final code = model.quickConnectCode;
    final waiting = phase == QuickConnectPhase.waiting;
    final paused = phase == QuickConnectPhase.paused;
    final checking =
        phase == QuickConnectPhase.checking || phase == QuickConnectPhase.idle;
    final completing = phase == QuickConnectPhase.completing;
    final unavailable = phase == QuickConnectPhase.unavailable;
    final expired = phase == QuickConnectPhase.expired;
    final message = switch (phase) {
      QuickConnectPhase.idle ||
      QuickConnectPhase.checking => 'Preparing Quick Connect…',
      QuickConnectPhase.waiting => 'Waiting for approval',
      QuickConnectPhase.paused =>
        'Paused while you use another sign-in method.',
      QuickConnectPhase.expired =>
        'This code has expired. Get a new code to continue.',
      QuickConnectPhase.unavailable =>
        'Quick Connect is disabled on this server. You can sign in with your username and password.',
      QuickConnectPhase.error =>
        model.quickConnectError ?? 'Unable to use Quick Connect. Please retry.',
      QuickConnectPhase.completing => 'Approved. Signing in…',
    };
    return [
      Text('Quick Connect', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      if (!unavailable) ...[
        Text(
          'On a device already signed in to Jellyfin, open Quick Connect in Settings and enter this code.',
          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
        ),
        if (code != null) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Quick Connect code: ${code.split('').join(' ')}',
            child: ExcludeSemantics(
              child: Text(
                code,
                key: const ValueKey('quick-connect-code'),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontSize: 40,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
      Semantics(
        liveRegion: true,
        child: Text(
          message,
          key: const ValueKey('quick-connect-status'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('quick-connect-action'),
          style: _buttonMotion,
          // Keep the selected action focused while its label shows progress.
          // Repeated presses are ignored until the current request completes.
          onPressed: model.isBusy && !completing
              ? null
              : () {
                  if (checking || completing) return;
                  _resumeQuickConnect(
                    newCode: waiting || expired || unavailable,
                  );
                },
          child: Text(
            waiting || expired
                ? 'Get a new code'
                : paused
                ? 'Resume Quick Connect'
                : unavailable
                ? 'Check again'
                : checking
                ? 'Preparing…'
                : completing
                ? 'Signing in…'
                : 'Retry',
          ),
        ),
      ),
    ];
  }

  Widget _tailscaleArea(BuildContext context, bool short) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = model.status;
    final url = status.authorizationUrl;
    final stacked = MediaQuery.sizeOf(context).width < 840;
    if (status.phase == TailscaleConnectionPhase.awaitingLogin && url != null) {
      final qr = Container(
        key: const ValueKey('tailscale-authorization-qr'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
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
      Widget instructions({required bool centered}) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text('Scan to sign in', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Use another device to sign in to Tailscale.',
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              'Waiting for sign-in',
              key: const ValueKey('connection-status'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            key: const ValueKey('retry-tailscale-login-button'),
            style: _buttonMotion,
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
                  Expanded(child: instructions(centered: false)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(child: qr),
                  const SizedBox(height: 12),
                  instructions(centered: true),
                ],
              ),
      );
    }
    if (model.tailscaleConnected) {
      return Semantics(
        liveRegion: true,
        child: Container(
          key: const ValueKey('tailscale-connected'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsRegular.check,
                  color: colors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected to Tailscale',
                      key: const ValueKey('connection-status'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select Next to find your Jellyfin server.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
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
            if (failed)
              Icon(
                PhosphorIconsRegular.warningCircle,
                color: colors.primary,
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
                    failed
                        ? 'Unable to connect'
                        : approval
                        ? 'Waiting for device approval'
                        : 'Preparing sign-in…',
                    key: const ValueKey('connection-status'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    failed
                        ? 'Try again, or turn off Tailscale to connect directly.'
                        : approval
                        ? 'Ask your administrator to approve this device in Tailscale. You can continue once it is approved.'
                        : 'Your sign-in code will appear here.',
                  ),
                  if (failed)
                    TextButton(
                      key: const ValueKey('retry-tailscale-login-button'),
                      style: _buttonMotion,
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
      key: const ValueKey('setup-footer'),
      children: [
        if (!connection) ...[
          TextButton(
            key: const ValueKey('onboarding-back-button'),
            style: _buttonMotion,
            onPressed: model.isBusy && model.phase != SetupPhase.credentials
                ? null
                : _back,
            child: const Text('Back'),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: FilledButton(
            focusNode: _nextFocus,
            style: _buttonMotion,
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

  Duration get _focusDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200);

  ButtonStyle get _buttonMotion =>
      ButtonStyle(animationDuration: _focusDuration);
}

// Animate only the incoming step. Keeping a single mounted form avoids sharing
// text controllers, focus nodes or scroll positions with an outgoing copy.
class _StepTransition extends StatefulWidget {
  const _StepTransition({
    required this.phase,
    required this.duration,
    required this.child,
  });

  final SetupPhase phase;
  final Duration duration;
  final Widget child;

  @override
  State<_StepTransition> createState() => _StepTransitionState();
}

class _StepTransitionState extends State<_StepTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  double _direction = 1;

  @override
  void didUpdateWidget(covariant _StepTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.duration == Duration.zero) {
      _controller.value = 1;
    } else if (oldWidget.phase != widget.phase) {
      _direction = widget.phase.index > oldWidget.phase.index ? 1 : -1;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    key: const ValueKey('setup-step-transition'),
    opacity: _opacity,
    alwaysIncludeSemantics: true,
    child: AnimatedBuilder(
      animation: _opacity,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        key: const ValueKey('setup-step-offset'),
        offset: Offset(12 * _direction * (1 - _opacity.value), 0),
        child: child,
      ),
    ),
  );
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
