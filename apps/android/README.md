# Soup for Android

Flutter client for Android 12+ mobile and Android TV, with direct Jellyfin
networking and an optional embedded Tailscale node.

## Onboarding

The centered, warm charcoal/orange panel guides users through connection,
server validation, and Jellyfin sign-in. On first launch **Use Tailscale** is
off; **Next** immediately opens server setup without starting Tailscale.

Enabling Tailscale on phones and tablets reveals **Authorise device on Tailscale**.
Tap it to sign in in a full-screen Android Custom Tab, sharing your browser’s
saved sign-in. Soup closes the tab when Tailscale connects or needs administrator
approval. Back/close lets you return early and reopen the same link. If Custom Tabs
are unavailable or fail to open, Soup uses your external browser and asks you to
return manually. Android TV displays a QR code for sign-in on another device.
Saved accounts that need to sign in again use the same device-appropriate flow.

Soup shows preparation, sign-in, administrator approval, and connection success
in place. **Next** becomes available when connected and still requires a tap.
Reauthorising an existing account automatically reopens its saved library.
**Get a new link** on mobile (**Get a new code** on TV) restarts sign-in; turning the switch off cancels it and
allows direct setup. If the browser cannot open, Soup shows an error and lets
you retry the button. Auth-key entry is not offered.

Server-address paste remains available. **Back** preserves address and username
drafts, while passwords are cleared on submission or backward navigation.
Changing the connection requires server validation again. Errors stay above the
scrollable form and navigation stays below it. The interface supports touch,
keyboard/D-pad focus, reduced motion, and small TV viewports.

Connection mode is stored separately from the secure Jellyfin session. Direct
sessions restore without touching the native node. Existing accounts without
a saved choice retain Tailscale. Tailscale sessions reconnect using saved node
state; there is no automatic fallback to direct networking. JSON, artwork,
subtitles, and the authenticated playback bridge all use the selected transport.

After the first successful sign-in, the existing appearance setup lets the user
choose their library layout, palette, and brightness.

## Development

Use the root Taskfile, or:

```sh
git submodule update --init --recursive
cd apps/android
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The native Android build requires the Android SDK/NDK and Go. Flutter widget and
transport tests run headlessly without an Android emulator. Run native browser
return lifecycle tests with `cd android && ./gradlew :app:testDebugUnitTest`.
These JVM tests do not replace real phone/browser acceptance. See
[onboarding screenshots](../../docs/screenshots/onboarding/README.md) for
reproducible UI review captures and their validation limits.
