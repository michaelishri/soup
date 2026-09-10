import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { after, before, describe, it } from "node:test";
import { createApp } from "../src/app.js";
import { createPool, type Db } from "../src/db/client.js";
import { applyMigrations } from "../src/db/migrations.js";
import { loadEnv } from "../src/env.js";
import { loadSigningKeys, sha256 } from "../src/lib/crypto.js";
import { openSecret, parseEncryptionKey, sealSecret } from "../src/lib/secret_box.js";
import {
  claimTransportGrant,
  depositTransportGrant,
} from "../src/lib/transport_grants.js";
import { createSession, upsertSubject } from "../src/auth/sessions.js";

const PLUGIN_ID = "test-plugin-tg";
const PLUGIN_SECRET = "test-plugin-secret";
const EMAIL = "tg@example.com";
const SERVER_ID = "test-jf-tg";

describe("secret_box", () => {
  it("round-trips AES-GCM seals", () => {
    const key = parseEncryptionKey(
      "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    );
    const sealed = sealSecret("tskey-auth-secret", key);
    assert.match(sealed, /^v1\./);
    assert.equal(openSecret(sealed, key), "tskey-auth-secret");
  });
});

describe("transport grants", () => {
  let db: Db;
  let encryptionKey: Buffer;
  let app: ReturnType<typeof createApp>;
  let accessToken: string;
  let env: ReturnType<typeof loadEnv>;

  before(async () => {
    process.env.ALLOW_DEV_LOGIN = "true";
    env = loadEnv({
      ...process.env,
      BOOTSTRAP_PLUGIN_ID: PLUGIN_ID,
      BOOTSTRAP_PLUGIN_SECRET: PLUGIN_SECRET,
      TRANSPORT_GRANT_ENCRYPTION_KEY:
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    });
    encryptionKey = parseEncryptionKey(env.TRANSPORT_GRANT_ENCRYPTION_KEY);
    db = createPool(env.DATABASE_URL);
    await applyMigrations(db);
    await db.query(
      `INSERT INTO plugin_credentials (plugin_id, secret_hash, label)
       VALUES ($1, $2, $3)
       ON CONFLICT (plugin_id) DO UPDATE
         SET secret_hash = EXCLUDED.secret_hash, revoked_at = NULL`,
      [PLUGIN_ID, sha256(PLUGIN_SECRET), "test"],
    );

    const keys = await loadSigningKeys(env, `/tmp/soup-identity-test-keys-${randomBytes(4).toString("hex")}`);
    app = createApp({ db, env, keys });

    await upsertSubject(db, {
      email: EMAIL,
      name: "TG Tester",
    });
    const session = await createSession(db, keys, env, {
      email: EMAIL,
    });
    accessToken = session.access_token;

    await db.query(
      `INSERT INTO servers (server_id, name, audience, plugin_id)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (server_id) DO UPDATE SET
         name = EXCLUDED.name,
         audience = EXCLUDED.audience,
         plugin_id = EXCLUDED.plugin_id,
         updated_at = now()`,
      [SERVER_ID, "Test JF", "jellyfin:test-jf-tg", PLUGIN_ID],
    );
    await db.query(
      `INSERT INTO entitlements (server_id, email, display_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (server_id, email) DO UPDATE SET
         display_name = EXCLUDED.display_name,
         updated_at = now()`,
      [SERVER_ID, EMAIL, "Tester"],
    );
  });

  after(async () => {
    await db.query(`DELETE FROM transport_grants WHERE server_id = $1`, [
      SERVER_ID,
    ]);
    await db.query(`DELETE FROM entitlements WHERE server_id = $1`, [SERVER_ID]);
    await db.query(`DELETE FROM servers WHERE server_id = $1`, [SERVER_ID]);
    await db.query(`DELETE FROM sessions WHERE email = $1`, [EMAIL]);
    await db.query(`DELETE FROM subjects WHERE email = $1`, [EMAIL]);
    await db.query(`DELETE FROM plugin_credentials WHERE plugin_id = $1`, [
      PLUGIN_ID,
    ]);
    await db.end();
  });

  function pluginAuth(): string {
    return `Basic ${Buffer.from(`${PLUGIN_ID}:${PLUGIN_SECRET}`).toString("base64")}`;
  }

  async function cleanupGrants() {
    await db.query(`DELETE FROM transport_grants WHERE server_id = $1`, [
      SERVER_ID,
    ]);
  }

  it("deposits grant, omits material on list, revokes via DELETE", async () => {
    await cleanupGrants();
    const material = `tskey-auth-${randomBytes(8).toString("hex")}`;

    const depositRes = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}/transport-grants`,
      {
        method: "POST",
        headers: {
          authorization: pluginAuth(),
          "content-type": "application/json",
        },
        body: JSON.stringify({
          grant_type: "tailscale_auth_key",
          material,
          ttl_seconds: 1700,
          tailscale_key_id: "kTESTCNTRL",
          capabilities: { ephemeral: true, reusable: false },
        }),
      },
    );
    assert.equal(depositRes.status, 201);
    const deposited = (await depositRes.json()) as {
      id: string;
      material?: string;
      tailscale_key_id?: string;
    };
    assert.ok(deposited.id);
    assert.equal(deposited.material, undefined);
    assert.equal(deposited.tailscale_key_id, "kTESTCNTRL");

    const listRes = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}/transport-grants`,
      { headers: { authorization: pluginAuth() } },
    );
    assert.equal(listRes.status, 200);
    const listed = (await listRes.json()) as {
      grants: Array<{ id: string; material?: string }>;
    };
    assert.equal(listed.grants.length, 1);
    assert.equal(listed.grants[0]!.material, undefined);

    const delRes = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}/transport-grants/${deposited.id}`,
      { method: "DELETE", headers: { authorization: pluginAuth() } },
    );
    assert.equal(delRes.status, 204);

    const claimRes = await app.request(
      `/v1/me/servers/${SERVER_ID}/transport-grant/claim`,
      {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}` },
      },
    );
    assert.equal(claimRes.status, 410);
  });

  it("rejects expired grants (TTL)", async () => {
    await cleanupGrants();
    const material = `tskey-auth-expired-${randomBytes(4).toString("hex")}`;
    const row = await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material,
      ttlSeconds: 120,
    });

    await db.query(
      `UPDATE transport_grants SET expires_at = now() - interval '1 second' WHERE id = $1`,
      [row.id],
    );

    const claimed = await claimTransportGrant(
      db,
      encryptionKey,
      SERVER_ID,
      EMAIL,
    );
    assert.equal(claimed, null);

    const httpClaim = await app.request(
      `/v1/me/servers/${SERVER_ID}/transport-grant/claim`,
      {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}` },
      },
    );
    assert.equal(httpClaim.status, 410);

    const roster = await app.request("/v1/me/servers", {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    assert.equal(roster.status, 200);
    const body = (await roster.json()) as {
      servers: Array<{ id: string; transport_grant: unknown }>;
    };
    const server = body.servers.find((s) => s.id === SERVER_ID);
    assert.ok(server);
    assert.equal(server.transport_grant, null);
  });

  it("enforces single-claim under concurrent races", async () => {
    await cleanupGrants();
    const material = `tskey-auth-race-${randomBytes(8).toString("hex")}`;
    await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material,
      ttlSeconds: 600,
    });

    const attempts = await Promise.all(
      Array.from({ length: 12 }, () =>
        claimTransportGrant(db, encryptionKey, SERVER_ID, EMAIL),
      ),
    );

    const winners = attempts.filter((a) => a !== null);
    assert.equal(winners.length, 1);
    assert.equal(winners[0]!.material, material);

    const secondWave = await Promise.all(
      Array.from({ length: 8 }, () =>
        app.request("/v1/me/servers", {
          headers: { authorization: `Bearer ${accessToken}` },
        }),
      ),
    );
    for (const res of secondWave) {
      assert.equal(res.status, 200);
      const body = (await res.json()) as {
        servers: Array<{ id: string; transport_grant: unknown }>;
      };
      const server = body.servers.find((s) => s.id === SERVER_ID);
      assert.equal(server?.transport_grant, null);
    }
  });

  it("returns material once via roster claim", async () => {
    await cleanupGrants();
    const material = `tskey-auth-roster-${randomBytes(6).toString("hex")}`;
    await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material,
      ttlSeconds: 900,
    });

    const first = await app.request("/v1/me/servers", {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    assert.equal(first.status, 200);
    const firstBody = (await first.json()) as {
      servers: Array<{
        id: string;
        transport_grant: { material?: string } | null;
      }>;
    };
    const firstServer = firstBody.servers.find((s) => s.id === SERVER_ID);
    assert.equal(firstServer?.transport_grant?.material, material);

    const second = await app.request("/v1/me/servers", {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const secondBody = (await second.json()) as {
      servers: Array<{ id: string; transport_grant: unknown }>;
    };
    assert.equal(
      secondBody.servers.find((s) => s.id === SERVER_ID)?.transport_grant,
      null,
    );
  });

  it("replaces prior unclaimed grant on new deposit", async () => {
    await cleanupGrants();
    const first = await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material: "tskey-auth-old",
      ttlSeconds: 900,
    });
    const second = await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material: "tskey-auth-new",
      ttlSeconds: 900,
    });

    const { rows: firstRow } = await db.query<{ revoked_at: Date | null }>(
      `SELECT revoked_at FROM transport_grants WHERE id = $1`,
      [first.id],
    );
    assert.ok(firstRow[0]?.revoked_at);

    const claimed = await claimTransportGrant(
      db,
      encryptionKey,
      SERVER_ID,
      EMAIL,
    );
    assert.equal(claimed?.id, second.id);
    assert.equal(claimed?.material, "tskey-auth-new");
  });

  it("rejects ttl_seconds outside 60–86400", async () => {
    await cleanupGrants();
    const tooShort = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}/transport-grants`,
      {
        method: "POST",
        headers: {
          authorization: pluginAuth(),
          "content-type": "application/json",
        },
        body: JSON.stringify({
          grant_type: "tailscale_auth_key",
          material: "tskey-auth-short",
          ttl_seconds: 30,
        }),
      },
    );
    assert.equal(tooShort.status, 400);

    const tooLong = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}/transport-grants`,
      {
        method: "POST",
        headers: {
          authorization: pluginAuth(),
          "content-type": "application/json",
        },
        body: JSON.stringify({
          grant_type: "tailscale_auth_key",
          material: "tskey-auth-long",
          ttl_seconds: 86_401,
        }),
      },
    );
    assert.equal(tooLong.status, 400);
  });

  it("DELETE entitlement soft-revokes grants and blocks claim/roster/assertion", async () => {
    await cleanupGrants();
    const material = `tskey-auth-revoke-${randomBytes(6).toString("hex")}`;
    await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material,
      ttlSeconds: 900,
    });

    const del = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}`,
      { method: "DELETE", headers: { authorization: pluginAuth() } },
    );
    assert.equal(del.status, 204);

    const { rows: grants } = await db.query<{ revoked_at: Date | null }>(
      `SELECT revoked_at FROM transport_grants
       WHERE server_id = $1 AND email = $2`,
      [SERVER_ID, EMAIL],
    );
    assert.ok(grants.length >= 1);
    assert.ok(grants.every((g) => g.revoked_at != null));

    const claimRes = await app.request(
      `/v1/me/servers/${SERVER_ID}/transport-grant/claim`,
      {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}` },
      },
    );
    assert.equal(claimRes.status, 403);

    const roster = await app.request("/v1/me/servers", {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    assert.equal(roster.status, 200);
    const rosterBody = (await roster.json()) as {
      servers: Array<{ id: string }>;
    };
    assert.equal(
      rosterBody.servers.find((s) => s.id === SERVER_ID),
      undefined,
    );

    const assertion = await app.request("/v1/assertions", {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ server_id: SERVER_ID }),
    });
    assert.equal(assertion.status, 403);

    // Restore entitlement for subsequent tests in this suite.
    await db.query(
      `INSERT INTO entitlements (server_id, email, display_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (server_id, email) DO UPDATE SET
         display_name = EXCLUDED.display_name,
         updated_at = now()`,
      [SERVER_ID, EMAIL, "Tester"],
    );
  });

  it("claim loses to concurrent entitlement revoke (no material leak)", async () => {
    await cleanupGrants();
    const material = `tskey-auth-race-revoke-${randomBytes(6).toString("hex")}`;
    await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material,
      ttlSeconds: 900,
    });

    const { revokeEntitlementWithGrants } = await import(
      "../src/lib/transport_grants.js"
    );

    const outcomes = await Promise.all([
      claimTransportGrant(db, encryptionKey, SERVER_ID, EMAIL),
      revokeEntitlementWithGrants(db, {
        serverId: SERVER_ID,
        email: EMAIL,
        pluginId: PLUGIN_ID,
      }),
      claimTransportGrant(db, encryptionKey, SERVER_ID, EMAIL),
    ]);

    const claims = outcomes.filter(
      (o): o is NonNullable<Awaited<ReturnType<typeof claimTransportGrant>>> =>
        o !== null && typeof o === "object" && "material" in o,
    );
    // At most one claim may win if it acquired FOR SHARE before revoke's FOR UPDATE.
    assert.ok(claims.length <= 1);
    if (claims.length === 1) {
      assert.equal(claims[0]!.material, material);
    }

    const { rows: grants } = await db.query<{
      claimed_at: Date | null;
      revoked_at: Date | null;
    }>(
      `SELECT claimed_at, revoked_at FROM transport_grants
       WHERE server_id = $1 AND email = $2`,
      [SERVER_ID, EMAIL],
    );
    assert.ok(grants.every((g) => g.revoked_at != null));

    await db.query(
      `INSERT INTO entitlements (server_id, email, display_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (server_id, email) DO UPDATE SET
         display_name = EXCLUDED.display_name,
         updated_at = now()`,
      [SERVER_ID, EMAIL, "Tester"],
    );
  });

  it("soft-revoked grant is unclaimable even when entitlement remains", async () => {
    await cleanupGrants();
    const material = `tskey-auth-soft-${randomBytes(4).toString("hex")}`;
    const row = await depositTransportGrant(db, encryptionKey, {
      serverId: SERVER_ID,
      email: EMAIL,
      grantType: "tailscale_auth_key",
      material,
      ttlSeconds: 900,
    });

    const del = await app.request(
      `/v1/servers/${SERVER_ID}/entitlements/${encodeURIComponent(EMAIL)}/transport-grants/${row.id}`,
      { method: "DELETE", headers: { authorization: pluginAuth() } },
    );
    assert.equal(del.status, 204);

    const claimed = await claimTransportGrant(
      db,
      encryptionKey,
      SERVER_ID,
      EMAIL,
    );
    assert.equal(claimed, null);
  });
});

describe("redactSecrets", () => {
  it("strips auth keys, bearer tokens, and JWTs", async () => {
    const { redactSecrets } = await import("../src/lib/redact.js");
    const raw =
      'mint failed tskey-auth-abc123XYZ Bearer eyJhbGciOiJIUzI1NiJ9.aaa.bbb {"access_token":"secret"}';
    const cleaned = redactSecrets(raw);
    assert.equal(cleaned.includes("tskey-auth"), false);
    assert.equal(cleaned.includes("Bearer eyJ"), false);
    assert.equal(cleaned.includes("secret"), false);
    assert.match(cleaned, /\[redacted\]/);
  });
});
