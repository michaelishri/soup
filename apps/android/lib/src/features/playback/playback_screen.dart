import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/appearance/soup_theme.dart';
import 'package:soup/src/data/playback/playback_bridge.dart';
import 'package:soup/src/features/playback/video_controller.dart';

class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({
    required this.api,
    required this.session,
    required this.item,
    required this.startAt,
    this.controllerFactory = const PlatformVideoControllerFactory(),
    super.key,
  });

  final JellyfinApi api;
  final JellyfinSession session;
  final JellyfinItem item;
  final Duration startAt;
  final SoupVideoControllerFactory controllerFactory;

  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  late final PlaybackBridge _bridge;
  JellyfinPlaybackPlan? _plan;
  SoupVideoController? _controller;
  JellyfinPlayMethod? _method;
  JellyfinSubtitleTrack? _subtitle;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'playback back');
  bool _loading = true;
  String? _error;
  Duration _lastReported = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bridge = PlaybackBridge(
      widget.api.transport,
      widget.session,
      widget.api.authenticatedHeaders(widget.session),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _backFocusNode.requestFocus();
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await widget.api.getPlaybackPlan(
        widget.session,
        widget.item,
        startAt: widget.startAt,
      );
      await _bridge.start();
      _plan = plan;
      _subtitle = null;
      if (plan.directUri != null) {
        try {
          await _load(
            plan.directMethod ?? JellyfinPlayMethod.directPlay,
            startAt: widget.startAt,
          );
        } on Object {
          if (plan.transcodeUri == null) rethrow;
          await _load(JellyfinPlayMethod.transcode, startAt: widget.startAt);
        }
      } else {
        await _load(JellyfinPlayMethod.transcode, startAt: widget.startAt);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is JellyfinApiException
            ? error.message
            : 'Could not start playback. $error';
      });
    }
  }

  Future<void> _load(
    JellyfinPlayMethod method, {
    required Duration startAt,
    String? subtitleText,
  }) async {
    final plan = _plan!;
    final upstream = method == JellyfinPlayMethod.transcode
        ? plan.transcodeUri
        : plan.directUri;
    if (upstream == null) {
      throw const JellyfinApiException('No playback source is available.');
    }
    final old = _controller;
    if (old != null) {
      old.removeListener(_playerChanged);
      await old.close();
    }
    final controller = widget.controllerFactory.create(
      _bridge.localUriFor(upstream),
      subtitleVtt: subtitleText == null ? null : Future.value(subtitleText),
    );
    _controller = controller;
    _method = method;
    controller.addListener(_playerChanged);
    await controller.initialize();
    if (startAt > Duration.zero) await controller.seekTo(startAt);
    await controller.play();
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(
      widget.api
          .reportPlaybackStarted(
            widget.session,
            plan,
            method: method,
            position: startAt,
          )
          .catchError((Object _) {}),
    );
  }

  void _playerChanged() {
    if (!mounted) return;
    setState(() {});
    final controller = _controller;
    final plan = _plan;
    final method = _method;
    if (controller == null || plan == null || method == null) return;
    final position = controller.value.position;
    if ((position - _lastReported).abs() >= const Duration(seconds: 10)) {
      _lastReported = position;
      unawaited(
        widget.api
            .reportPlaybackProgress(
              widget.session,
              plan,
              method: method,
              position: position,
              paused: !controller.value.playing,
            )
            .catchError((Object _) {}),
      );
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.playing) {
      await controller.pause();
    } else {
      await controller.play();
    }
    await _reportNow();
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final target = controller.value.position + delta;
    await controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > duration
          ? duration
          : target,
    );
    await _reportNow();
  }

  Future<void> _reportNow() async {
    final controller = _controller;
    final plan = _plan;
    final method = _method;
    if (controller == null || plan == null || method == null) return;
    _lastReported = controller.value.position;
    try {
      await widget.api.reportPlaybackProgress(
        widget.session,
        plan,
        method: method,
        position: controller.value.position,
        paused: !controller.value.playing,
      );
    } on Object {
      // Playback continues if presence reporting temporarily fails.
    }
  }

  Future<void> _cycleSubtitle() async {
    final plan = _plan;
    final controller = _controller;
    final method = _method;
    if (plan == null || controller == null || method == null) return;
    final current = _subtitle;
    final next = current == null
        ? (plan.subtitles.isEmpty ? null : plan.subtitles.first)
        : plan.subtitles.indexOf(current) == plan.subtitles.length - 1
        ? null
        : plan.subtitles[plan.subtitles.indexOf(current) + 1];
    if (next == current) return;
    final position = controller.value.position;
    setState(() {
      _subtitle = next;
      _loading = true;
    });
    try {
      final subtitleText = next == null
          ? null
          : await widget.api.getSubtitle(widget.session, next);
      await _load(method, startAt: position, subtitleText: subtitleText);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _subtitle = current;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch subtitles. $error')),
        );
      }
    }
  }

  Future<void> _shutdown() async {
    final controller = _controller;
    final plan = _plan;
    final method = _method;
    if (controller != null && plan != null && method != null) {
      try {
        await widget.api.reportPlaybackStopped(
          widget.session,
          plan,
          method: method,
          position: controller.value.position,
        );
      } on Object {
        // Closing the player must not be blocked by presence reporting.
      }
      controller.removeListener(_playerChanged);
      await controller.close();
    }
    await _bridge.close();
  }

  @override
  void dispose() {
    unawaited(_shutdown());
    _backFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller?.value ?? const SoupVideoValue();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowRight): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                PreviousFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          },
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (value.initialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: value.aspectRatio,
                      child: _controller!.buildView(),
                    ),
                  ),
                if (value.caption.isNotEmpty)
                  Positioned(
                    left: 80,
                    right: 80,
                    bottom: 150,
                    child: Text(
                      value.caption,
                      key: const ValueKey('playback-caption'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                  ),
                _Controls(
                  title: widget.item.name,
                  value: value,
                  method: _method,
                  subtitle: _subtitle,
                  subtitleCount: _plan?.subtitles.length ?? 0,
                  backFocusNode: _backFocusNode,
                  onBack: () => Navigator.of(context).pop(),
                  onToggle: _togglePlayback,
                  onRewind: () => _seekBy(const Duration(seconds: -10)),
                  onForward: () => _seekBy(const Duration(seconds: 30)),
                  onSeek: (position) async {
                    await _controller?.seekTo(position);
                    await _reportNow();
                  },
                  onSubtitle: _cycleSubtitle,
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error case final error?)
                  _PlaybackError(error: error, onRetry: _initialize),
                if (value.buffering && !_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.title,
    required this.value,
    required this.method,
    required this.subtitle,
    required this.subtitleCount,
    required this.backFocusNode,
    required this.onBack,
    required this.onToggle,
    required this.onRewind,
    required this.onForward,
    required this.onSeek,
    required this.onSubtitle,
  });

  final String title;
  final SoupVideoValue value;
  final JellyfinPlayMethod? method;
  final JellyfinSubtitleTrack? subtitle;
  final int subtitleCount;
  final FocusNode backFocusNode;
  final VoidCallback onBack;
  final VoidCallback onToggle;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSubtitle;

  @override
  Widget build(BuildContext context) {
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds.clamp(0, durationMs);
    final chrome =
        Theme.of(
          context,
        ).extension<AuthenticatedThemeTokens>()?.playbackChrome ??
        const Color(0xE6000000);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 28, 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [chrome, Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: IconButton.filledTonal(
                  key: const ValueKey('playback-back-button'),
                  autofocus: true,
                  focusNode: backFocusNode,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (method case final method?)
                Chip(
                  key: const ValueKey('playback-method'),
                  label: Text(switch (method) {
                    JellyfinPlayMethod.directPlay => 'Direct Play',
                    JellyfinPlayMethod.directStream => 'Direct Stream',
                    JellyfinPlayMethod.transcode => 'Transcoding',
                  }),
                ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(40, 46, 40, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, chrome],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1.5),
                child: Slider(
                  key: const ValueKey('playback-progress'),
                  value: positionMs.toDouble(),
                  max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                  onChanged: durationMs <= 0
                      ? null
                      : (value) =>
                            onSeek(Duration(milliseconds: value.round())),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_time(value.position)),
                          Text(_time(value.duration)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: IconButton.filledTonal(
                              key: const ValueKey('rewind-button'),
                              tooltip: 'Back 10 seconds',
                              onPressed: onRewind,
                              icon: const Icon(Icons.replay_10),
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 16),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(3),
                            child: IconButton.filled(
                              key: const ValueKey('play-pause-button'),
                              tooltip: value.playing ? 'Pause' : 'Play',
                              onPressed: onToggle,
                              iconSize: 34,
                              icon: Icon(
                                value.playing ? Icons.pause : Icons.play_arrow,
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 16),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(4),
                            child: IconButton.filledTonal(
                              key: const ValueKey('forward-button'),
                              tooltip: 'Forward 30 seconds',
                              onPressed: onForward,
                              icon: const Icon(Icons.forward_30),
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 16),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(5),
                            child: compact
                                ? IconButton.filledTonal(
                                    key: const ValueKey('subtitle-button'),
                                    tooltip: subtitle?.label ?? 'Subtitles off',
                                    onPressed: subtitleCount == 0
                                        ? null
                                        : onSubtitle,
                                    icon: const Icon(Icons.subtitles),
                                  )
                                : FilledButton.tonalIcon(
                                    key: const ValueKey('subtitle-button'),
                                    onPressed: subtitleCount == 0
                                        ? null
                                        : onSubtitle,
                                    icon: const Icon(Icons.subtitles),
                                    label: Text(
                                      subtitle?.label ?? 'Subtitles off',
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _time(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xE6000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 16),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
