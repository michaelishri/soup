# Wave 4 — Hardening + TV ~60s acceptance

Date: 2026-09-10  
Scope: `services/soup-identity`, `plugins/jellyfin-soup`, `apps/android`,
`packages/soup_identity`, `packages/soup_tailscale`  
Depends on: Wave 3 invite E2E path
([android-soup-invite-wave3-2026-09-10.md](./android-soup-invite-wave3-2026-09-10.md))

## Done

1. **Revoke E2E** — Plugin **Revoke** still DELETEs the Tailscale auth key
   (best-effort) then `DELETE …/entitlements/{googleSub}`. MS now revokes all
   grants for that pair and deletes the entitlement in **one transaction**
   (`FOR UPDATE` on the entitlement row). Concurrent claims take `FOR SHARE`
   first, so they cannot claim after revoke commits. Soft `DELETE …/transport-grants/{id}`
   remains for remint/cleanup without dropping entitlement.
2. **Grant TTL / claim races** — Deposit `ttl_seconds` must be **60–86400**.
   Claim waits with `FOR UPDATE` (not `SKIP LOCKED`) so concurrent claimants
   serialize on the single mailbox row. TTL expiry and 12-way claim races stay
   covered; added entitlement-revoke + soft-revoke claim tests.
3. **Secret-safe logging / UI** — MS `onError`, plugin Tailscale/Soup HTTP
   clients, and Android/Tailscale friendly errors redact `tskey-*`, Bearer
   tokens, JWTs, and known JSON secret fields. Exception messages returned to
   admin APIs are redacted; auth-key material is never logged on successful mint.
4. **Acceptance notes** — This document finalizes the ~60s TV path and revoke
   checks for manual acceptance.

## Revocation model (both TTL and DELETE)

| Event | Tailscale | Soup MS | App effect |
| --- | --- | --- | --- |
| Owner **Revoke** in plugin UI | `DELETE /keys/{id}` when key id known | Atomic entitlement delete + grant soft-revoke | Roster row gone; assertion `403`; no silent re-exchange for that server |
| Grant soft-revoke / remint | Previous unused key DELETE before remint | Prior unclaimed grant `revoked_at` | New material only after redeposit |
| Unused past TTL | Key `expirySeconds` | `expires_at` → unclaimable (`410` / null) | Need remint / re-invite for transport |
| Claimed ephemeral node offline | Tailscale removes ephemeral node | Entitlement may remain | New grant required for re-join |

v1 does **not** call Tailscale `devices:core` for node purge; short key TTL +
ephemeral tags + DELETE on revoke are the control plane.

## Manual acceptance — Android TV (~60s invite path)

Prerequisites: Soup Identity MS live, Jellyfin 10.11+ with `jellyfin-soup`
(config + Tailscale mint), TV build with:

```sh
flutter run --dart-define=SOUP_IDENTITY_AUTH=true \
  --dart-define=SOUP_IDENTITY_BASE_URL=<reachable-ms-url>
```

Invite + transport grant deposited **before** the TV starts device-link.

| Step | Expect | Budget |
| --- | --- | --- |
| 1. Host invite (Google sub) | Entitlement Active; transport grant deposited | Pre-work |
| 2. TV cold launch (Soup flag) | Device-link QR + user code | — |
| 3. Phone Google via verification URI | TV stores `soup.session` | ~10–20s |
| 4. Roster + auth-key join | Auto-select first server; Tailscale Running | ~5–15s |
| 5. Assertion → Exchange | Library (or appearance once) | ~2–5s |
| **Total 3–5** | In library | **≤ ~60s** on healthy LAN/tailnet |
| 6. Kill/relaunch | No Google QR when Soup refresh valid | — |
| 7. Revoke in plugin UI | Next roster empty / exchange `403`; Google only if Soup session cleared separately | — |
| 8. Remint / re-invite | New grant claimable once | — |

### Failure cues (unchanged + revoke)

| Symptom | Likely cause |
| --- | --- |
| Stuck “Loading your servers” | MS down / wrong base URL |
| Transport error then exchange fail | No Tailscale path / grant expired |
| “Not invited” / exchange 403 | Entitlement missing or revoked |
| Exchange 401 | JWKS / audience mismatch |
| Google QR after relaunch | Soup refresh revoked or cleared |
| UI/log shows `tskey-…` / Bearer / JWT | **Fail Wave 4 secret-safe** — file defect |

### Secret-safe checklist

- [ ] TV error banners never show `tskey-`, raw Bearer, or JWT blobs
- [ ] Jellyfin plugin logs on mint/revoke/invite failure omit key material and OAuth access tokens (key **id** OK)
- [ ] Soup Identity error logs omit grant material

## Tests

```sh
cd services/soup-identity && npm test
cd packages/soup_identity && dart test
cd packages/soup_tailscale && dart test
cd apps/android && flutter test test/soup_device_link_view_model_test.dart test/connectivity_view_model_test.dart
```

MS coverage added: TTL bounds, entitlement DELETE cascade, revoke↔claim race,
soft-revoke unclaimable, `redactSecrets`.

## Key surfaces

- `services/soup-identity/src/lib/transport_grants.ts` — `revokeEntitlementWithGrants`, claim `FOR SHARE` + `FOR UPDATE`, TTL max
- `services/soup-identity/src/lib/redact.ts`
- `plugins/jellyfin-soup/.../SecretRedactor.cs` + API clients / controller
- `packages/soup_identity` — `redactSecrets`
- `packages/soup_tailscale` — native error redaction
- Android `_friendlyError` paths
