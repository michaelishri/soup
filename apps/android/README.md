# Soup for Android

Flutter prototype for Android mobile and Android TV. It embeds a Tailscale node
inside the application and routes Jellyfin discovery and login over the node's
authenticated loopback SOCKS5 proxy.

## Run locally

From the repository root, initialize the pinned native source first:

```sh
git submodule update --init --recursive
cd apps/android
flutter pub get
flutter test
flutter run
```

The target device must run Android 12 (API 31) or newer. The same application
supports touch input and Android TV D-pad focus traversal.

The current prototype stops at a verified Tailscale connection and Jellyfin
login; library browsing and playback are deliberately outside this milestone.
