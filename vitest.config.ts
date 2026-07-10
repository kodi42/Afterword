import { defineConfig } from 'vitest/config';
import path from 'node:path';

/**
 * Node test runner for the pure logic (parser) and the data layer (feature
 * queries). The key move: alias `@/db/client` to the better-sqlite3 test client
 * so query modules run in Node against real in-memory SQLite. Everything else
 * under `@/` resolves to `src/` as usual.
 *
 * Not covered here (needs a device/simulator): screen rendering, keyboard,
 * gestures, scroll-to-note.
 */
export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    globals: true,
  },
  resolve: {
    alias: [
      // Specific first: the DB handle swaps to the test client.
      { find: '@/db/client', replacement: path.resolve(__dirname, 'src/db/client.testenv.ts') },
      { find: /^@\/(.*)$/, replacement: path.resolve(__dirname, 'src/$1') },
    ],
  },
});
