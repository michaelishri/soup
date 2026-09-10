import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { loadEnv } from "../env.js";
import { sha256 } from "../lib/crypto.js";
import { createPool } from "./client.js";
import { applyMigrations } from "./migrations.js";

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

async function main() {
  loadDotEnv();
  const env = loadEnv();
  const pool = createPool(env.DATABASE_URL);
  const applied = await applyMigrations(pool);

  if (env.BOOTSTRAP_PLUGIN_ID && env.BOOTSTRAP_PLUGIN_SECRET) {
    await pool.query(
      `INSERT INTO plugin_credentials (plugin_id, secret_hash, label)
       VALUES ($1, $2, $3)
       ON CONFLICT (plugin_id) DO UPDATE
         SET secret_hash = EXCLUDED.secret_hash,
             label = COALESCE(EXCLUDED.label, plugin_credentials.label),
             revoked_at = NULL`,
      [
        env.BOOTSTRAP_PLUGIN_ID,
        sha256(env.BOOTSTRAP_PLUGIN_SECRET),
        "bootstrap",
      ],
    );
    console.log(`Bootstrapped plugin credential: ${env.BOOTSTRAP_PLUGIN_ID}`);
  }

  await pool.end();
  console.log(`Migrations applied: ${applied.join(", ")}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
