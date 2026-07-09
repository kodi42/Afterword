import { drizzle } from 'drizzle-orm/expo-sqlite';
import { openDatabaseSync } from 'expo-sqlite';
import * as schema from './schema';

/**
 * Single shared database handle for the whole app.
 * `enableChangeListener` powers useLiveQuery so screens auto-refresh on writes.
 */
export const expoDb = openDatabaseSync('afterword.db', {
  enableChangeListener: true,
});

// Required for `onDelete: 'cascade'` to actually delete child rows.
expoDb.execSync('PRAGMA foreign_keys = ON;');

export const db = drizzle(expoDb, { schema });

export { schema };
