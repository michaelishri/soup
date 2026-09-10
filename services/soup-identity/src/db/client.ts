import pg from "pg";

const { Pool } = pg;

export type Db = pg.Pool;

export function createPool(databaseUrl: string): Db {
  return new Pool({ connectionString: databaseUrl });
}
