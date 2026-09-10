import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:soup/src/data/jellyfin/jellyfin_api.dart';
import 'package:soup/src/data/soup/soup_session_store.dart';
import 'package:soup/src/features/soup_auth/soup_device_link_view_model.dart';
import 'package:soup_identity/soup_identity.dart';
import 'package:soup_tailscale/soup_tailscale.dart';

import 'support/connectivity_fakes.dart';

void main() {
  SoupDeviceLinkViewModel buildModel({
    required SoupIdentityClient client,
    SoupSessionStore? soupStore,
    MemorySessionStore? jellyfinStore,
    TailscaleClient? tailscale,
    bool connectTransportGrants = true,
    bool performJellyfinExchange = true,
    Future<JellyfinApi> Function()? jellyfinApiProvider,
  }) {
    final jfStore = jellyfinStore ?? MemorySessionStore();
    return SoupDeviceLinkViewModel(
      client: client,
      sessionStore: soupStore ?? MemorySoupSessionStore(),
      jellyfinSessionStore: jfStore,
      jellyfinApiProvider:
          jellyfinApiProvider ??
          () async => JellyfinApi(
            MockClient((request) async {
              if (request.url.path.endsWith('/SoupAuth/Exchange')) {
                return http.Response(
                  '{"AccessToken":"soup-token","ServerId":"jf-1","User":{"Id":"u1","Name":"Guest"}}',
                  200,
                );
              }
              if (request.url.path.contains('/Users/')) {
                return http.Response(
                  '{"Id":"u1","Name":"Guest"}',
                  200,
                );
              }
              return http.Response('{}', 404);
            }),
            deviceId: 'soup-device',
          ),
      tailscaleClient: tailscale,
      connectTransportGrants: connectTransportGrants,
      performJellyfinExchange: performJellyfinExchange,
    );
  }

  test('device-link poll stores session, auto-selects server, exchanges', () async {
    final client = MockSoupIdentityClient(pollsUntilApproved: 1);
    final soupStore = MemorySoupSessionStore();
    final jellyfinStore = MemorySessionStore();
    final model = buildModel(
      client: client,
      soupStore: soupStore,
      jellyfinStore: jellyfinStore,
      performJellyfinExchange: true,
    );
    addTearDown(model.dispose);

    await model.initialize();
    expect(model.session, isNull);

    await model.startDeviceLink();
    await pumpUntil(
      () => model.phase == SoupDeviceLinkPhase.ready,
      timeout: const Duration(seconds: 2),
    );

    expect(model.session?.accessToken, 'mock-access');
    expect(model.session?.lastServerId, 'home-jf');
    expect(soupStore.session?.refreshToken, 'mock-refresh');
    expect(model.roster?.servers.single.id, 'home-jf');
    expect(model.selectedServer?.id, 'home-jf');
    expect(model.jellyfinSession?.accessToken, 'soup-token');
    expect(jellyfinStore.session?.accessToken, 'soup-token');
    expect(model.transportConnected, isFalse);
  });

  test('roster transport grant calls connectWithAuthKey then exchanges', () async {
    final grant = TransportGrant(
      id: '11111111-1111-1111-1111-111111111111',
      grantType: 'tailscale_auth_key',
      expiresAt: DateTime.utc(2026, 9, 10, 12),
      material: 'tskey-auth-wave2c',
    );
    final client = MockSoupIdentityClient(
      pollsUntilApproved: 1,
      servers: [
        RosterServer(
          id: 'home-jf',
          name: 'Home',
          audience: 'jellyfin:home-jf',
          magicDns: 'jellyfin.tailnet.ts.net',
          transportGrant: grant,
        ),
      ],
    );
    final tailscale = FakeTailscaleClient();
    addTearDown(tailscale.dispose);
    final model = buildModel(
      client: client,
      tailscale: tailscale,
      connectTransportGrants: true,
    );
    addTearDown(model.dispose);

    await model.initialize();
    await model.startDeviceLink();
    await pumpUntil(
      () => model.phase == SoupDeviceLinkPhase.ready,
      timeout: const Duration(seconds: 2),
    );

    expect(tailscale.authKeyConnects, 1);
    expect(tailscale.lastAuthKey, 'tskey-auth-wave2c');
    expect(model.transportConnected, isTrue);
    expect(model.transportServerId, 'home-jf');
    expect(model.transportError, isNull);
    expect(model.jellyfinSession?.accessToken, 'soup-token');
  });

  test('transport grant connect is skipped when feature flag is off', () async {
    final client = MockSoupIdentityClient(
      pollsUntilApproved: 1,
      servers: [
        RosterServer(
          id: 'home-jf',
          name: 'Home',
          audience: 'jellyfin:home-jf',
          magicDns: 'jellyfin.tailnet.ts.net',
          transportGrant: TransportGrant(
            id: '11111111-1111-1111-1111-111111111111',
            grantType: 'tailscale_auth_key',
            expiresAt: DateTime.utc(2026, 9, 10, 12),
            material: 'tskey-auth-skipped',
          ),
        ),
      ],
    );
    final tailscale = FakeTailscaleClient();
    addTearDown(tailscale.dispose);
    final model = buildModel(
      client: client,
      tailscale: tailscale,
      connectTransportGrants: false,
    );
    addTearDown(model.dispose);

    await model.initialize();
    await model.startDeviceLink();
    await pumpUntil(
      () => model.phase == SoupDeviceLinkPhase.ready,
      timeout: const Duration(seconds: 2),
    );

    expect(tailscale.authKeyConnects, 0);
    expect(model.transportConnected, isFalse);
    expect(model.jellyfinSession?.accessToken, 'soup-token');
  });

  test('refresh rotates tokens through the client', () async {
    final client = MockSoupIdentityClient(pollsUntilApproved: 1);
    final store = MemorySoupSessionStore(
      SoupSession.fromTokens(
        const SoupSessionTokens(
          accessToken: 'mock-access',
          refreshToken: 'mock-refresh',
          expiresIn: 900,
          tokenType: 'Bearer',
          email: 'dev@example.com',
        ),
        lastServerId: 'home-jf',
      ),
    );
    final model = buildModel(client: client, soupStore: store);
    addTearDown(model.dispose);

    await model.initialize();
    await model.refreshAndReloadRoster();
    expect(model.phase, SoupDeviceLinkPhase.ready);
    expect(model.session?.accessToken, startsWith('mock-access-'));
    expect(model.session?.refreshToken, startsWith('mock-refresh-'));
    expect(store.session?.lastServerId, 'home-jf');
  });

  test('silent re-exchange replaces expired Jellyfin token', () async {
    final client = MockSoupIdentityClient();
    final soupStore = MemorySoupSessionStore(
      SoupSession.fromTokens(
        const SoupSessionTokens(
          accessToken: 'mock-access',
          refreshToken: 'mock-refresh',
          expiresIn: 900,
          tokenType: 'Bearer',
          email: 'dev@example.com',
        ),
        lastServerId: 'home-jf',
      ),
    );
    final jellyfinStore = MemorySessionStore(
      JellyfinSession(
        serverUrl: Uri.parse('http://jellyfin.tailnet.ts.net/'),
        serverId: 'old',
        userId: 'u1',
        userName: 'Guest',
        accessToken: 'expired',
      ),
    );
    var probes = 0;
    final model = buildModel(
      client: client,
      soupStore: soupStore,
      jellyfinStore: jellyfinStore,
      jellyfinApiProvider: () async => JellyfinApi(
        MockClient((request) async {
          if (request.url.path.endsWith('/SoupAuth/Exchange')) {
            return http.Response(
              '{"AccessToken":"fresh-token","ServerId":"jf-1","User":{"Id":"u1","Name":"Guest"}}',
              200,
            );
          }
          if (request.url.path.contains('/Users/')) {
            probes++;
            if (probes == 1) {
              return http.Response('Unauthorized', 401);
            }
            return http.Response('{"Id":"u1","Name":"Guest"}', 200);
          }
          return http.Response('{}', 404);
        }),
        deviceId: 'soup-device',
      ),
    );
    addTearDown(model.dispose);

    await model.initialize();
    expect(model.jellyfinSession?.accessToken, 'fresh-token');
    expect(jellyfinStore.session?.accessToken, 'fresh-token');
    expect(model.phase, SoupDeviceLinkPhase.ready);
  });
}

class MemorySoupSessionStore implements SoupSessionStore {
  MemorySoupSessionStore([this.session]);

  SoupSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<SoupSession?> read() async => session;

  @override
  Future<void> write(SoupSession value) async => session = value;
}

Future<void> pumpUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) {
      fail('Condition not met before timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
