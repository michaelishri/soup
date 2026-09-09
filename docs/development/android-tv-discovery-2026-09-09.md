# Jellyfin discovery — SOUP-97 / SOUP-98

Implementation branch: `feat/jellyfin-discovery-soup97`.

Onboarding offers verified Jellyfin server cards before manual address entry.
Local discovery runs without Tailscale; a connected embedded node adds visible
tailnet peers. Connecting a card rechecks its server ID before opening the
existing Quick Connect/password sign-in screen. Authentication and saved-session
storage follow the existing path. Restoring an authenticated session does not
start discovery.

## Network behavior

- Send Jellyfin's UDP discovery query on port 7359 using each active Android
  IPv4 interface's actual broadcast address. Repeat once after 500 ms.
- With Tailscale, query visible peers through LocalAPI and send directed IPv4
  UDP queries through the authenticated SOCKS5 UDP relay. Closing its control
  socket closes the association.
- Allow three seconds for UDP replies. Preserve advertised ports and base paths;
  also try the responder IP to repair localhost or unreachable advertised hosts.
- Probe known responders/peers on HTTP 8096 and HTTPS 8920, plus HTTPS 443 and
  8920 on peer MagicDNS names. IPv6 peers participate in HTTP fallback.
- Validate unauthenticated `System/Info/Public`, require matching advertised IDs,
  deduplicate by server ID, and prefer verified tailnet endpoints and HTTPS.
  Unsupported versions stay visible with an explanation and cannot be selected.
- Bound each search to 15 seconds, peer lookup to two seconds, each HTTP request
  to three seconds, eight concurrent requests, 128 peers and 512 candidates.
  Capped/interrupted searches expose partial results. Online peers go first.
- Cancellation closes LAN sockets, UDP associations and HTTP transports,
  including stalled SOCKS and TLS handshakes. Discovery's private HTTP CONNECT
  bridge leaves TLS certificate verification to `dart:io`; it does not weaken
  certificate checks or alter the authenticated client factory.

There is no arbitrary LAN/subnet scan or guessed reverse-proxy path. A server
on an unadvertised custom port/path, behind a subnet router, or excluded by
tailnet access rules can require manual entry. HTTPS discovery requires a valid,
trusted certificate for the address being tested.

## Automated coverage

`task qa` passes formatting, all three analyzers and 292 tests (256 app,
12 Tailscale transport and 24 generated API tests).

The discovery service, socket and onboarding tests cover UDP framing and real
SOCKS round trips, malformed responses, ID mismatch, custom paths, duplicate
servers, endpoint preference, old versions, IPv6, empty results, peer limits,
concurrency, deadlines, stalled handshakes, cancellation and certificate rejection.

View-model/widget tests cover late results without focus theft, background/resume,
transport replacement, selected-card restoration, long lists in both motion
modes, manual draft/protocol preservation, field-to-Next navigation, password
authentication/persistence, and no discovery for saved direct or Tailscale
sessions. Phone widgets are checked at enlarged text size.

The README/gallery include new phone and TV discovery screenshots rendered from
production widgets with fictional server data.

## Guest Room TV checks

Chromecast/sabrina, Android 14, 1920×1080, density 320 (960×540 logical pixels).
Fresh onboarding uses the isolated package
`dev.michaelishri.soup.discoveryreview`, built from the normal entrypoint using:

```sh
ORG_GRADLE_PROJECT_soupApplicationId=dev.michaelishri.soup.discoveryreview \
  flutter build apk --release --no-pub
```

The Gradle override defaults to `dev.michaelishri.soup` when omitted. Separate
application storage preserves the user's production account and embedded node.

Verified against a controlled LAN fixture:

- A real Chromecast UDP broadcast receives the fixture advertisement. Its
  deliberately incorrect localhost host is repaired to the responder IP while
  retaining custom port 18096 and the `/jellyfin` base path.
- Remote traversal reaches the server card, Search again, manual entry and Back.
  Down from the manual address reaches Next; Up returns to the field.
- The native keyboard owns arrows (highlight moves between keys). A complete
  HTTP address updates the protocol selector, and closing the editor preserves
  the draft. Hardware Back returns to the discovered server card.
- With the fixture stopped, the empty state offers manual entry and Retry.
  Retrying returns focus to manual entry and completes without stale cards.
- Selecting the server opens Quick Connect. Fixture approval proceeds through
  appearance selection to Home. Force-stop/reopen restores the fixture session
  without asking for onboarding again.

These are real device/network/input checks with a fictional Jellyfin endpoint,
not evidence of real media playback. Directed tailnet discovery and the proxy
transport have automated socket/service coverage; fresh enrollment and discovery
through the Chromecast's embedded Tailscale node remain unverified in this run.
Physical phone testing also remains unverified. Existing production enrollment
is not copied into the isolated test package.

Local device screenshots, XML and fixture logs are kept under
`/tmp/soup98-discovery`; only fictional widget gallery images are committed.

The final production-package release APK builds successfully. SHA-256:
`65acff3765220ad4eb7a435eeff2f5f6cfc04939fe5bc5e9bc9bd283f1f46f3d`.
It was installed with `adb install -r`; the installed checksum matches. The
existing signed-in homepage returned after update and after force-stop/reopen,
without onboarding. Both captured process logs contain no fatal or unhandled
exception entries. The temporary review app was uninstalled and the LAN fixture
stopped after testing.
