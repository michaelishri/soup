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

The current prototype includes the complete connection and sign-in flow plus an
authenticated home screen for libraries, Continue Watching, and Latest Media.
JSON and artwork are fetched through the embedded Tailscale connection, and the
TV interface has explicit, ordered D-pad traversal. Library folders open into
poster grids; movie and episode details expose exact Play/Resume positions, and
series provide season and episode navigation.
