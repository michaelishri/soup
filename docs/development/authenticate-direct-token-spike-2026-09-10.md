# Wave 1D spike: AuthenticateDirect token ↔ Soup Android HTTP client

Date: 2026-09-10. Scope: prove a Jellyfin-plugin-minted `AccessToken` (via `ISessionManager.AuthenticateDirect`) is the same shape Soup already consumes, and that Soup's existing authenticated request path accepts it when `DeviceId` matches Soup's stored device id. No plugin UI beyond notes for Wave 3.

## Verdict

**Compatible.** Pattern A can return a normal Jellyfin `AuthenticationResult`; Soup already maps `AccessToken` + `User.Id`/`Name` + `ServerId` into `JellyfinSession` and sends that token on every library/playback call. The hard requirement for Wave 3 is: the plugin must pass **Soup's** `DeviceId` (and preferably matching `App` / `DeviceName` / `AppVersion`) into `AuthenticateDirect`.

## 1. Jellyfin 10.11 shapes

### `AuthenticationRequest` (plugin → `AuthenticateDirect`)

From Jellyfin `v10.11.3` `MediaBrowser.Controller.Session.AuthenticationRequest`:

| Field | Required by `AuthenticateDirect` | Soup should supply |
| --- | --- | --- |
| `UserId` / `Username` | One must resolve a user | Mapped from entitlement `sub` → Jellyfin user |
| `Password` | No (direct skips password) | Omit |
| `App` | Yes (`ArgumentException` if empty) | `"Soup"` (`JellyfinApi.clientName`) |
| `AppVersion` | Yes | `"0.1.0"` today (`JellyfinApi.clientVersion`) |
| `DeviceId` | Yes | Persistent id from `SecureSessionStore.deviceId()` |
| `DeviceName` | Yes | `"Soup Android"` (hardcoded in MediaBrowser header) |
| `RemoteEndPoint` | No | Plugin may set from request |

`AuthenticateDirect` is `AuthenticateNewSessionInternal(request, enforcePassword: false)`. It creates a device-bound access token via `GetAuthorizationToken(user, deviceId, app, appVersion, deviceName)` and returns the same result type as password / Quick Connect login.

### `AuthenticationResult` (plugin → app)

Server type (`MediaBrowser.Controller.Authentication.AuthenticationResult`):

| Property | JSON | Soup usage |
| --- | --- | --- |
| `User` | `User` | Required: `Id`, `Name` |
| `AccessToken` | `AccessToken` | Required: stored as `JellyfinSession.accessToken` |
| `ServerId` | `ServerId` | Stored (may be empty string if missing) |
| `SessionInfo` | `SessionInfo` | **Ignored** by Soup |

Soup's OpenAPI-generated `AuthenticationResult` only models `User`, `AccessToken`, `ServerId`. Extra `SessionInfo` in JSON is ignored by `fromJson` — safe for `/SoupAuth/Exchange` to return the full server object.

`JellyfinSession` fields after mapping (`_sessionFromResult`):

- `serverUrl` — from the connection the app already has (not in the result)
- `serverId`, `userId`, `userName`, `accessToken` — from the result

## 2. Soup Android MediaBrowser / token headers

Pre-auth (generated client, e.g. AuthenticateByName / Quick Connect):

```http
Authorization: MediaBrowser Client="Soup", Device="Soup Android", DeviceId="<deviceId>", Version="0.1.0"
Accept: application/json
```

Authenticated library / playback (`_sessionHeaders`):

```http
Accept: application/json
X-Emby-Token: <AccessToken>
Authorization: MediaBrowser Client="Soup", Device="Soup Android", DeviceId="<deviceId>", Version="0.1.0", Token="<AccessToken>"
```

Device id source: `SecureSessionStore` key `jellyfin.device-id` — 32 hex chars, created once per install and reused for every JellyfinApi instance (`ConnectivityViewModel` → `JellyfinApi(..., deviceId: await sessionStore.deviceId())`).

### How Jellyfin validates the token (10.11)

`AuthorizationContext` looks up the device **by `AccessToken` alone**. It does not reject a request solely because the header `DeviceId` differs from the device row. Empty `DeviceId` / `Client` / `Device` / `Version` are filled from the stored device; mismatched `Device` / `Version` may update the device row.

So a plugin-minted token works for API calls even if `DeviceId` were wrong — but:

1. Dashboard / session UX and “one token per deviceId” semantics break.
2. A later Soup login that mints with the real Soup `DeviceId` will revoke any prior token for that `(user, deviceId)` pair via `GetAuthorizationToken`.
3. Official guidance prefers `Authorization: MediaBrowser … Token="…"`. `X-Emby-Token` is legacy (`EnableLegacyAuthorization`); removed in Jellyfin 12.

**Wave 3 must still mint with Soup’s DeviceId** so session identity stays coherent.

## 3. Proof

### Automated (this worktree)

`apps/android/test/jellyfin_api_test.dart` — `plugin-shaped AuthenticationResult (incl. SessionInfo) maps and authenticates with Soup DeviceId`:

1. Mocks `/Users/AuthenticateByName` with a full plugin-like body (`AccessToken`, `ServerId`, `User`, plus `SessionInfo`).
2. Asserts `_sessionFromResult` path accepts it (extra `SessionInfo` ignored).
3. Calls `getHome` with that session and Soup `deviceId`, asserting `DeviceId="<soup-device>"`, `Token="plugin-minted-token"`, and `X-Emby-Token` on library requests.

Run: `cd apps/android && flutter test test/jellyfin_api_test.dart --name "plugin-shaped"`.

### Documented live curl (optional host check)

After a plugin (or temporary admin path) has minted a token with Soup’s device id:

```bash
# Variables: JF base URL, token from AuthenticateDirect, Soup's device id
JF='http://jellyfin:8096'
TOKEN='…'
DEVICE='a1b2c3d4e5f60718293a4b5c6d7e8f90'   # same as SecureSessionStore
USER_ID='…'

curl -sS "$JF/Users/$USER_ID/Views" \
  -H 'Accept: application/json' \
  -H "X-Emby-Token: $TOKEN" \
  -H "Authorization: MediaBrowser Client=\"Soup\", Device=\"Soup Android\", DeviceId=\"$DEVICE\", Version=\"0.1.0\", Token=\"$TOKEN\""
```

Expect HTTP 200 and a Views payload. A 401 means the token is invalid/revoked, not a header-scheme mismatch (Soup already uses the same headers for password and Quick Connect sessions).

Reference plugin pattern: jellyfin-plugin-sso builds `AuthenticationRequest` from client-supplied `AppName` / `AppVersion` / `DeviceID` / `DeviceName`, then `return await _sessionManager.AuthenticateDirect(authRequest)`.

## 4. Wave 3 header / device-id fixes

| # | Issue | Action |
| --- | --- | --- |
| 1 | Plugin must not invent DeviceId | Exchange body must include Soup `deviceId`; pass through to `AuthenticateDirect.DeviceId` |
| 2 | App / Device / Version drift | Pass `App="Soup"`, `DeviceName="Soup Android"`, `AppVersion` matching `JellyfinApi.clientVersion` (or send all three from the app on exchange) |
| 3 | Exchange response shape | Return full `AuthenticationResult` JSON; app reuses `_sessionFromResult` (or a thin wrapper). Tolerate `SessionInfo` |
| 4 | `X-Emby-Token` | Keep for 10.11 (works with `EnableLegacyAuthorization`); plan drop before Jellyfin 12 — Token in `Authorization` already present |
| 5 | OpenAPI model omits `SessionInfo` | No change required for v1; do not rely on SessionInfo in the app |
| 6 | Hardcoded `"0.1.0"` / `"Soup Android"` | If packaging bumps version, exchange + AuthenticateDirect must stay in sync (prefer app-supplied metadata on exchange) |
| 7 | One token per (user, deviceId) | Silent re-exchange will invalidate the previous Soup token for that device — expected; clear/replace `JellyfinSession` on success |

## 5. Out of scope (this spike)

- Implementing `/SoupAuth/Exchange` or plugin UI
- Changing Soup header construction
- Live Jellyfin container exercise (curl recipe only)
