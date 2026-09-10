# Wave 2A — MS single-claim transport grants

Date: 2026-09-10  
Service: `services/soup-identity`  
Task: `task_dfa1de6a9267`

## Done

Replaced Wave 0 `501` stubs with real transport-grant mailbox semantics aligned to `docs/development/tailscale-auth-key-mint-spike-2026-09-10.md`.

### API

| Method | Path | Behavior |
| --- | --- | --- |
| `POST` | `/v1/servers/{serverId}/entitlements/{googleSub}/transport-grants` | Deposit Tailscale auth-key material + TTL (≥60s); encrypt-at-rest; revoke prior unclaimed grants for same pair |
| `GET` | same | List grants **without** `material` |
| `DELETE` | `.../transport-grants/{grantId}` | Soft-revoke (`revoked_at`) |
| `GET` | `/v1/me/servers` | Atomic single-claim per server; `material` once |
| `POST` | `/v1/me/servers/{serverId}/transport-grant/claim` | Explicit claim; `410` when gone |

### Storage / crypto

- Migration `002_transport_grants_wave2.sql`: `tailscale_key_id`, `capabilities`, `revoked_at`, `single_claim`
- AES-256-GCM seal via `TRANSPORT_GRANT_ENCRYPTION_KEY` (`src/lib/secret_box.ts`)
- Claim uses `SELECT … FOR UPDATE SKIP LOCKED` + conditional `UPDATE claimed_at`

### Tests

`npm test` — 6 passing:

- deposit / list omit material / DELETE revoke
- TTL expiry → unclaimable
- 12-way concurrent claim race → exactly one winner
- roster claim-once
- replace prior unclaimed on redeposit

### Out of scope (per task)

- Android / plugin mint UI
- Live Tailscale mint
- Wave 4 revocation orchestration against Tailscale control plane (plugin DELETE key + MS entitlement cascade landed; no `devices:core`)
