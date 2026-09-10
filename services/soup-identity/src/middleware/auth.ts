import type { Context, Next } from "hono";
import type { Env } from "../env.js";
import type { SigningKeys } from "../lib/crypto.js";
import { verifyAccessToken, sha256, safeEqual } from "../lib/crypto.js";
import type { Db } from "../db/client.js";

export type AppVariables = {
  googleSub: string;
  email?: string;
  pluginId: string;
};

export type AppEnv = {
  Variables: AppVariables;
  Bindings: Record<string, never>;
};

export function createSoupAuth(deps: {
  env: Env;
  keys: SigningKeys;
}) {
  return async (c: Context<AppEnv>, next: Next) => {
    const header = c.req.header("authorization");
    if (!header?.startsWith("Bearer ")) {
      return c.json({ error: "unauthorized", message: "Bearer token required" }, 401);
    }
    try {
      const claims = await verifyAccessToken(
        deps.keys,
        deps.env,
        header.slice("Bearer ".length),
      );
      c.set("googleSub", claims.sub);
      if (claims.email) c.set("email", claims.email);
      await next();
    } catch {
      return c.json({ error: "unauthorized", message: "Invalid access token" }, 401);
    }
  };
}

export function createPluginAuth(deps: { db: Db }) {
  return async (c: Context<AppEnv>, next: Next) => {
    const header = c.req.header("authorization");
    if (!header?.startsWith("Basic ")) {
      return c.json(
        { error: "unauthorized", message: "Plugin Basic auth required" },
        401,
      );
    }
    const decoded = Buffer.from(header.slice("Basic ".length), "base64").toString(
      "utf8",
    );
    const sep = decoded.indexOf(":");
    if (sep < 0) {
      return c.json({ error: "unauthorized", message: "Malformed Basic auth" }, 401);
    }
    const pluginId = decoded.slice(0, sep);
    const secret = decoded.slice(sep + 1);
    const { rows } = await deps.db.query<{
      plugin_id: string;
      secret_hash: string;
      revoked_at: Date | null;
    }>(
      `SELECT plugin_id, secret_hash, revoked_at
       FROM plugin_credentials WHERE plugin_id = $1`,
      [pluginId],
    );
    const row = rows[0];
    if (!row || row.revoked_at || !safeEqual(row.secret_hash, sha256(secret))) {
      return c.json({ error: "unauthorized", message: "Invalid plugin credentials" }, 401);
    }
    c.set("pluginId", row.plugin_id);
    await next();
  };
}
