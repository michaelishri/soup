import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';

void main() {
  test('normalises a server URL with a Jellyfin base path', () {
    expect(
      JellyfinApi.parseServerUrl('media.example/jellyfin').toString(),
      'http://media.example/jellyfin/',
    );
  });

  test(
    'uses the current MediaBrowser header and typed 10.11 response',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"ServerName":"Home","Version":"10.11.3","Id":"server"}',
          200,
        );
      });
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'device-id');

      final info = await api.getPublicSystemInfo(
        Uri.parse('https://media.example/jellyfin/'),
      );

      expect(captured.url.path, '/jellyfin/System/Info/Public');
      expect(captured.headers['authorization'], contains('Client="Soup"'));
      expect(
        captured.headers['authorization'],
        contains('DeviceId="device-id"'),
      );
      expect(info.name, 'Home');
      expect(info.supportsSoup, isTrue);
    },
  );

  test(
    'authenticates with the 10.11 endpoint and returns a typed session',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          '{"AccessToken":"secret-token","ServerId":"server","User":{"Id":"user","Name":"Alex"}}',
          200,
        );
      });
      addTearDown(client.close);
      final api = JellyfinApi(client, deviceId: 'device-id');

      final session = await api.authenticate(
        serverUrl: Uri.parse('http://jellyfin:8096/'),
        username: 'Alex',
        password: 'password',
      );

      expect(captured.url.path, '/Users/AuthenticateByName');
      expect(jsonDecode(captured.body), {'Username': 'Alex', 'Pw': 'password'});
      expect(session.accessToken, 'secret-token');
      expect(session.userName, 'Alex');
    },
  );

  test('rejects a Jellyfin server older than 10.11', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"ServerName":"Old","Version":"10.10.7","Id":"server"}',
        200,
      ),
    );
    addTearDown(client.close);

    expect(
      () => JellyfinApi(
        client,
        deviceId: 'device',
      ).getPublicSystemInfo(Uri.parse('http://jellyfin/')),
      throwsA(isA<JellyfinApiException>()),
    );
  });

  test('loads authenticated home rows through the session client', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/Views')) {
        return http.Response(
          '{"Items":[{"Id":"library","Name":"Movies","Type":"CollectionFolder","CollectionType":"movies"}]}',
          200,
        );
      }
      if (request.url.path.endsWith('/Items/Resume')) {
        return http.Response(
          '{"Items":[{"Id":"resume","Name":"Film","Type":"Movie","UserData":{"PlaybackPositionTicks":120,"PlayedPercentage":25}}]}',
          200,
        );
      }
      if (request.url.queryParameters['IncludeItemTypes'] == 'Movie') {
        return http.Response(
          '[{"Id":"movie","Name":"Recent Movie","Type":"Movie"}]',
          200,
        );
      }
      if (request.url.queryParameters['IncludeItemTypes'] == 'Episode') {
        return http.Response(
          '[{"Id":"series","Name":"Recent Series","Type":"Series"}]',
          200,
        );
      }
      return http.Response(
        '[{"Id":"latest","Name":"Episode","Type":"Episode","SeriesName":"Show"}]',
        200,
      );
    });
    addTearDown(client.close);
    final api = JellyfinApi(client, deviceId: 'device');
    final session = JellyfinSession(
      serverUrl: Uri.parse('http://jellyfin/jellyfin/'),
      serverId: 'server',
      userId: 'user',
      userName: 'Alex',
      accessToken: 'secret-token',
    );

    final home = await api.getHome(session);

    expect(home.libraries.single.name, 'Movies');
    expect(home.resume.single.playedPercentage, 25);
    expect(home.latest.single.seriesName, 'Show');
    expect(home.recentlyAddedMovies!.single.name, 'Recent Movie');
    expect(home.recentlyAddedTv!.single.name, 'Recent Series');
    expect(requests, hasLength(5));
    expect(
      requests.every(
        (request) => request.headers['x-emby-token'] == 'secret-token',
      ),
      isTrue,
    );
    expect(requests.first.url.path, '/jellyfin/Users/user/Views');
    expect(requests[1].url.path, '/jellyfin/Users/user/Items/Resume');
    expect(requests[2].url.queryParameters['IncludeItemTypes'], isNull);
    expect(requests[3].url.queryParameters['IncludeItemTypes'], 'Movie');
    expect(requests[3].url.queryParameters['Limit'], '25');
    expect(requests[4].url.queryParameters['IncludeItemTypes'], 'Episode');
    expect(requests[4].url.queryParameters['Limit'], '25');
    final tvRequest = requests.singleWhere(
      (request) => request.url.queryParameters['IncludeItemTypes'] == 'Episode',
    );
    expect(tvRequest.url.queryParameters['GroupItems'], 'true');
  });

  test('loads artwork with authentication and sizing', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes([1, 2, 3], 200);
    });
    addTearDown(client.close);
    final api = JellyfinApi(client, deviceId: 'device');
    final session = JellyfinSession(
      serverUrl: Uri.parse('http://jellyfin/'),
      serverId: 'server',
      userId: 'user',
      userName: 'Alex',
      accessToken: 'token',
    );
    const item = JellyfinItem(
      id: 'item',
      name: 'Movie',
      type: 'Movie',
      primaryImageTag: 'tag',
    );

    final bytes = await api.getImage(session, item, maxWidth: 320);

    expect(bytes, [1, 2, 3]);
    expect(captured.url.path, '/Items/item/Images/Primary');
    expect(captured.url.queryParameters['maxWidth'], '320');
    expect(captured.headers['x-emby-token'], 'token');
  });

  test('loads details, library contents, seasons, and episodes', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/Users/user/Items/movie') {
        return http.Response(
          '{"Id":"movie","Name":"Movie","Type":"Movie","Overview":"Plot"}',
          200,
        );
      }
      if (request.url.path == '/Users/user/Items') {
        return http.Response(
          '{"Items":[{"Id":"series","Name":"Show","Type":"Series"}]}',
          200,
        );
      }
      if (request.url.path.endsWith('/Seasons')) {
        return http.Response(
          '{"Items":[{"Id":"season","Name":"Season 1","Type":"Season"}]}',
          200,
        );
      }
      return http.Response(
        '{"Items":[{"Id":"episode","Name":"Pilot","Type":"Episode","IndexNumber":1}]}',
        200,
      );
    });
    addTearDown(client.close);
    final api = JellyfinApi(client, deviceId: 'device');
    final session = JellyfinSession(
      serverUrl: Uri.parse('http://jellyfin/'),
      serverId: 'server',
      userId: 'user',
      userName: 'Alex',
      accessToken: 'token',
    );

    final movie = await api.getItem(session, 'movie');
    final contents = await api.getLibraryItems(session, 'library');
    final seasons = await api.getSeasons(session, 'series');
    final episodes = await api.getEpisodes(
      session,
      'series',
      seasonId: 'season',
    );

    expect(movie.overview, 'Plot');
    expect(contents.single.type, 'Series');
    expect(seasons.single.id, 'season');
    expect(episodes.single.indexNumber, 1);
    expect(paths, [
      '/Users/user/Items/movie',
      '/Users/user/Items',
      '/Shows/series/Seasons',
      '/Shows/series/Episodes',
    ]);
  });

  test('resolves direct play, transcode fallback, and text subtitles', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        '{"PlaySessionId":"play-session","MediaSources":[{"Id":"source","Container":"mp4","SupportsDirectPlay":true,"SupportsDirectStream":true,"TranscodingUrl":"/Videos/movie/master.m3u8?token=value","MediaStreams":[{"Index":2,"Type":"Subtitle","Codec":"subrip","DisplayTitle":"English","IsDefault":true}]}]}',
        200,
      );
    });
    addTearDown(client.close);
    final api = JellyfinApi(client, deviceId: 'device');
    final session = JellyfinSession(
      serverUrl: Uri.parse('http://jellyfin:8096/jellyfin/'),
      serverId: 'server',
      userId: 'user',
      userName: 'Alex',
      accessToken: 'token',
    );
    const movie = JellyfinItem(id: 'movie', name: 'Movie', type: 'Movie');

    final plan = await api.getPlaybackPlan(
      session,
      movie,
      startAt: const Duration(seconds: 12),
    );

    expect(captured.url.path, '/jellyfin/Items/movie/PlaybackInfo');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['StartTimeTicks'], 120000000);
    expect(body['DeviceProfile']['DirectPlayProfiles'], isNotEmpty);
    expect(body['DeviceProfile']['TranscodingProfiles'], isNotEmpty);
    expect(plan.directMethod, JellyfinPlayMethod.directPlay);
    expect(plan.directUri?.path, '/jellyfin/Videos/movie/stream.mp4');
    expect(plan.transcodeUri?.path, '/jellyfin/Videos/movie/master.m3u8');
    expect(plan.subtitles.single.label, 'English');
    expect(
      plan.subtitles.single.uri.path,
      '/jellyfin/Videos/movie/source/Subtitles/2/Stream.vtt',
    );
  });

  test('uses a transcode-only source and reports playback progress', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/PlaybackInfo')) {
        return http.Response(
          '{"PlaySessionId":"play","MediaSources":[{"Id":"source","Container":"mkv","SupportsDirectPlay":false,"SupportsDirectStream":false,"TranscodingUrl":"/Videos/movie/master.m3u8"}]}',
          200,
        );
      }
      return http.Response('', 204);
    });
    addTearDown(client.close);
    final api = JellyfinApi(client, deviceId: 'device');
    final session = JellyfinSession(
      serverUrl: Uri.parse('http://jellyfin/'),
      serverId: 'server',
      userId: 'user',
      userName: 'Alex',
      accessToken: 'token',
    );
    const movie = JellyfinItem(id: 'movie', name: 'Movie', type: 'Movie');

    final plan = await api.getPlaybackPlan(
      session,
      movie,
      startAt: Duration.zero,
    );
    await api.reportPlaybackStarted(
      session,
      plan,
      method: JellyfinPlayMethod.transcode,
      position: Duration.zero,
    );
    await api.reportPlaybackProgress(
      session,
      plan,
      method: JellyfinPlayMethod.transcode,
      position: const Duration(seconds: 42),
      paused: true,
    );
    await api.reportPlaybackStopped(
      session,
      plan,
      method: JellyfinPlayMethod.transcode,
      position: const Duration(seconds: 43),
    );

    expect(plan.directUri, isNull);
    expect(plan.transcodeUri, isNotNull);
    expect(requests.map((request) => request.url.path), [
      '/Items/movie/PlaybackInfo',
      '/Sessions/Playing',
      '/Sessions/Playing/Progress',
      '/Sessions/Playing/Stopped',
    ]);
    final progress = jsonDecode(requests[2].body) as Map<String, dynamic>;
    expect(progress['PositionTicks'], 420000000);
    expect(progress['IsPaused'], isTrue);
    expect(progress['PlayMethod'], 'Transcode');
  });
}
