# Android Soup auth shell (Wave 1B)

Delivered in this worktree only. Legacy Jellyfin onboarding is unchanged unless the feature flag is on.

## What landed

1. **`packages/soup_identity`** — hand-rolled HTTP client for Wave 0 OpenAPI:
   - `POST /auth/device/link`
   - `GET /auth/device/link/{deviceCode}`
   - `POST /v1/sessions/refresh`
   - `GET /v1/me/servers`
   - `MockSoupIdentityClient` for UI/tests when MS is down

2. **`SecureSoupSessionStore`** (`soup.session`) — stores access/refresh tokens, `googleSub`, optional `lastServerId`. Jellyfin `SecureSessionStore` untouched.

3. **Feature-flagged device-link UI** — QR + user code (Tailscale/QC patterns), polls until approved, then best-effort roster fetch. Gate sits **before** `ConnectivityScreen` when enabled.

## Enable

```sh
flutter run --dart-define=SOUP_IDENTITY_AUTH=true \
  --dart-define=SOUP_IDENTITY_MOCK=true
# or against local MS (emulator):
# --dart-define=SOUP_IDENTITY_BASE_URL=http://10.0.2.2:8787
```

## Explicitly not done (per Wave 1B)

- Jellyfin `/SoupAuth/Exchange`
- Replacing legacy Tailscale + Jellyfin onboarding

Wave 2C (see `android-transport-auth-key-wave2c-2026-09-10.md`) adds roster
`connectWithAuthKey` when a transport grant is present.

## Tests

- `packages/soup_identity/test/soup_identity_client_test.dart`
- `apps/android/test/soup_session_store_test.dart`
- `apps/android/test/soup_device_link_view_model_test.dart`
- `apps/android/test/soup_device_link_screen_test.dart`
