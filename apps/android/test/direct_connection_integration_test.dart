import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/jellyfin/jellyfin_client_factory.dart';
import 'package:soup/src/data/playback/playback_bridge.dart';
import 'package:soup/src/data/session/connection_preferences_store.dart';
import 'package:soup/src/features/connectivity/connectivity_view_model.dart';

import 'support/connectivity_fakes.dart';

void main() {
  test(
    'direct onboarding, home, artwork and playback share the selected transport',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      final tokens = <String?>[];
      final subscription = server.listen((request) async {
        requests.add(request.uri.path);
        tokens.add(request.headers.value('x-emby-token'));
        final response = request.response;
        final path = request.uri.path;
        if (path.endsWith('/System/Info/Public')) {
          response.write(
            '{"ServerName":"Living Room","Version":"10.11.2","Id":"server-1"}',
          );
        } else if (path.endsWith('/Users/AuthenticateByName')) {
          response.write(
            '{"AccessToken":"token","ServerId":"server-1","User":{"Id":"user-1","Name":"Alex"}}',
          );
        } else if (path.contains('/Images/')) {
          response.headers.contentType = ContentType('image', 'png');
          response.add([137, 80, 78, 71]);
        } else if (path.endsWith('.mp4')) {
          response.statusCode = HttpStatus.partialContent;
          response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-2/3');
          response.add([1, 2, 3]);
        } else {
          response.write(path.endsWith('/Latest') ? '[]' : '{"Items":[]}');
        }
        await response.close();
      });
      addTearDown(() async {
        await server.close(force: true);
        await subscription.cancel();
      });
      final tailscale = FakeTailscaleClient();
      final model = ConnectivityViewModel(
        tailscale,
        jellyfinClientFactory: const DefaultJellyfinClientFactory(),
        sessionStore: MemorySessionStore(),
        connectionStore: MemoryConnectionPreferencesStore(),
      );
      addTearDown(tailscale.dispose);
      addTearDown(model.dispose);
      await model.initialize();
      await model.continueConnection();
      await model.checkServer('http://127.0.0.1:${server.port}');
      await model.signIn(username: 'Alex', password: 'test-password');
      expect(model.phase, SetupPhase.ready);
      final api = await model.authenticatedApi();
      final session = model.session!;
      expect((await api.getHome(session)).libraries, isEmpty);
      expect(
        await api.getImage(
          session,
          const JellyfinItem(
            id: 'movie',
            name: 'Movie',
            type: 'Movie',
            primaryImageTag: 'image-1',
          ),
        ),
        [137, 80, 78, 71],
      );
      final bridge = PlaybackBridge(
        api.transport,
        session,
        api.authenticatedHeaders(session),
      );
      await bridge.start();
      addTearDown(bridge.close);
      final player = http.Client();
      addTearDown(player.close);
      final response = await player.get(
        bridge.localUriFor(
          session.serverUrl.resolve('Videos/movie/stream.mp4'),
        ),
        headers: {'Range': 'bytes=0-2'},
      );
      expect(response.statusCode, HttpStatus.partialContent);
      expect(response.bodyBytes, [1, 2, 3]);
      expect(tokens.skip(2), everyElement('token'));
      expect(requests, contains('/Users/user-1/Views'));
      expect(requests, contains('/Items/movie/Images/Primary'));
      expect(requests, contains('/Videos/movie/stream.mp4'));
      expect(tailscale.restores, 0);
      expect(tailscale.interactiveConnects, 0);
    },
  );
}
