# Soup Identity

Thin microservice for Soup Google device-link, Netflix-style sessions, roster/entitlement mailbox, JWKS, and Pattern A JWT assertions.

Design: [`docs/ideas/soup-entitlement-mailbox.md`](../../docs/ideas/soup-entitlement-mailbox.md)  
Frozen OpenAPI: [`openapi/openapi.yaml`](./openapi/openapi.yaml)

**Trust rules:** Soup never calls Jellyfin. No QC mailbox. Multi-server is always `servers[]`. Transport grants are single-claim Tailscale auth-key blobs with TTL + encrypt-at-rest.

**Join key:** normalized Google account **email** (JWT `sub` and entitlement path). Google OIDC `sub` is optional metadata only.

## Stack

- TypeScript + [Hono](https://hono.dev)
- Postgres 16
- JWT assertions: **RS256** recommended (`JWT_ALG=RS256`; Jellyfin IdentityModel cannot verify EdDSA)
- Google OIDC when `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` are set; otherwise `ALLOW_DEV_LOGIN` device approve

## Quick start (Docker)

```bash
cd services/soup-identity
cp .env.example .env   # then fill Google OIDC if desired
docker compose up --build
```

Compose loads `.env` for `GOOGLE_CLIENT_*`. Service: `http://localhost:8787`  
Postgres (host): `localhost:5433` → container `5432`  
Health: `GET /healthz`  
JWKS: `GET /.well-known/jwks.json`

Bootstrap plugin Basic auth (from compose):

- username: `dev-plugin`
- password: `dev-plugin-secret-change-me`

Logs show `google=on` when OIDC is configured, else `google=dev`.

## Local Node (Postgres in Docker)

```bash
cd services/soup-identity
cp .env.example .env
docker compose up -d postgres
npm install
npm run migrate   # optional; the server also auto-applies migrations on boot
npm run dev
```

## Device-link smoke (dev login)

Use when Google client env is unset and `ALLOW_DEV_LOGIN=true`:

```bash
# 1) Start a device link (TV)
curl -sS -X POST http://localhost:8787/auth/device/link | jq

# 2) Approve with the returned user_code (phone / curl)
curl -sS -X POST http://localhost:8787/auth/dev/complete \
  -H 'content-type: application/json' \
  -d '{"user_code":"ABCD-EFGH","email":"dev@example.com"}' | jq

# 3) Poll with device_code until status=approved (tokens + email)
curl -sS "http://localhost:8787/auth/device/link/<device_code>" | jq
```

Or open `verification_uri_complete` in a browser (Festival-styled HTML form when Google env is unset).

## Google OIDC setup

Required for real Google sign-in on the phone (TV still only shows QR + code).

### 1. Google Cloud Console

1. Create (or open) a project → **APIs & Services → Credentials**.
2. **Create credentials → OAuth client ID** → application type **Web application**.
3. Under **Authorized redirect URIs**, add the exact Soup callback, e.g.:
   - Local / emulator: `http://localhost:8787/auth/google/callback`
   - Phone on LAN: `http://<host-lan-ip>:8787/auth/google/callback`  
     (must match `GOOGLE_REDIRECT_URI` and what the phone can reach)
4. Copy **Client ID** and **Client secret**.

OAuth consent screen: add test users while the app is in Testing.

### 2. Soup Identity env

In `services/soup-identity/.env` (compose reads this file):

```env
PUBLIC_BASE_URL=http://<host-reachable-from-phone>:8787
GOOGLE_CLIENT_ID=....apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=http://<same-host>:8787/auth/google/callback
ALLOW_DEV_LOGIN=false
```

| Variable | Purpose |
| --- | --- |
| `PUBLIC_BASE_URL` | Base used in `verification_uri` / QR links the TV shows |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Enables real Google SSO (`google=on`) |
| `GOOGLE_REDIRECT_URI` | Must match a Console authorized redirect URI **exactly** |
| `ALLOW_DEV_LOGIN` | `false` in production; `true` keeps `/auth/dev/complete` for local smoke |

Docker Compose may override `GOOGLE_REDIRECT_URI` to a LAN callback — keep Console and compose in sync.

Restart after changes: `docker compose up -d --force-recreate soup-identity`.

### 3. Invite the guest email (Jellyfin)

In Jellyfin → **Soup Invites**, invite the guest’s **Google email** (not OIDC `sub`). That email must match the account used on the phone.

### 4. End-to-end flow

```text
TV  POST /auth/device/link
    → shows user_code + QR (verification_uri_complete?user_code=…)

Phone opens QR → GET /auth/google/start?user_code=…
    → redirect to Google → GET /auth/google/callback

    If user_code was in OAuth state and still valid:
      → HTML “Device linked” (TV poll succeeds)

    Else (no code in QR, or code expired):
      → HTML “Enter your TV code”
      → POST /auth/google/link-device (link_token + user_code)
      → HTML “Device linked”

TV  GET /auth/device/link/{device_code} → status=approved + Soup tokens (email)
    → roster → assertion → Jellyfin /SoupAuth/Exchange
```

Soup **never** shows access/refresh tokens in the browser. Tokens are only returned on the TV poll (and to the app).

### 5. Troubleshooting

| Symptom | Check |
| --- | --- |
| Logs say `google=dev` | `.env` missing `GOOGLE_CLIENT_*`; recreate container with `env_file` |
| `redirect_uri_mismatch` | Console URI ≠ `GOOGLE_REDIRECT_URI` (scheme/host/port/path) |
| Phone can’t open QR | `PUBLIC_BASE_URL` must be reachable from the phone (not `localhost`) |
| “Not invited” on exchange | Plugin invite email ≠ Google account email (case-insensitive) |
| Code expired after Google | Enter a fresh TV code on the post-Google form |

## Plugin roster + assertion

```bash
AUTH=$(printf 'dev-plugin:dev-plugin-secret-change-me' | base64 -w0)

# Register server
curl -sS -X PUT http://localhost:8787/v1/servers/home-jf \
  -H "authorization: Basic $AUTH" \
  -H 'content-type: application/json' \
  -d '{"name":"Home","audience":"jellyfin:home-jf","magic_dns":"jellyfin.tailnet.ts.net","base_url":"https://jellyfin.tailnet.ts.net"}' | jq

# Entitle the Google email used in device-link
curl -sS -X PUT http://localhost:8787/v1/servers/home-jf/entitlements/dev%40example.com \
  -H "authorization: Basic $AUTH" \
  -H 'content-type: application/json' \
  -d '{"display_name":"Dev"}' | jq

# App: roster + assertion (Bearer = access_token from device-link)
curl -sS http://localhost:8787/v1/me/servers -H "authorization: Bearer $ACCESS" | jq
curl -sS -X POST http://localhost:8787/v1/assertions \
  -H "authorization: Bearer $ACCESS" \
  -H 'content-type: application/json' \
  -d '{"server_id":"home-jf"}' | jq
```

Assertion JWT claims: `sub` = Google email, `aud` = server audience, `exp` ≈ 2–5 minutes (`ASSERTION_TTL_SECONDS`, default 180).

## Session refresh

```bash
curl -sS -X POST http://localhost:8787/v1/sessions/refresh \
  -H 'content-type: application/json' \
  -d '{"refresh_token":"..."}' | jq
```

## Transport grants (Wave 2)

Plugin deposits a Tailscale auth key; Soup seals it at rest and returns material **once** on claim.

```bash
AUTH=$(printf 'dev-plugin:dev-plugin-secret-change-me' | base64 -w0)

# Deposit (requires prior server + entitlement)
curl -sS -X POST http://localhost:8787/v1/servers/home-jf/entitlements/dev%40example.com/transport-grants \
  -H "authorization: Basic $AUTH" \
  -H 'content-type: application/json' \
  -d '{"grant_type":"tailscale_auth_key","material":"tskey-auth-example","ttl_seconds":1700,"tailscale_key_id":"kEXAMPLECNTRL"}' | jq

# List (material omitted)
curl -sS http://localhost:8787/v1/servers/home-jf/entitlements/dev%40example.com/transport-grants \
  -H "authorization: Basic $AUTH" | jq

# App claim via roster (Bearer = access_token) — first read returns material
curl -sS http://localhost:8787/v1/me/servers -H "authorization: Bearer $ACCESS" | jq

# Or explicit claim
curl -sS -X POST http://localhost:8787/v1/me/servers/home-jf/transport-grant/claim \
  -H "authorization: Bearer $ACCESS" | jq

# Revoke unused grant
curl -sS -X DELETE http://localhost:8787/v1/servers/home-jf/entitlements/dev%40example.com/transport-grants/<grantId> \
  -H "authorization: Basic $AUTH" -w '%{http_code}\n'
```

Semantics: new deposit revokes prior unclaimed grants for the same `(server_id, email)`; claim is atomic (`claimed_at`); expired / claimed / revoked grants are unclaimable (`410` on dedicated claim). Entitlement `DELETE` soft-revokes all grants in the same transaction (Wave 4).

```bash
npm test   # TTL expiry, claim races, entitlement revoke cascade, redactSecrets
```

## Layout

```text
src/           Hono app, auth, JWKS, CRUD, transport grants
test/          node:test integration tests
migrations/    Postgres schema
openapi/       Frozen v1 OpenAPI
docker-compose.yml
```
