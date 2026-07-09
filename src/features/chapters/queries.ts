import { db } from '@/db/client';
import { chapterNotes, type NewChapterNote } from '@/db/schema';
import { eq, desc } from 'drizzle-orm';
import { advanceCurrentChapter } from '@/features/books/queries';

/** All chapter-note data access. This is the core feature of v1. */

/** Newest chapter first, so the latest reflection sits at the top of the log. */
export function chapterNotesQuery(bookId: number) {
  return db
    .select()
    .from(chapterNotes)
    .where(eq(chapterNotes.bookId, bookId))
    .orderBy(desc(chapterNotes.chapterNumber), desc(chapterNotes.createdAt));
}

export async function createChapterNote(input: NewChapterNote) {
  const [row] = await db.insert(chapterNotes).values(input).returning();
  return row;
}

/**
 * The Chapters-tab add flow: insert the note, then advance the book's progress
 * to that chapter. Auto-advance happens only on add, never on edit — editing an
 * old note's chapter number shouldn't move where the reader currently is.
 */
export async function addChapterNote(input: NewChapterNote) {
  const row = await createChapterNote(input);
  await advanceCurrentChapter(input.bookId, input.chapterNumber);
  return row;
}

export async function updateChapterNote(id: number, patch: Partial<NewChapterNote>) {
  await db
    .update(chapterNotes)
    .set({ ...patch, updatedAt: new Date() })
    .where(eq(chapterNotes.id, id));
}

export async function deleteChapterNote(id: number) {
  await db.delete(chapterNotes).where(eq(chapterNotes.id, id));
}
