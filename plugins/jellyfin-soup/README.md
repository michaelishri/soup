# Jellyfin Soup Auth plugin

Jellyfin **10.11.x** plugin for the Soup entitlement mailbox (Pattern A).

Design: [`docs/ideas/soup-entitlement-mailbox.md`](../../docs/ideas/soup-entitlement-mailbox.md)  
Soup OpenAPI: [`services/soup-identity/openapi/openapi.yaml`](../../services/soup-identity/openapi/openapi.yaml)  
Tailscale mint spike: [`docs/development/tailscale-auth-key-mint-spike-2026-09-10.md`](../../docs/development/tailscale-auth-key-mint-spike-2026-09-10.md)

## Scope

- Plugin config: Soup base URL, plugin Basic credential, server id/audience/issuer
- Tailscale config: OAuth client (preferred) or API token, tailnet, guest tags, key expiry
- Admin UI + APIs: invite/revoke by Google `sub` (email invites stay Pending until sub known)
- On invite (sub known): mint single-use ephemeral tagged auth key → `POST …/transport-grants` to Soup
- Outbound Soup client: `PUT /v1/servers/{id}`, entitlement upsert/delete, transport-grant deposit
- `POST /SoupAuth/Exchange`: fetch JWKS, verify assertion JWT, map `sub` → Jellyfin user, `AuthenticateDirect`, return `AuthenticationResult`

**Outbound only:** Jellyfin → Soup and Jellyfin → Tailscale. Soup never holds Tailscale owner credentials.

## Build

```bash
export PATH="$HOME/.dotnet:$PATH"   # if using user-local SDK
cd plugins/jellyfin-soup
dotnet build -c Release
```

Copy `Jellyfin.Plugin.Soup/bin/Release/net9.0/Jellyfin.Plugin.Soup.dll` (and IdentityModel deps if not provided by the server) into the Jellyfin plugins folder, or package via `build.yaml`.

## Configure

1. Dashboard → Plugins → Soup Auth
2. Set Soup base URL (e.g. `http://localhost:8787`)
3. Set plugin id/secret to match Soup `BOOTSTRAP_PLUGIN_*`
4. Set `ServerId` + `Audience` (JWT `aud`, e.g. `jellyfin:home-jf`)
5. Set `AssertionIssuer` to Soup `ASSERTION_ISSUER` (default `https://soup.local/identity`)
6. **Tailscale (optional but required for guest transport):**
   - Prefer OAuth client with `auth_keys` scope, bound to `tag:soup-guest`
   - Or paste a user API token (`tskey-api-…`) as fallback
   - Set guest tags (default `tag:soup-guest`) and expiry (default 1800s)
7. Save → **Register server** → invite a Google `sub` → plugin upserts entitlement and deposits a transport grant when Tailscale is configured

### Owner ACL sketch

Tag the Jellyfin host `tag:soup-jellyfin` and allow guests only to Jellyfin ports. See the Wave 1C spike for the full `tagOwners` / `grants` snippet.

## Invite → mint → deposit

When `MintTailscaleAuthKeyOnInvite` is on and Tailscale credentials are set:

1. Upsert entitlement on Soup
2. `POST https://api.tailscale.com/api/v2/oauth/token` (if OAuth) then `POST …/tailnet/{tailnet}/keys`
   - `reusable=false`, `ephemeral=true`, `preauthorized=true`, tags from config
3. `POST /v1/servers/{serverId}/entitlements/{googleSub}/transport-grants` with:
   - `grant_type=tailscale_auth_key`
   - `material` = one-time `tskey-auth-…`
   - `ttl_seconds` = `min(1800, expirySeconds - 60)` (Soup expires first)
   - `tailscale_key_id` + capability echo for audit
4. Store `TailscaleKeyId` on the local entitlement row (for revoke)

Re-inviting the same sub does **not** remint if a key id is already stored. Use **Remint** (`POST …/TransportGrant`) to force a new key (revokes the previous unused key first). Sync entitlements upserts Soup rows only — no remint.

If deposit to Soup fails after mint, the plugin DELETE-revokes the freshly minted Tailscale key so unused secrets do not linger.

## Revoke / cleanup behavior

| Event | Plugin action | Tailscale | Soup |
| --- | --- | --- | --- |
| Owner clicks **Revoke** | Mark local row `Revoked`, clear stored key id | `DELETE …/keys/{TailscaleKeyId}` when known (best-effort; 404 OK) | `DELETE …/entitlements/{googleSub}` (Wave 4: atomic grant soft-revoke + entitlement delete) |
| Unused key past Tailscale `expirySeconds` | None required | Key auto-expires | Grant `expires_at` makes claim impossible |
| Unused grant past Soup TTL | None required | Key may still exist until expiry/DELETE | Unclaimable |
| Deposit fails after mint | Surface invite/remint error | Immediate DELETE of minted key | No grant stored |
| Guest goes offline (ephemeral node) | Entitlement can remain | Node auto-removed by Tailscale | New grant needed for re-join → use **Remint** |
| Sync entitlements | Upsert only | No mint/revoke | Entitlement rows refreshed |

Wave 4 acceptance (TTL + DELETE + secret-safe logs + TV ~60s):
[`docs/development/android-soup-hardening-wave4-2026-09-10.md`](../../docs/development/android-soup-hardening-wave4-2026-09-10.md).
v1 does not call Tailscale `devices:core` for node purge.

## Exchange

```http
POST /SoupAuth/Exchange
Content-Type: application/json

{
  "assertion": "<jwt from Soup POST /v1/assertions>",
  "deviceId": "...",
  "deviceName": "...",
  "app": "Soup",
  "appVersion": "0.1.0"
}
```

Returns a normal Jellyfin `AuthenticationResult` (`AccessToken`, `User`, `SessionInfo`, …).

## Admin API (elevation required)

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/SoupAuth/Entitlements` | List Pending/Active |
| POST | `/SoupAuth/Entitlements/Invite` | Invite by `googleSub` and/or `email`; mint+deposit when configured |
| POST | `/SoupAuth/Entitlements/{idOrGoogleSub}/TransportGrant` | Force remint + deposit |
| DELETE | `/SoupAuth/Entitlements/{idOrGoogleSub}` | Revoke locally + Tailscale key DELETE + Soup DELETE |
| POST | `/SoupAuth/RegisterServer` | Soup `PUT /v1/servers/{serverId}` |
| POST | `/SoupAuth/Sync` | Register + upsert all Active rows (no remint) |
