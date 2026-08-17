# Soup — Jellyfin over Tailscale

Soup is a Jellyfin client with Tailscale integration. This integration means users don't need to have the separate Tailscale VPN client connected before starting the Jellyfin client.

## Supported target

- Android 12+ mobile and Android TV: Flutter/Dart in `apps/android`.
- Embedded networking: Tailscale's C library through the FFI package in `packages/soup_tailscale`.

The Android prototype includes the complete setup path: an embedded Tailscale
node, an authenticated app-local SOCKS5 proxy, Jellyfin 10.11 discovery, and
username/password sign-in. The UI depends on a substitutable `TailscaleClient`
boundary and adapts between touch-sized phone layouts and D-pad-friendly TV
layouts. After sign-in, Soup restores the secure session and loads My Media,
Continue Watching, and Latest Media, including artwork, through the same
app-local Tailscale proxy. Libraries open into browsable grids, and item details
show artwork, metadata, overview, Play/Resume, plus season and episode navigation
for series. Playback negotiates direct play with Jellyfin and falls back to HLS
transcoding when required, with resume seeking, transport controls, progress
reporting, and selectable WebVTT subtitles. Media remains on the embedded
Tailscale path through an authenticated loopback playback bridge. TV setup uses
a Tailscale authorization QR code that can be scanned with a phone, with direct
browser opening on Android and an advanced one-time auth-key fallback. Server
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
  code or opens in the device browser.
- Advanced auth keys are submitted once to the native node and are never
  persisted. The masked field and clipboard contents are not logged.
- The Jellyfin password is cleared immediately after submission and is never
  persisted.
- The Jellyfin access token and Soup device ID are stored with Android-backed
  secure storage; Android cloud backup is disabled for the app.
- Persistent Tailscale node state lives in the app support directory so a valid
  node can reconnect without another browser login or auth key.

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

To use the prototype, choose **Sign in with Tailscale**, scan the QR code with a
phone, and finish authorization in Tailscale. If the tailnet requires device
approval, Soup waits until an administrator approves the TV. Auth keys remain
available under **Advanced options** for pre-approved or tagged-device setups.
After registration, enter a Jellyfin 10.11+ URL reachable from that tailnet
(for example `http://jellyfin:8096`). Both HTTP and HTTPS server URLs are
supported; HTTPS uses normal certificate validation.

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
