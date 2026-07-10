import { db } from '@/db/client';
import { books, chapterNotes, characters, predictions } from '@/db/schema';
import { desc, eq, or, sql, type Column, type SQL } from 'drizzle-orm';

/**
 * Global search across every book's chapter notes and reference entries.
 *
 * v1 uses SQLite `LIKE`, which is case-insensitive for ASCII and plenty fast at
 * a personal library's scale. The plan notes an FTS5 upgrade for ranked results
 * later; the call sites here won't change when that lands.
 *
 * Surfaced highlights/characters live inside note bodies as marker text, so a
 * note-body match already finds them — no separate marker scan needed for search.
 */

export type NoteHit = {
  kind: 'note';
  bookId: number;
  bookTitle: string;
  noteId: number;
  chapterNumber: number;
  title: string | null;
  body: string;
};

export type CharacterHit = {
  kind: 'character';
  bookId: number;
  bookTitle: string;
  id: number;
  name: string;
  description: string | null;
};

export type PredictionHit = {
  kind: 'prediction';
  bookId: number;
  bookTitle: string;
  id: number;
  prompt: string;
  status: string;
};

export type SearchResults = {
  notes: NoteHit[];
  characters: CharacterHit[];
  predictions: PredictionHit[];
};

const EMPTY: SearchResults = { notes: [], characters: [], predictions: [] };

/** Build a `%term%` matcher with LIKE wildcards in the user's text neutralized. */
function contains(column: Column, term: string): SQL {
  const escaped = term.replace(/[\\%_]/g, '\\$&');
  return sql`${column} LIKE ${'%' + escaped + '%'} ESCAPE '\\'`;
}

export async function searchAll(rawTerm: string): Promise<SearchResults> {
  const term = rawTerm.trim();
  if (!term) return EMPTY;

  const [notes, chars, preds] = await Promise.all([
    db
      .select({
        bookId: chapterNotes.bookId,
        bookTitle: books.title,
        noteId: chapterNotes.id,
        chapterNumber: chapterNotes.chapterNumber,
        title: chapterNotes.title,
        body: chapterNotes.body,
      })
      .from(chapterNotes)
      .innerJoin(books, eq(books.id, chapterNotes.bookId))
      .where(or(contains(chapterNotes.body, term), contains(chapterNotes.title, term)))
      .orderBy(desc(chapterNotes.updatedAt)),

    db
      .select({
        bookId: characters.bookId,
        bookTitle: books.title,
        id: characters.id,
        name: characters.name,
        description: characters.description,
      })
      .from(characters)
      .innerJoin(books, eq(books.id, characters.bookId))
      .where(or(contains(characters.name, term), contains(characters.description, term)))
      .orderBy(characters.name),

    db
      .select({
        bookId: predictions.bookId,
        bookTitle: books.title,
        id: predictions.id,
        prompt: predictions.prompt,
        status: predictions.status,
      })
      .from(predictions)
      .innerJoin(books, eq(books.id, predictions.bookId))
      .where(or(contains(predictions.prompt, term), contains(predictions.outcome, term)))
      .orderBy(desc(predictions.updatedAt)),
  ]);

  return {
    notes: notes.map((n) => ({ kind: 'note', ...n })),
    characters: chars.map((c) => ({ kind: 'character', ...c })),
    predictions: preds.map((p) => ({ kind: 'prediction', ...p })),
  };
}

/** Total hit count across all groups — handy for the empty/summary state. */
export function countResults(r: SearchResults): number {
  return r.notes.length + r.characters.length + r.predictions.length;
}
