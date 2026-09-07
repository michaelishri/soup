# Soup — Jellyfin, with optional Tailscale

Soup is a Jellyfin client that connects directly to your server or through an
optional embedded Tailscale connection. Embedded Tailscale does not require a
separate VPN app.

## Supported target

- Android 12+ mobile and Android TV: Flutter/Dart in `apps/android`.
- Embedded networking: Tailscale's C library through the FFI package in `packages/soup_tailscale`.

The Android prototype includes the complete setup path: optional embedded Tailscale,
direct or authenticated app-local SOCKS5 networking, Jellyfin 10.11 discovery, and
username/password sign-in. The UI depends on a substitutable `TailscaleClient`
boundary and adapts between touch-sized phone layouts and D-pad-friendly TV
layouts. After sign-in, Soup restores the secure session and loads My Media,
Continue Watching, and Latest Media, including artwork, through the same
selected connection. Libraries open into browsable grids, and item details
show artwork, metadata, overview, Play/Resume, plus season and episode navigation
for series. Playback negotiates direct play with Jellyfin and falls back to HLS
transcoding when required, with resume seeking, transport controls, progress
reporting, and selectable WebVTT subtitles. The authenticated loopback playback
bridge uses the same selected connection as the rest of the app. Tailscale setup
uses an authorization QR code scanned with another device on both mobile and TV. Server
address paste remains available, while connection and sign-in errors stay
pinned above the scrollable form so they remain readable at constrained heights.

## Customisable interface

After the first successful Jellyfin sign-in, Soup asks how the authenticated
experience should look. The choice is stored for the device and can be changed
later from Settings without reconnecting or changing accounts.

- **Fruity** is a spacious, artwork-led interface inspired by Apple TV. On TV,
  its top navigation is Home, TV, Movies, and Settings; phones use the same
  destinations in compact bottom navigation.
- **Blockbuster** is a denser, browse-led interface inspired by Netflix. It uses
  a billboard home and an expanding navigation rail on Android TV.
- Both layouts support Soup, Ocean, Grove, and Mono palettes, each with an
  explicit light and dark version.

Onboarding and sign-in always use Soup's fixed setup design. Appearance choices
apply only after authentication. The current customisation boundary is layout,
palette, and brightness; custom row ordering, typography, density, and a freeform
layout builder are intentionally deferred.

Secrets are handled deliberately:

- Interactive registration sends no Tailscale credential through Soup. The
  embedded node supplies an HTTPS authorization URL that Soup renders as a QR
  code. Browser-launch and auth-key options are not offered in Soup onboarding.
- The Jellyfin password is cleared immediately after submission or backward navigation and is never
  persisted.
- The Jellyfin access token and Soup device ID are stored with Android-backed
  secure storage; Android cloud backup is disabled for the app.
- Persistent Tailscale node state lives in the app support directory so a valid
  node can reconnect without another sign-in. The connection choice is stored
  separately; direct sessions never start the embedded Tailscale node.

## Android development

Development workflows are collected in the root `Taskfile.yml`. Install
[Task](https://taskfile.dev/), then discover every available command with:

```sh
task --list
```

The common workflow is:

```sh
task setup       # Initialize libtailscale and install package dependencies.
task qa          # Check formatting, analyze, and run every test suite.
task build       # Build the debug APK.
task run         # Run on the selected Flutter device.
```

Use `task devices` to find a device ID, then pass it as a Task variable when
needed, for example `task run DEVICE=emulator-5554`. Android TV image setup,
keyboard configuration, boot, wait, and shutdown commands are grouped under
`emulator:tv:*`; the defaults create the API 34 ARM64
`Soup_Android_TV_API_34` AVD. This development image boots without Google TV
account onboarding, and the Taskfile explicitly enables host keyboard input.
Run `task --list` for descriptions of package-specific QA, release builds, API
generation, coverage, logging, and cleanup commands.

The equivalent commands without Task are:

```sh
git submodule update --init --recursive
cd apps/android
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to `apps/android/build/app/outputs/flutter-apk/app-debug.apk`.
The build hook compiles the pinned upstream `libtailscale` source with Go and
the Android NDK for every ABI requested by Flutter. Android 12 / API 31 is the
minimum supported version.

On first launch, **Use Tailscale** is off. Select **Next** to enter a Jellyfin
10.11+ address reachable from your device, or enable Tailscale to reveal its
sign-in QR code. Scan with another device and finish authorization. If device
approval is required, Soup waits for the administrator; after connection,
select **Next**. You can turn Tailscale off at any point in that connection step.

Soup checks the server before asking for your username and password. **Back**
lets you edit the server or connection choice. Both HTTP and HTTPS URLs are
supported, with normal certificate validation and no automatic fallback from
Tailscale to direct networking. Existing saved accounts remain on Tailscale
until you explicitly change the connection choice.

The warm, centered onboarding panel supports touch, D-pad focus, reduced motion,
and constrained TV heights. [Review screenshots and regeneration instructions](docs/screenshots/onboarding/README.md)
are available for the actual Flutter widgets rendered with demonstration data.

## Jellyfin API generation

The narrow Dart API used by the prototype is generated from
`tool/openapi/jellyfin-10.11-prototype.yaml`. That contract is derived from
Jellyfin's published 10.11.1 OpenAPI snapshot. Generated operations currently
cover public system information and username authentication; the handwritten
facade contains the authenticated library queries and stable app models.

```sh
./tool/generate_jellyfin_api.sh
```

The generated package is committed at `packages/jellyfin_api`. The handwritten
application facade owns authorization headers, version checks, timeouts, and
mapping generated wire models into stable app models.

## Tailscale FFI package

```sh
cd packages/soup_tailscale
flutter analyze
flutter test
```

Upstream library: https://github.com/tailscale/libtailscale

Soup pins the upstream source as a Git submodule. On Android, a small bridge
supplies network-interface information using Java's `NetworkInterface` API,
matching the approach used by the official Tailscale Android client. This is
required because Android sandboxes direct netlink interface discovery.
