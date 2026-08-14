# Soup — Jellyfin over Tailscale

Soup is a Jellyfin client with Tailscale integration. This integration means users don't need to have the separate Tailscale VPN client connected before starting the Jellyfin client.

## Prototype targets

- Android 12+ mobile and Android TV: Flutter/Dart in `apps/android`.
- Samsung QE65Q80TATXXU (Tizen 5.5): C#/NUI, tracked as a separate implementation.
- Embedded networking: Tailscale's C library through the FFI package in `packages/soup_tailscale`.

The Android UI depends only on the `TailscaleClient` contract. The production native adapter is not linked yet; the current adapter fails explicitly if connection is attempted.

## Android development

```sh
cd apps/android
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is written to `apps/android/build/app/outputs/flutter-apk/app-debug.apk`.

## Tailscale FFI package

```sh
cd packages/soup_tailscale
flutter analyze
flutter test
```

Upstream library: https://github.com/tailscale/libtailscale
