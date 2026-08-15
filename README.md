# Soup — Jellyfin over Tailscale

Soup is a Jellyfin client with Tailscale integration. This integration means users don't need to have the separate Tailscale VPN client connected before starting the Jellyfin client.

## Prototype targets

- Android 12+ mobile and Android TV: Flutter/Dart in `apps/android`.
- Samsung QE65Q80TATXXU (Tizen 5.5): C#/NUI, tracked as a separate implementation.
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
Tailscale path through an authenticated loopback playback bridge. TV setup
provides explicit clipboard actions for the auth key and server address, while
connection and sign-in errors remain pinned above the scrollable form so they
stay readable at constrained heights.

Secrets are handled deliberately:

- The Tailscale auth key is submitted once to the native node and is never
  persisted by Soup.
- The masked auth-key field has an explicit clipboard paste action for TV use;
  clipboard contents are not logged or persisted by Soup.
- The Jellyfin password is cleared immediately after submission and is never
  persisted.
- The Jellyfin access token and Soup device ID are stored with Android-backed
  secure storage; Android cloud backup is disabled for the app.
- Persistent Tailscale node state lives in the app support directory so a
  valid node can reconnect without another auth key.

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

To use the prototype, create a one-time, pre-authorized auth key in the
Tailscale admin console, enter it in Soup, then enter a Jellyfin 10.11+ URL
reachable from that tailnet (for example `http://jellyfin:8096`). Both HTTP and
HTTPS server URLs are supported; HTTPS uses normal certificate validation.

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
