# Wave 3 — Android Soup invite flow + silent re-auth

Date: 2026-09-10  
Scope: `apps/android` + `packages/soup_identity`  
Task: full invite path after Waves 1B/2C + AuthenticateDirect spike fixes

## Done

1. **Roster auto-select** — `ServerRoster.autoSelected` picks the sole/first
   `servers[]` row (no multi-server picker).
2. **Assertion → Exchange** — after optional auth-key Tailscale join:
   `POST /v1/assertions` → `POST /SoupAuth/Exchange` with Soup `deviceId`,
   `deviceName=Soup Android`, `app=Soup`, `appVersion` matching
   `JellyfinApi.clientVersion`, then persist `JellyfinSession`.
3. **Cold start** — restore Soup session; validate Jellyfin token; on 401
   silent re-exchange (refresh Soup access if needed). Google device-link UI
   only when Soup refresh is dead (`needsGoogleSignIn`).
4. **Feature flag** — `SOUP_IDENTITY_AUTH` keeps legacy direct / interactive
   Tailscale + password/QC when off. Soup mode sits beside that path.
5. **AuthenticateDirect spike** — exchange body supplies app-owned device
   metadata; response reuses `_sessionFromResult` (tolerates `SessionInfo`).

## Feature flags

```sh
flutter run --dart-define=SOUP_IDENTITY_AUTH=true \
  --dart-define=SOUP_IDENTITY_MOCK=true
# Live MS + plugin (emulator):
# --dart-define=SOUP_IDENTITY_BASE_URL=http://10.0.2.2:8787
# Opt out of auth-key join:
# --dart-define=SOUP_TRANSPORT_AUTH_KEY=false
```

## Manual E2E invite path (Android TV, ~60s target)

Prerequisites: Soup Identity MS running, Jellyfin 10.11+ with `jellyfin-plugin-soup`
configured (outbound register + invite), Tailscale auth-key mint working on the
plugin when transport grants are desired.

1. **Host invite (Jellyfin dashboard)** — Invite the guest Google account
   (`googleSub` and/or email). Confirm a transport grant is deposited when
   Tailscale mint is configured.
2. **TV cold launch with Soup flag** — Start Soup on TV with
   `SOUP_IDENTITY_AUTH=true` (and live `SOUP_IDENTITY_BASE_URL`, not mock).
3. **Device-link (~10–20s)** — TV shows QR + user code. Phone completes Google
   OIDC via the verification URI. TV polls until approved and stores
   `soup.session`.
4. **Roster + transport (~5–15s)** — App loads `GET /v1/me/servers`, auto-selects
   the first server, claims auth-key grant when present, `connectWithAuthKey`,
   waits until Tailscale Running.
5. **Exchange (~2–5s)** — `POST /v1/assertions` then `POST /SoupAuth/Exchange`
   with Soup device id. App writes `jellyfin.session` and opens the library
   (appearance setup on first account only).
6. **Cold start silent path** — Kill/relaunch the app. Expect no Google QR when
   Soup refresh is valid. If the Jellyfin token was revoked, expect a brief
   “Signing into Jellyfin…” exchange without Google UI.
7. **Dead Soup refresh** — Clear or expire Soup refresh only. Expect Google
   device-link UI again (`needsGoogleSignIn`).

Timing budget: steps 3–5 should land in the library around **60 seconds** on a
healthy LAN/tailnet when the invite + grant already exist before the TV starts
polling.

**Wave 4** finalizes revoke + secret-safe acceptance in
[android-soup-hardening-wave4-2026-09-10.md](./android-soup-hardening-wave4-2026-09-10.md).

### Failure cues

| Symptom | Likely cause |
| --- | --- |
| Stuck on “Loading your servers” | MS down / wrong `SOUP_IDENTITY_BASE_URL` |
| Transport error, then exchange fail | No Tailscale path to Jellyfin MagicDNS/`base_url` |
| “Not invited” (403) | Plugin entitlement missing for this Google `sub` |
| Exchange 401 | JWKS / assertion audience mismatch |
| Google QR after relaunch | Soup refresh revoked or cleared |

## Key surfaces

- `packages/soup_identity`: `mintAssertion`, `AssertionResponse`, `autoSelected`
- `JellyfinApi.exchangeSoupAuth` / `validateSession`
- `SoupDeviceLinkViewModel`: phases `exchanging`, `needsGoogleSignIn`;
  `silentReExchange`, `ensureJellyfinSessionValid`
- `ConnectivityViewModel.adoptSoupJellyfinSession`
- App shell: Soup gate via `showsAuthShell`; legacy path unchanged when flag off

## Tests

- `packages/soup_identity/test/soup_identity_client_test.dart`
- `apps/android/test/jellyfin_api_test.dart` (`exchangeSoupAuth`)
- `apps/android/test/soup_device_link_view_model_test.dart`
- `apps/android/test/connectivity_view_model_test.dart` (adopt Jellyfin session)
