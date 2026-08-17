# Soup for Android

Flutter prototype for Android mobile and Android TV. It embeds a Tailscale node
inside the application and routes Jellyfin discovery and login over the node's
authenticated loopback SOCKS5 proxy.

## Tailscale registration

Soup normally registers its embedded node through Tailscale's interactive web
login. On Android TV it displays the one-time HTTPS authorization URL as a QR
code for a phone to scan; Android devices can also open the same URL in an
installed browser. Soup follows the connection automatically and shows a
separate waiting state when the tailnet requires administrator approval.

For pre-approved or tagged-device environments, **Advanced options** retains a
masked one-time auth-key field and clipboard paste action. The field is cleared
before submission, and Soup never persists or logs the key. Successful node
state remains in the app's private support directory for future reconnects.

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
series provide season and episode navigation. The player negotiates direct play
or HLS transcoding, routes media through the embedded Tailscale connection,
reports playback progress, and supports selectable subtitles.
