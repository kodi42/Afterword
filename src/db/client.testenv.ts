import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { migrate } from 'drizzle-orm/better-sqlite3/migrator';
import * as schema from './schema';

/**
 * TEST-ONLY database handle. Vitest aliases `@/db/client` to this file (see
 * vitest.config.ts), so every feature query runs against an in-memory SQLite in
 * Node instead of native expo-sqlite. Same schema, same generated migrations —
 * the DDL is plain SQLite, driver-agnostic — so behaviour matches the app.
 */
const sqlite = new Database(':memory:');
sqlite.pragma('foreign_keys = ON'); // required for onDelete: 'cascade'

export const db = drizzle(sqlite, { schema });

// Apply the real migration folder once at import time.
migrate(db, { migrationsFolder: './src/db/migrations' });

/** Wipe every table between tests without re-running migrations. */
export function resetDb() {
  sqlite.pragma('foreign_keys = OFF');
  const tables = sqlite
    .prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != '__drizzle_migrations'",
    )
    .all() as { name: string }[];
  for (const { name } of tables) sqlite.prepare(`DELETE FROM "${name}"`).run();
  sqlite.pragma('foreign_keys = ON');
}

export const expoDb = sqlite;
export { schema };
