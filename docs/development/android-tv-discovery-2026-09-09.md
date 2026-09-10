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

## Merge review follow-up

The user installed the published `b269302` APK on a phone, reported that it
worked well, and approved merging. Detailed phone scenarios were not recorded.

Final review reproduced a race in which discovery completed or failed while
Next was writing connection preferences. The busy guard discarded the final
event and left the server screen searching indefinitely. Current-generation
events are now accepted during that write; starting a new search remains
busy-aware and lifecycle/generation checks still discard stale events. Both
regression cases failed before the fix and cover terminal state, retained server
cards and Retry afterward. This follow-up is newer than the APK identified above.

After this fix, `task qa` passes all analyzers and 294 tests (258 app, 12
Tailscale transport, 24 generated API).

## Emulator networking (testing only)

Default Android emulator networking is a NAT segment (`10.0.2.15/24`). Soup LAN
discovery only UDP-broadcasts Jellyfin's query on port 7359 to each interface's
broadcast address. Packets to `10.0.2.255` never reach a real home LAN, so the
emulator will not list a Jellyfin on another LAN device even when that server
is healthy.

**Workaround — manual entry (preferred for emulator QA):**

1. Leave Tailscale off.
2. Choose **Enter address manually**.
3. Enter `http://<jellyfin-lan-ip>:8096` (or HTTPS / port `8920` as appropriate).

Outbound TCP from the emulator to host-LAN IPs often still works under NAT even
though broadcast discovery fails. Confirm with
`adb shell ping -c 1 <jellyfin-lan-ip>` or by selecting Next after manual entry.

**If TCP to the LAN IP fails**, forward through the host (testing only), then
point Soup at the emulator's host alias:

```sh
# example on the PC: listen on 18096 and proxy to the LAN Jellyfin
# socat TCP-LISTEN:18096,fork,reuseaddr TCP:<jellyfin-lan-ip>:8096
```

In Soup: `http://10.0.2.2:18096`. `adb reverse` only maps emulator→host
loopback, so it does not replace a forward to another LAN host.

For real UDP discovery, use a physical device on the same LAN, or a connected
Tailscale session once embedded Tailscale is enrolled (directed peer discovery).
Do not change production discovery to scan LAN ranges or seed `10.0.2.2`.
