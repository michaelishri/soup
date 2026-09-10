import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Db } from "./client.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function applyMigrations(
  db: Db,
  migrationsDir = path.join(__dirname, "../../migrations"),
): Promise<string[]> {
  const files = (await readdir(migrationsDir))
    .filter((f) => f.endsWith(".sql"))
    .sort();
  const applied: string[] = [];
  for (const file of files) {
    const sql = await readFile(path.join(migrationsDir, file), "utf8");
    await db.query(sql);
    applied.push(file);
  }
  return applied;
}
