import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Db } from "./client.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function applyMigrations(
  db: Db,
  migrationsDir = path.join(__dirname, "../../migrations"),
): Promise<string[]> {
  await db.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);

  const files = (await readdir(migrationsDir))
    .filter((f) => f.endsWith(".sql"))
    .sort();
  const applied: string[] = [];
  for (const file of files) {
    const existing = await db.query<{ filename: string }>(
      `SELECT filename FROM schema_migrations WHERE filename = $1`,
      [file],
    );
    if (existing.rows.length > 0) continue;

    const sql = await readFile(path.join(migrationsDir, file), "utf8");
    await db.query("BEGIN");
    try {
      await db.query(sql);
      await db.query(`INSERT INTO schema_migrations (filename) VALUES ($1)`, [
        file,
      ]);
      await db.query("COMMIT");
      applied.push(file);
    } catch (err) {
      await db.query("ROLLBACK");
      throw err;
    }
  }
  return applied;
}
