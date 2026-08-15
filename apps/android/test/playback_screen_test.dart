import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/features/playback/playback_screen.dart';
import 'package:soup/src/features/playback/video_controller.dart';

void main() {
  final session = JellyfinSession(
    serverUrl: Uri.parse('http://jellyfin/'),
    serverId: 'server',
    userId: 'user',
    userName: 'Alex',
    accessToken: 'token',
  );
  const movie = JellyfinItem(id: 'movie', name: 'Movie', type: 'Movie');

  testWidgets('uses a supported direct-play source without transcoding', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        return http.Response(
          '{"PlaySessionId":"play","MediaSources":[{"Id":"source","Container":"mp4","SupportsDirectPlay":true,"TranscodingUrl":"/Videos/movie/master.m3u8"}]}',
          200,
        );
      }
      return http.Response('', 204);
    });
    addTearDown(client.close);
    final factory = FakeVideoControllerFactory();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PlaybackScreen(
          api: JellyfinApi(client, deviceId: 'device'),
          session: session,
          item: movie,
          startAt: Duration.zero,
          controllerFactory: factory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(factory.controllers, hasLength(1));
    expect(factory.controllers.single.uri.path, '/Videos/movie/stream.mp4');
    expect(find.text('Direct Play'), findsOneWidget);
    expect(factory.controllers.single.value.playing, isTrue);
  });

  testWidgets('falls back from failed direct play to HLS transcoding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/PlaybackInfo')) {
        return http.Response(
          '{"PlaySessionId":"play","MediaSources":[{"Id":"source","Container":"mp4","SupportsDirectPlay":true,"TranscodingUrl":"/Videos/movie/master.m3u8"}]}',
          200,
        );
      }
      return http.Response('', 204);
    });
    addTearDown(client.close);
    final factory = FakeVideoControllerFactory(failures: 1);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PlaybackScreen(
          api: JellyfinApi(client, deviceId: 'device'),
          session: session,
          item: movie,
          startAt: const Duration(seconds: 15),
          controllerFactory: factory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(factory.controllers, hasLength(2));
    expect(factory.controllers.last.uri.path, '/Videos/movie/master.m3u8');
    expect(find.text('Transcoding'), findsOneWidget);
    expect(
      factory.controllers.last.value.position,
      const Duration(seconds: 15),
    );
    expect(factory.controllers.last.value.playing, isTrue);
    final backButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('playback-back-button')),
    );
    expect(backButton.focusNode?.hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('play-pause-button')));
    await tester.pump();
    expect(factory.controllers.last.value.playing, isFalse);
    expect(
      requests.any(
        (request) => request.url.path == '/Sessions/Playing/Progress',
      ),
      isTrue,
    );
  });

  testWidgets('cycles WebVTT subtitles and renders the active caption', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        return http.Response(
          '{"PlaySessionId":"play","MediaSources":[{"Id":"source","Container":"mkv","SupportsDirectPlay":false,"TranscodingUrl":"/Videos/movie/master.m3u8","MediaStreams":[{"Index":3,"Type":"Subtitle","Codec":"srt","DisplayTitle":"English","IsDefault":true}]}]}',
          200,
        );
      }
      if (request.url.path.endsWith('/Stream.vtt')) {
        return http.Response('WEBVTT\n\n00:00.000 --> 00:02.000\nHello', 200);
      }
      return http.Response('', 204);
    });
    addTearDown(client.close);
    final factory = FakeVideoControllerFactory();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: PlaybackScreen(
          api: JellyfinApi(client, deviceId: 'device'),
          session: session,
          item: movie,
          startAt: Duration.zero,
          controllerFactory: factory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subtitles off'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('subtitle-button')));
    await tester.pumpAndSettle();

    expect(factory.controllers, hasLength(2));
    expect(await factory.controllers.last.subtitleVtt, contains('WEBVTT'));
    expect(find.text('English'), findsOneWidget);
    factory.controllers.last.setCaption('Hello');
    await tester.pump();
    expect(find.byKey(const ValueKey('playback-caption')), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('fits playback controls on a phone-sized surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/PlaybackInfo')) {
        return http.Response(
          '{"PlaySessionId":"play","MediaSources":[{"Id":"source","Container":"mp4","SupportsDirectPlay":true}]}',
          200,
        );
      }
      return http.Response('', 204);
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: PlaybackScreen(
          api: JellyfinApi(client, deviceId: 'device'),
          session: session,
          item: movie,
          startAt: Duration.zero,
          controllerFactory: FakeVideoControllerFactory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('play-pause-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class FakeVideoControllerFactory implements SoupVideoControllerFactory {
  FakeVideoControllerFactory({this.failures = 0});

  int failures;
  final controllers = <FakeVideoController>[];

  @override
  SoupVideoController create(Uri uri, {Future<String>? subtitleVtt}) {
    final controller = FakeVideoController(
      uri,
      subtitleVtt: subtitleVtt,
      failInitialization: failures-- > 0,
    );
    controllers.add(controller);
    return controller;
  }
}

class FakeVideoController extends ChangeNotifier
    implements SoupVideoController {
  FakeVideoController(
    this.uri, {
    required this.subtitleVtt,
    required this.failInitialization,
  });

  final Uri uri;
  final Future<String>? subtitleVtt;
  final bool failInitialization;
  SoupVideoValue _value = const SoupVideoValue();

  @override
  SoupVideoValue get value => _value;

  @override
  Future<void> initialize() async {
    if (failInitialization) throw StateError('direct playback failed');
    _value = const SoupVideoValue(
      initialized: true,
      duration: Duration(minutes: 90),
    );
    notifyListeners();
  }

  @override
  Future<void> play() async {
    _copy(playing: true);
  }

  @override
  Future<void> pause() async {
    _copy(playing: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _copy(position: position);
  }

  void setCaption(String caption) => _copy(caption: caption);

  void _copy({bool? playing, Duration? position, String? caption}) {
    _value = SoupVideoValue(
      initialized: _value.initialized,
      playing: playing ?? _value.playing,
      buffering: _value.buffering,
      position: position ?? _value.position,
      duration: _value.duration,
      aspectRatio: _value.aspectRatio,
      caption: caption ?? _value.caption,
      error: _value.error,
    );
    notifyListeners();
  }

  @override
  Widget buildView() => const ColoredBox(
    key: ValueKey('fake-video-surface'),
    color: Colors.blueGrey,
  );

  @override
  Future<void> close() async {
    dispose();
  }
}
