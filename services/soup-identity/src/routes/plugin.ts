import { Hono } from "hono";
import type { Db } from "../db/client.js";
import type { Env } from "../env.js";
import { createPluginAuth, type AppEnv } from "../middleware/auth.js";
import {
  depositTransportGrant,
  GRANT_TTL_MAX_SECONDS,
  GRANT_TTL_MIN_SECONDS,
  listTransportGrants,
  revokeEntitlementWithGrants,
  revokeTransportGrant,
  toPluginRecord,
} from "../lib/transport_grants.js";
import { parseEncryptionKey } from "../lib/secret_box.js";
import { isValidEmail, normalizeEmail } from "../auth/sessions.js";

export function buildPluginRoutes(deps: { db: Db; env: Env }) {
  const app = new Hono<AppEnv>();
  const requirePlugin = createPluginAuth(deps);
  const encryptionKey = parseEncryptionKey(deps.env.TRANSPORT_GRANT_ENCRYPTION_KEY);

  app.put("/v1/servers/:serverId", requirePlugin, async (c) => {
    const serverId = c.req.param("serverId");
    const pluginId = c.get("pluginId");
    const body = await c.req.json<{
      name: string;
      audience: string;
      base_url?: string;
      magic_dns?: string;
      metadata?: Record<string, unknown>;
    }>();
    if (!body.name || !body.audience) {
      return c.json(
        { error: "bad_request", message: "name and audience required" },
        400,
      );
    }

    await deps.db.query(
      `INSERT INTO servers (server_id, name, base_url, magic_dns, audience, plugin_id, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
       ON CONFLICT (server_id) DO UPDATE SET
         name = EXCLUDED.name,
         base_url = EXCLUDED.base_url,
         magic_dns = EXCLUDED.magic_dns,
         audience = EXCLUDED.audience,
         plugin_id = EXCLUDED.plugin_id,
         metadata = EXCLUDED.metadata,
         updated_at = now()`,
      [
        serverId,
        body.name,
        body.base_url ?? null,
        body.magic_dns ?? null,
        body.audience,
        pluginId,
        JSON.stringify(body.metadata ?? {}),
      ],
    );

    return c.json({
      server_id: serverId,
      name: body.name,
      base_url: body.base_url ?? null,
      magic_dns: body.magic_dns ?? null,
      audience: body.audience,
      plugin_id: pluginId,
      metadata: body.metadata ?? {},
    });
  });

  app.delete("/v1/servers/:serverId", requirePlugin, async (c) => {
    const serverId = c.req.param("serverId");
    const pluginId = c.get("pluginId");
    const result = await deps.db.query(
      `DELETE FROM servers WHERE server_id = $1 AND plugin_id = $2`,
      [serverId, pluginId],
    );
    if ((result.rowCount ?? 0) === 0) {
      return c.json({ error: "not_found", message: "Server not found" }, 404);
    }
    return c.body(null, 204);
  });

  app.put(
    "/v1/servers/:serverId/entitlements/:email",
    requirePlugin,
    async (c) => {
      const serverId = c.req.param("serverId")!;
      const rawEmail = c.req.param("email");
      if (!rawEmail) {
        return c.json({ error: "bad_request", message: "email required" }, 400);
      }
      const email = normalizeEmail(decodeURIComponent(rawEmail));
      if (!isValidEmail(email)) {
        return c.json({ error: "bad_request", message: "valid email required" }, 400);
      }
      const pluginId = c.get("pluginId");
      const body = (await c.req
        .json<{
          display_name?: string;
          jellyfin_user_hint?: string;
          metadata?: Record<string, unknown>;
        }>()
        .catch(() => ({
          display_name: undefined as string | undefined,
          jellyfin_user_hint: undefined as string | undefined,
          metadata: undefined as Record<string, unknown> | undefined,
        }))) as {
        display_name?: string;
        jellyfin_user_hint?: string;
        metadata?: Record<string, unknown>;
      };

      const { rows: owned } = await deps.db.query(
        `SELECT 1 FROM servers WHERE server_id = $1 AND plugin_id = $2`,
        [serverId, pluginId],
      );
      if (!owned[0]) {
        return c.json({ error: "not_found", message: "Unknown server" }, 404);
      }

      await deps.db.query(
        `INSERT INTO entitlements
          (server_id, email, display_name, jellyfin_user_hint, metadata)
         VALUES ($1, $2, $3, $4, $5::jsonb)
         ON CONFLICT (server_id, email) DO UPDATE SET
           display_name = EXCLUDED.display_name,
           jellyfin_user_hint = EXCLUDED.jellyfin_user_hint,
           metadata = EXCLUDED.metadata,
           updated_at = now()`,
        [
          serverId,
          email,
          body.display_name ?? null,
          body.jellyfin_user_hint ?? null,
          JSON.stringify(body.metadata ?? {}),
        ],
      );

      return c.json({
        server_id: serverId,
        email: email,
        display_name: body.display_name ?? null,
        jellyfin_user_hint: body.jellyfin_user_hint ?? null,
        metadata: body.metadata ?? {},
      });
    },
  );

  app.delete(
    "/v1/servers/:serverId/entitlements/:email",
    requirePlugin,
    async (c) => {
      const email = normalizeEmail(decodeURIComponent(c.req.param("email")!));
      if (!isValidEmail(email)) {
        return c.json({ error: "bad_request", message: "valid email required" }, 400);
      }
      const result = await revokeEntitlementWithGrants(deps.db, {
        serverId: c.req.param("serverId")!,
        email,
        pluginId: c.get("pluginId"),
      });
      if (result === "not_found") {
        return c.json(
          { error: "not_found", message: "Entitlement or server not found" },
          404,
        );
      }
      return c.body(null, 204);
    },
  );

  app.post(
    "/v1/servers/:serverId/entitlements/:email/transport-grants",
    requirePlugin,
    async (c) => {
      const serverId = c.req.param("serverId")!;
      const rawEmail = c.req.param("email");
      if (!rawEmail) {
        return c.json({ error: "bad_request", message: "email required" }, 400);
      }
      const email = normalizeEmail(decodeURIComponent(rawEmail));
      if (!isValidEmail(email)) {
        return c.json({ error: "bad_request", message: "valid email required" }, 400);
      }
      const pluginId = c.get("pluginId");

      const body = await c.req.json<{
        grant_type?: string;
        material?: string;
        ttl_seconds?: number;
        tailscale_key_id?: string;
        capabilities?: Record<string, unknown>;
        single_claim?: boolean;
      }>();

      if (body.grant_type !== "tailscale_auth_key") {
        return c.json(
          {
            error: "bad_request",
            message: "grant_type must be tailscale_auth_key",
          },
          400,
        );
      }
      if (!body.material || typeof body.material !== "string") {
        return c.json(
          { error: "bad_request", message: "material required" },
          400,
        );
      }
      const ttl = body.ttl_seconds;
      if (
        typeof ttl !== "number" ||
        !Number.isFinite(ttl) ||
        ttl < GRANT_TTL_MIN_SECONDS ||
        ttl > GRANT_TTL_MAX_SECONDS
      ) {
        return c.json(
          {
            error: "bad_request",
            message: `ttl_seconds must be between ${GRANT_TTL_MIN_SECONDS} and ${GRANT_TTL_MAX_SECONDS}`,
          },
          400,
        );
      }

      const { rows: owned } = await deps.db.query(
        `SELECT 1 FROM servers WHERE server_id = $1 AND plugin_id = $2`,
        [serverId, pluginId],
      );
      if (!owned[0]) {
        return c.json({ error: "not_found", message: "Unknown server" }, 404);
      }

      const { rows: entitled } = await deps.db.query(
        `SELECT 1 FROM entitlements WHERE server_id = $1 AND email = $2`,
        [serverId, email],
      );
      if (!entitled[0]) {
        return c.json(
          { error: "not_found", message: "Entitlement not found" },
          404,
        );
      }

      const row = await depositTransportGrant(deps.db, encryptionKey, {
        serverId: serverId!,
        email: email!,
        grantType: body.grant_type,
        material: body.material,
        ttlSeconds: Math.floor(ttl),
        tailscaleKeyId: body.tailscale_key_id ?? null,
        capabilities: body.capabilities,
        singleClaim: body.single_claim ?? true,
      });

      return c.json(toPluginRecord(row), 201);
    },
  );

  app.get(
    "/v1/servers/:serverId/entitlements/:email/transport-grants",
    requirePlugin,
    async (c) => {
      const serverId = c.req.param("serverId")!;
      const email = normalizeEmail(decodeURIComponent(c.req.param("email")!));
      if (!isValidEmail(email)) {
        return c.json({ error: "bad_request", message: "valid email required" }, 400);
      }
      const pluginId = c.get("pluginId");
      const { rows: owned } = await deps.db.query(
        `SELECT 1 FROM servers WHERE server_id = $1 AND plugin_id = $2`,
        [serverId, pluginId],
      );
      if (!owned[0]) {
        return c.json({ error: "not_found", message: "Unknown server" }, 404);
      }

      const rows = await listTransportGrants(deps.db, serverId, email);
      return c.json({ grants: rows.map(toPluginRecord) });
    },
  );

  app.delete(
    "/v1/servers/:serverId/entitlements/:email/transport-grants/:grantId",
    requirePlugin,
    async (c) => {
      const email = normalizeEmail(decodeURIComponent(c.req.param("email")!));
      if (!isValidEmail(email)) {
        return c.json({ error: "bad_request", message: "valid email required" }, 400);
      }
      const result = await revokeTransportGrant(deps.db, {
        serverId: c.req.param("serverId")!,
        email,
        grantId: c.req.param("grantId")!,
        pluginId: c.get("pluginId"),
      });
      if (result === "not_found") {
        return c.json({ error: "not_found", message: "Grant not found" }, 404);
      }
      return c.body(null, 204);
    },
  );

  return app;
}
