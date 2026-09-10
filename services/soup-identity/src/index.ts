import { readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { serve } from "@hono/node-server";
import { loadEnv } from "./env.js";
import { createPool } from "./db/client.js";
import { applyMigrations } from "./db/migrations.js";
import { loadSigningKeys, sha256 } from "./lib/crypto.js";
import { createApp } from "./app.js";

/** Minimal .env loader (no dotenv dependency). Does not override existing env. */
function loadDotEnv(file = path.join(process.cwd(), ".env")) {
  if (!existsSync(file)) return;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

async function ensureBootstrapPlugin(
  db: ReturnType<typeof createPool>,
  env: ReturnType<typeof loadEnv>,
) {
  if (!env.BOOTSTRAP_PLUGIN_ID || !env.BOOTSTRAP_PLUGIN_SECRET) return;
  await db.query(
    `INSERT INTO plugin_credentials (plugin_id, secret_hash, label)
     VALUES ($1, $2, $3)
     ON CONFLICT (plugin_id) DO UPDATE
       SET secret_hash = EXCLUDED.secret_hash,
           revoked_at = NULL`,
    [env.BOOTSTRAP_PLUGIN_ID, sha256(env.BOOTSTRAP_PLUGIN_SECRET), "bootstrap"],
  );
}

async function main() {
  loadDotEnv();
  const env = loadEnv();
  const db = createPool(env.DATABASE_URL);
  const keys = await loadSigningKeys(env);

  try {
    await applyMigrations(db);
    await ensureBootstrapPlugin(db, env);
  } catch (err) {
    console.warn("Auto-migrate skipped or failed:", err);
  }

  const app = createApp({ db, env, keys });

  console.log(
    `soup-identity listening on :${env.PORT} (alg=${keys.alg} kid=${keys.kid} google=${env.googleConfigured ? "on" : "dev"})`,
  );
  serve({ fetch: app.fetch, port: env.PORT });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
