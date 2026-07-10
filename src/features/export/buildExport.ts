import { db } from '@/db/client';
import { books, chapterNotes, characters, predictions, characterAliases } from '@/db/schema';

/**
 * Builds the export payload (schema `version: 1`) from the local database. Pure
 * data work — no native modules — so it's unit-testable and stays in lockstep
 * with the native `ImportService`. The share/file side lives in exportData.ts.
 */

export const EXPORT_VERSION = 1;

function epoch(date: Date | null | undefined): number | null {
  return date ? date.getTime() : null;
}

export async function buildExportJSON(): Promise<string> {
  const [allBooks, allNotes, allCharacters, allPredictions, allAliases] = await Promise.all([
    db.select().from(books),
    db.select().from(chapterNotes),
    db.select().from(characters),
    db.select().from(predictions),
    db.select().from(characterAliases),
  ]);

  const payload = {
    version: EXPORT_VERSION,
    exportedAt: epoch(new Date()),
    books: allBooks.map((book) => ({
      title: book.title,
      author: book.author,
      status: book.status,
      totalChapters: book.totalChapters,
      currentChapter: book.currentChapter,
      startedAt: epoch(book.startedAt),
      finishedAt: epoch(book.finishedAt),
      chapterNotes: allNotes
        .filter((n) => n.bookId === book.id)
        .map((n) => ({
          chapterNumber: n.chapterNumber,
          title: n.title,
          body: n.body,
          createdAt: epoch(n.createdAt),
        })),
      characters: allCharacters
        .filter((c) => c.bookId === book.id)
        .map((c) => ({
          name: c.name,
          description: c.description,
          firstSeenChapter: c.firstSeenChapter,
          status: c.status,
        })),
      predictions: allPredictions
        .filter((p) => p.bookId === book.id)
        .map((p) => ({
          prompt: p.prompt,
          madeAtChapter: p.madeAtChapter,
          status: p.status,
          outcome: p.outcome,
          wasCorrect: p.wasCorrect,
        })),
      aliases: allAliases
        .filter((a) => a.bookId === book.id)
        .map((a) => ({ alias: a.alias, canonical: a.canonical })),
    })),
  };

  return JSON.stringify(payload, null, 2);
}
