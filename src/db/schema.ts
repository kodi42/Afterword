import { sql } from 'drizzle-orm';
import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';

/**
 * DATA MODEL
 *
 * One book has many of everything else. Every child row carries a bookId and
 * is deleted with its book (onDelete: 'cascade'). Cascade needs the
 * `PRAGMA foreign_keys = ON` set in client.ts to actually fire.
 *
 * Timestamps are stored as unix epochs and mapped to JS Date by Drizzle.
 * ids are auto-incrementing integers. Local-only app, so no UUIDs needed.
 *
 * When you add a field or a table: edit here, then run `npm run db:generate`
 * to produce a new migration. Never hand-edit the generated migration files.
 */

const timestamps = {
  createdAt: integer('created_at', { mode: 'timestamp' })
    .notNull()
    .default(sql`(unixepoch())`),
  updatedAt: integer('updated_at', { mode: 'timestamp' })
    .notNull()
    .default(sql`(unixepoch())`),
};

/** The shelf. Everything hangs off a book. */
export const books = sqliteTable('books', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  title: text('title').notNull(),
  author: text('author'),
  // 'reading' | 'finished'
  status: text('status').notNull().default('reading'),
  coverUri: text('cover_uri'),
  totalChapters: integer('total_chapters'),
  currentChapter: integer('current_chapter'),
  startedAt: integer('started_at', { mode: 'timestamp' }),
  finishedAt: integer('finished_at', { mode: 'timestamp' }),
  ...timestamps,
});

/** The core feature: one reflection per chapter. This is the v1 heart of the app. */
export const chapterNotes = sqliteTable('chapter_notes', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  bookId: integer('book_id')
    .notNull()
    .references(() => books.id, { onDelete: 'cascade' }),
  chapterNumber: integer('chapter_number').notNull(),
  title: text('title'),
  body: text('body').notNull().default(''),
  ...timestamps,
});

/** Reference: who is this person again? */
export const characters = sqliteTable('characters', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  bookId: integer('book_id')
    .notNull()
    .references(() => books.id, { onDelete: 'cascade' }),
  name: text('name').notNull(), // the only required field on an entry
  description: text('description'),
  firstSeenChapter: integer('first_seen_chapter'),
  // 'active' | 'gone'  (dead, departed, no longer relevant)
  status: text('status').notNull().default('active'),
  ...timestamps,
});

/** Reference: a plotline you are tracking across chapters. */
export const plotThreads = sqliteTable('plot_threads', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  bookId: integer('book_id')
    .notNull()
    .references(() => books.id, { onDelete: 'cascade' }),
  title: text('title').notNull(),
  notes: text('notes'),
  // 'open' | 'resolved'
  status: text('status').notNull().default('open'),
  ...timestamps,
});

/**
 * Merge escape hatch for surfaced characters. Deterministic marker extraction
 * can't guess that "Ned" and "Eddard" are one person, so a merge writes an alias
 * row: the `alias` name folds into the `canonical` name at parse time. Both are
 * stored normalized (trimmed, lower-cased) to match how names are grouped.
 */
export const characterAliases = sqliteTable('character_aliases', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  bookId: integer('book_id')
    .notNull()
    .references(() => books.id, { onDelete: 'cascade' }),
  alias: text('alias').notNull(), // the surfaced name that disappears
  canonical: text('canonical').notNull(), // the name it folds into
  ...timestamps,
});

/** Reference: a guess you make while reading, that you can later mark right or wrong. */
export const predictions = sqliteTable('predictions', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  bookId: integer('book_id')
    .notNull()
    .references(() => books.id, { onDelete: 'cascade' }),
  prompt: text('prompt').notNull(), // the question or guess
  madeAtChapter: integer('made_at_chapter'),
  // 'open' | 'answered'
  status: text('status').notNull().default('open'),
  outcome: text('outcome'), // what actually happened
  wasCorrect: integer('was_correct', { mode: 'boolean' }),
  ...timestamps,
});

// Inferred TypeScript types for use across the app.
export type Book = typeof books.$inferSelect;
export type NewBook = typeof books.$inferInsert;
export type ChapterNote = typeof chapterNotes.$inferSelect;
export type NewChapterNote = typeof chapterNotes.$inferInsert;
export type Character = typeof characters.$inferSelect;
export type NewCharacter = typeof characters.$inferInsert;
export type PlotThread = typeof plotThreads.$inferSelect;
export type Prediction = typeof predictions.$inferSelect;
export type NewPrediction = typeof predictions.$inferInsert;
export type CharacterAlias = typeof characterAliases.$inferSelect;
export type NewCharacterAlias = typeof characterAliases.$inferInsert;
