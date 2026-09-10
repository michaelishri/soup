# Soup Identity

Thin microservice for Soup Google device-link, Netflix-style sessions, roster/entitlement mailbox, JWKS, and Pattern A JWT assertions.

Design: [`docs/ideas/soup-entitlement-mailbox.md`](../../docs/ideas/soup-entitlement-mailbox.md)  
Frozen OpenAPI: [`openapi/openapi.yaml`](./openapi/openapi.yaml)

**Trust rules:** Soup never calls Jellyfin. No QC mailbox. Multi-server is always `servers[]`. Transport grants are single-claim Tailscale auth-key blobs with TTL + encrypt-at-rest.

## Stack

- TypeScript + [Hono](https://hono.dev)
- Postgres 16
- JWT assertions: EdDSA (default) or RS256 via `JWT_ALG`
- Google OIDC when `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` are set; otherwise `ALLOW_DEV_LOGIN` device approve

## Quick start (Docker)

```bash
cd services/soup-identity
docker compose up --build
```

Service: `http://localhost:8787`  
Postgres (host): `localhost:5433` → container `5432`  
Health: `GET /healthz`  
JWKS: `GET /.well-known/jwks.json`

Bootstrap plugin Basic auth (from compose):

- username: `dev-plugin`
- password: `dev-plugin-secret-change-me`

## Local Node (Postgres in Docker)

```bash
cd services/soup-identity
cp .env.example .env
docker compose up -d postgres
npm install
npm run migrate   # optional; the server also auto-applies 001_init.sql on boot
npm run dev
```

## Device-link smoke (dev login)

```bash
# 1) Start a device link (TV)
curl -sS -X POST http://localhost:8787/auth/device/link | jq

# 2) Approve with the returned user_code (phone / curl)
curl -sS -X POST http://localhost:8787/auth/dev/complete \
  -H 'content-type: application/json' \
  -d '{"user_code":"ABCD-EFGH"}' | jq

# 3) Poll with device_code until status=approved (tokens)
curl -sS "http://localhost:8787/auth/device/link/<device_code>" | jq
```

Or open `verification_uri_complete` in a browser (dev HTML form when Google env is unset).

## Plugin roster + assertion

```bash
AUTH=$(printf 'dev-plugin:dev-plugin-secret-change-me' | base64 -w0)

# Register server
curl -sS -X PUT http://localhost:8787/v1/servers/home-jf \
  -H "authorization: Basic $AUTH" \
  -H 'content-type: application/json' \
  -d '{"name":"Home","audience":"jellyfin:home-jf","magic_dns":"jellyfin.tailnet.ts.net","base_url":"https://jellyfin.tailnet.ts.net"}' | jq

# Entitle the Google subject used in device-link
curl -sS -X PUT http://localhost:8787/v1/servers/home-jf/entitlements/dev-google-sub-001 \
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

Assertion JWT claims: `sub` = Google `sub`, `aud` = server audience, `exp` ≈ 2–5 minutes (`ASSERTION_TTL_SECONDS`, default 180).

## Session refresh

```bash
curl -sS -X POST http://localhost:8787/v1/sessions/refresh \
  -H 'content-type: application/json' \
  -d '{"refresh_token":"..."}' | jq
```

## Google OIDC (optional)

Set in `.env` / compose:

```env
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_REDIRECT_URI=http://localhost:8787/auth/google/callback
ALLOW_DEV_LOGIN=false
```

Flow: TV `POST /auth/device/link` → phone opens `verification_uri_complete` → Google → callback approves the user code → TV poll returns Soup access + refresh tokens.

## Transport grants (Wave 2)

Plugin deposits a Tailscale auth key; Soup seals it at rest and returns material **once** on claim.

```bash
AUTH=$(printf 'dev-plugin:dev-plugin-secret-change-me' | base64 -w0)

# Deposit (requires prior server + entitlement)
curl -sS -X POST http://localhost:8787/v1/servers/home-jf/entitlements/dev-google-sub-001/transport-grants \
  -H "authorization: Basic $AUTH" \
  -H 'content-type: application/json' \
  -d '{"grant_type":"tailscale_auth_key","material":"tskey-auth-example","ttl_seconds":1700,"tailscale_key_id":"kEXAMPLECNTRL"}' | jq

# List (material omitted)
curl -sS http://localhost:8787/v1/servers/home-jf/entitlements/dev-google-sub-001/transport-grants \
  -H "authorization: Basic $AUTH" | jq

# App claim via roster (Bearer = access_token) — first read returns material
curl -sS http://localhost:8787/v1/me/servers -H "authorization: Bearer $ACCESS" | jq

# Or explicit claim
curl -sS -X POST http://localhost:8787/v1/me/servers/home-jf/transport-grant/claim \
  -H "authorization: Bearer $ACCESS" | jq

# Revoke unused grant
curl -sS -X DELETE http://localhost:8787/v1/servers/home-jf/entitlements/dev-google-sub-001/transport-grants/<grantId> \
  -H "authorization: Basic $AUTH" -w '%{http_code}\n'
```

Semantics: new deposit revokes prior unclaimed grants for the same `(server_id, google_sub)`; claim is atomic (`claimed_at`); expired / claimed / revoked grants are unclaimable (`410` on dedicated claim). Entitlement `DELETE` soft-revokes all grants in the same transaction (Wave 4).

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
