import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SoupVideoValue {
  const SoupVideoValue({
    this.initialized = false,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.caption = '',
    this.error,
  });

  final bool initialized;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final String caption;
  final String? error;
}

abstract interface class SoupVideoController implements Listenable {
  SoupVideoValue get value;

  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Widget buildView();

  Future<void> close();
}

abstract interface class SoupVideoControllerFactory {
  SoupVideoController create(Uri uri, {Future<String>? subtitleVtt});
}

class PlatformVideoControllerFactory implements SoupVideoControllerFactory {
  const PlatformVideoControllerFactory();

  @override
  SoupVideoController create(Uri uri, {Future<String>? subtitleVtt}) {
    return PlatformVideoController(uri, subtitleVtt: subtitleVtt);
  }
}

class PlatformVideoController extends ChangeNotifier
    implements SoupVideoController {
  PlatformVideoController(Uri uri, {Future<String>? subtitleVtt})
    : _controller = VideoPlayerController.networkUrl(
        uri,
        closedCaptionFile: subtitleVtt?.then(WebVTTCaptionFile.new),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      ) {
    _controller.addListener(_sync);
  }

  final VideoPlayerController _controller;
  SoupVideoValue _value = const SoupVideoValue();

  @override
  SoupVideoValue get value => _value;

  void _sync() {
    final source = _controller.value;
    _value = SoupVideoValue(
      initialized: source.isInitialized,
      playing: source.isPlaying,
      buffering: source.isBuffering,
      position: source.position,
      duration: source.duration,
      aspectRatio: source.aspectRatio <= 0 ? 16 / 9 : source.aspectRatio,
      caption: source.caption.text,
      error: source.errorDescription,
    );
    notifyListeners();
  }

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> seekTo(Duration position) => _controller.seekTo(position);

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> close() async {
    _controller.removeListener(_sync);
    await _controller.dispose();
    dispose();
  }
}
