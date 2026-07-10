import { db } from '@/db/client';
import { books, type NewBook } from '@/db/schema';
import { and, desc, eq, isNull, lt, or } from 'drizzle-orm';

/**
 * All book data access lives here. Screens never write raw SQL.
 * Read screens use useLiveQuery(booksQuery) for auto-refresh.
 */

export const booksQuery = db.select().from(books).orderBy(desc(books.updatedAt));

export function bookQuery(id: number) {
  return db.select().from(books).where(eq(books.id, id));
}

export async function createBook(input: NewBook) {
  const [row] = await db.insert(books).values(input).returning();
  return row;
}

export async function updateBook(id: number, patch: Partial<NewBook>) {
  await db
    .update(books)
    .set({ ...patch, updatedAt: new Date() })
    .where(eq(books.id, id));
}

/**
 * Move a book's reading progress forward to `chapter`. Only advances — adding a
 * note for an earlier chapter never rewinds the current chapter. Used by the
 * chapter-note flow so logging a chapter keeps the library progress in step.
 */
export async function advanceCurrentChapter(bookId: number, chapter: number) {
  await db
    .update(books)
    .set({ currentChapter: chapter, updatedAt: new Date() })
    .where(
      and(
        eq(books.id, bookId),
        or(isNull(books.currentChapter), lt(books.currentChapter, chapter)),
      ),
    );
}

export async function markFinished(id: number) {
  await db
    .update(books)
    .set({ status: 'finished', finishedAt: new Date(), updatedAt: new Date() })
    .where(eq(books.id, id));
}

/** Undo "finished" — put a book back on the reading shelf. */
export async function markReading(id: number) {
  await db
    .update(books)
    .set({ status: 'reading', finishedAt: null, updatedAt: new Date() })
    .where(eq(books.id, id));
}

export async function deleteBook(id: number) {
  await db.delete(books).where(eq(books.id, id));
}
