# Soup for Android

Flutter client for Android 12+ mobile and Android TV, with direct Jellyfin
networking and an optional embedded Tailscale node.

## Onboarding

The centered, warm charcoal/orange panel guides users through connection,
server validation, and Jellyfin sign-in. On first launch **Use Tailscale** is
off; **Next** immediately opens server setup without starting Tailscale.

Enabling Tailscale reveals a QR code for sign-in on another device. Soup shows
preparation, sign-in, administrator approval, and connection success in place.
**Next** becomes available when connected. **Get a new code** restarts sign-in;
turning the switch off cancels it and allows direct setup. Browser launch and
auth-key entry are no longer offered by the app.

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

## Soup Identity auth (feature-flagged)

Optional Netflix-style Soup invite path **beside** legacy direct / interactive
Tailscale + password/Quick Connect. Off by default
(`SOUP_IDENTITY_AUTH=true` to enable).

When enabled: TV QR / user code → phone Google SSO (or enter TV code after Google) →
roster auto-select → optional `connectWithAuthKey` → `POST /v1/assertions` →
`POST /SoupAuth/Exchange` → library. Cold start restores Soup session and silently
re-exchanges Jellyfin tokens; Google UI returns only if Soup refresh is dead.

Invite guests by **Google email** in the Jellyfin Soup Invites page. Identity setup:
[services/soup-identity/README.md](../../services/soup-identity/README.md#google-oidc-setup).

**Direct Jellyfin login (opt-in, not default):** on the Soup device-link screen choose
**Sign in with Jellyfin instead**. That opens the legacy connection flow where you can
toggle **Use Tailscale** on or off, then sign in with username/password or Quick Connect.
**Use Soup invite instead** returns to device-link. Preference is stored as `auth.path.v1`.

```sh
flutter run --dart-define=SOUP_IDENTITY_AUTH=true \
  --dart-define=SOUP_IDENTITY_MOCK=true
```

- `SOUP_IDENTITY_AUTH=true` — Soup Google device-link + Pattern A exchange
- `SOUP_IDENTITY_MOCK=true` — in-memory client when `services/soup-identity` is down
- `SOUP_IDENTITY_BASE_URL` — defaults to `http://10.0.2.2:8787` (Android emulator → host)
- `SOUP_TRANSPORT_AUTH_KEY=false` — keep device-link but skip auth-key Tailscale join

Soup session tokens are stored under `soup.session` via
`SecureSoupSessionStore`, separate from the existing Jellyfin
`SecureSessionStore`. See
[Wave 3 invite notes](../../docs/development/android-soup-invite-wave3-2026-09-10.md).

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
transport tests run headlessly without an Android emulator. See
[onboarding screenshots](../../docs/screenshots/onboarding/README.md) for
reproducible UI review captures and their validation limits.
