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
layouts.

Secrets are handled deliberately:

- The Tailscale auth key is submitted once to the native node and is never
  persisted by Soup.
- The Jellyfin password is cleared immediately after submission and is never
  persisted.
- The Jellyfin access token and Soup device ID are stored with Android-backed
  secure storage; Android cloud backup is disabled for the app.
- Persistent Tailscale node state lives in the app support directory so a
  valid node can reconnect without another auth key.

## Android development

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
Jellyfin's published 10.11.1 OpenAPI snapshot and currently includes only the
public system information and username authentication operations.

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
