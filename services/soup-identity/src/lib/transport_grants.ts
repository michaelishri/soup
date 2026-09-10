import type { Db } from "../db/client.js";
import { openSecret, sealSecret } from "./secret_box.js";

export type TransportGrantRow = {
  id: string;
  server_id: string;
  email: string;
  grant_type: string;
  material: string;
  expires_at: Date;
  claimed_at: Date | null;
  created_at: Date;
  tailscale_key_id: string | null;
  capabilities: Record<string, unknown>;
  revoked_at: Date | null;
  single_claim: boolean;
};

export type TransportGrantPublic = {
  id: string;
  grant_type: string;
  expires_at: string;
  claimed_at: string | null;
  material?: string;
  tailscale_key_id?: string | null;
  capabilities?: Record<string, unknown>;
};

/** Soup grant TTL bounds (seconds). Align with OpenAPI TransportGrantDeposit. */
export const GRANT_TTL_MIN_SECONDS = 60;
export const GRANT_TTL_MAX_SECONDS = 86_400;

export type DepositInput = {
  serverId: string;
  email: string;
  grantType: string;
  material: string;
  ttlSeconds: number;
  tailscaleKeyId?: string | null;
  capabilities?: Record<string, unknown>;
  singleClaim?: boolean;
};

function iso(d: Date | string): string {
  return d instanceof Date ? d.toISOString() : new Date(d).toISOString();
}

export function toPluginRecord(row: TransportGrantRow): TransportGrantPublic {
  return {
    id: row.id,
    grant_type: row.grant_type,
    expires_at: iso(row.expires_at),
    claimed_at: row.claimed_at ? iso(row.claimed_at) : null,
    tailscale_key_id: row.tailscale_key_id,
    capabilities: row.capabilities ?? {},
  };
}

export function toClaimRecord(
  row: TransportGrantRow,
  plaintext: string,
): TransportGrantPublic {
  return {
    id: row.id,
    grant_type: row.grant_type,
    expires_at: iso(row.expires_at),
    claimed_at: row.claimed_at ? iso(row.claimed_at) : null,
    material: plaintext,
  };
}

export function assertGrantTtl(ttlSeconds: number): number {
  if (
    typeof ttlSeconds !== "number" ||
    !Number.isFinite(ttlSeconds) ||
    ttlSeconds < GRANT_TTL_MIN_SECONDS ||
    ttlSeconds > GRANT_TTL_MAX_SECONDS
  ) {
    throw new Error(
      `ttl_seconds must be between ${GRANT_TTL_MIN_SECONDS} and ${GRANT_TTL_MAX_SECONDS}`,
    );
  }
  return Math.floor(ttlSeconds);
}

/** Invalidate prior unclaimed grants, then insert encrypted material. */
export async function depositTransportGrant(
  db: Db,
  encryptionKey: Buffer,
  input: DepositInput,
): Promise<TransportGrantRow> {
  const ttlSeconds = assertGrantTtl(input.ttlSeconds);
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      `UPDATE transport_grants
       SET revoked_at = now()
       WHERE server_id = $1
         AND email = $2
         AND claimed_at IS NULL
         AND revoked_at IS NULL`,
      [input.serverId, input.email],
    );

    const sealed = sealSecret(input.material, encryptionKey);
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);
    const { rows } = await client.query<TransportGrantRow>(
      `INSERT INTO transport_grants
         (server_id, email, grant_type, material, expires_at,
          tailscale_key_id, capabilities, single_claim)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8)
       RETURNING id, server_id, email, grant_type, material, expires_at,
                 claimed_at, created_at, tailscale_key_id, capabilities,
                 revoked_at, single_claim`,
      [
        input.serverId,
        input.email,
        input.grantType,
        sealed,
        expiresAt,
        input.tailscaleKeyId ?? null,
        JSON.stringify(input.capabilities ?? {}),
        input.singleClaim ?? true,
      ],
    );
    await client.query("COMMIT");
    return rows[0]!;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

export async function listTransportGrants(
  db: Db,
  serverId: string,
  email: string,
): Promise<TransportGrantRow[]> {
  const { rows } = await db.query<TransportGrantRow>(
    `SELECT id, server_id, email, grant_type, material, expires_at,
            claimed_at, created_at, tailscale_key_id, capabilities,
            revoked_at, single_claim
     FROM transport_grants
     WHERE server_id = $1 AND email = $2 AND revoked_at IS NULL
     ORDER BY created_at DESC`,
    [serverId, email],
  );
  return rows;
}

export async function revokeTransportGrant(
  db: Db,
  input: {
    serverId: string;
    email: string;
    grantId: string;
    pluginId: string;
  },
): Promise<"ok" | "not_found"> {
  const { rows: owned } = await db.query(
    `SELECT 1 FROM servers WHERE server_id = $1 AND plugin_id = $2`,
    [input.serverId, input.pluginId],
  );
  if (!owned[0]) return "not_found";

  const result = await db.query(
    `UPDATE transport_grants
     SET revoked_at = now()
     WHERE id = $1
       AND server_id = $2
       AND email = $3
       AND revoked_at IS NULL`,
    [input.grantId, input.serverId, input.email],
  );
  return (result.rowCount ?? 0) > 0 ? "ok" : "not_found";
}

/**
 * Atomically soft-revoke all grants for (server, sub) then delete the entitlement.
 * Holds a row lock on the entitlement so concurrent claims cannot race the delete.
 */
export async function revokeEntitlementWithGrants(
  db: Db,
  input: {
    serverId: string;
    email: string;
    pluginId: string;
  },
): Promise<"ok" | "not_found"> {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    const { rows: owned } = await client.query(
      `SELECT 1 FROM servers WHERE server_id = $1 AND plugin_id = $2`,
      [input.serverId, input.pluginId],
    );
    if (!owned[0]) {
      await client.query("ROLLBACK");
      return "not_found";
    }

    const { rows: locked } = await client.query(
      `SELECT 1 FROM entitlements
       WHERE server_id = $1 AND email = $2
       FOR UPDATE`,
      [input.serverId, input.email],
    );
    if (!locked[0]) {
      await client.query("ROLLBACK");
      return "not_found";
    }

    await client.query(
      `UPDATE transport_grants
       SET revoked_at = now()
       WHERE server_id = $1 AND email = $2 AND revoked_at IS NULL`,
      [input.serverId, input.email],
    );
    await client.query(
      `DELETE FROM entitlements WHERE server_id = $1 AND email = $2`,
      [input.serverId, input.email],
    );
    await client.query("COMMIT");
    return "ok";
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Atomically claim the newest claimable grant for (server, sub).
 * Returns plaintext material only for the winning claimer.
 * Requires a live entitlement row (FOR SHARE) so revoke cannot interleave.
 */
export async function claimTransportGrant(
  db: Db,
  encryptionKey: Buffer,
  serverId: string,
  email: string,
): Promise<TransportGrantPublic | null> {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    // Serialize against entitlement revoke (FOR UPDATE on that path).
    const { rows: entitled } = await client.query(
      `SELECT 1 FROM entitlements
       WHERE server_id = $1 AND email = $2
       FOR SHARE`,
      [serverId, email],
    );
    if (!entitled[0]) {
      await client.query("COMMIT");
      return null;
    }

    // Lock the newest claimable row so concurrent claimants serialize.
    // Prefer waiting (FOR UPDATE) over SKIP LOCKED so a concurrent claimer
    // that arrives mid-lock does not spuriously miss the only grant.
    const { rows: candidates } = await client.query<{ id: string }>(
      `SELECT id FROM transport_grants
       WHERE server_id = $1
         AND email = $2
         AND claimed_at IS NULL
         AND revoked_at IS NULL
         AND expires_at > now()
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [serverId, email],
    );
    const candidate = candidates[0];
    if (!candidate) {
      await client.query("COMMIT");
      return null;
    }

    const { rows } = await client.query<TransportGrantRow>(
      `UPDATE transport_grants
       SET claimed_at = now()
       WHERE id = $1
         AND claimed_at IS NULL
         AND revoked_at IS NULL
         AND expires_at > now()
       RETURNING id, server_id, email, grant_type, material, expires_at,
                 claimed_at, created_at, tailscale_key_id, capabilities,
                 revoked_at, single_claim`,
      [candidate.id],
    );
    await client.query("COMMIT");
    const row = rows[0];
    if (!row) return null;
    const plaintext = openSecret(row.material, encryptionKey);
    return toClaimRecord(row, plaintext);
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
