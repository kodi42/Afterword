import { describe, it, expect, beforeEach } from 'vitest';
import { eq } from 'drizzle-orm';
import { db } from '@/db/client';
// resetDb lives only on the test client. At runtime vitest aliases `@/db/client`
// to this same module, so both point at one in-memory SQLite instance.
import { resetDb } from '@/db/client.testenv';
import { characters, chapterNotes, predictions } from '@/db/schema';
import {
  createBook,
  bookQuery,
  deleteBook,
  updateBook,
  markFinished,
  markReading,
} from '@/features/books/queries';
import { addChapterNote } from '@/features/chapters/queries';
import {
  createCharacter,
  createPrediction,
  answerPrediction,
  reopenPrediction,
} from '@/features/reference/queries';
import {
  mergeCharacter,
  unmergeCharacter,
  aliasesQuery,
  buildAliasMap,
  answerSurfacedPrediction,
  predictionKeys,
} from '@/features/surface/queries';

beforeEach(() => resetDb());

async function makeBook() {
  const book = await createBook({ title: 'Test Book' });
  return book!.id;
}

describe('books', () => {
  it('creates and reads back a book', async () => {
    const id = await makeBook();
    const [row] = await bookQuery(id);
    expect(row.title).toBe('Test Book');
    expect(row.status).toBe('reading');
  });

  it('updateBook patches fields', async () => {
    const id = await makeBook();
    await updateBook(id, { title: 'Renamed', author: 'A. U. Thor', totalChapters: 42 });
    const [row] = await bookQuery(id);
    expect(row.title).toBe('Renamed');
    expect(row.author).toBe('A. U. Thor');
    expect(row.totalChapters).toBe(42);
  });

  it('markFinished sets status + finishedAt; markReading reverts', async () => {
    const id = await makeBook();
    await markFinished(id);
    let [row] = await bookQuery(id);
    expect(row.status).toBe('finished');
    expect(row.finishedAt).toBeInstanceOf(Date);

    await markReading(id);
    [row] = await bookQuery(id);
    expect(row.status).toBe('reading');
    expect(row.finishedAt).toBeNull();
  });

  it('cascades delete to child rows (foreign_keys ON)', async () => {
    const bookId = await makeBook();
    await addChapterNote({ bookId, chapterNumber: 1, body: 'hi' });
    await createCharacter({ bookId, name: 'Ned' });
    await createPrediction({ bookId, prompt: 'guess' });

    await deleteBook(bookId);

    expect(await db.select().from(chapterNotes).where(eq(chapterNotes.bookId, bookId))).toHaveLength(0);
    expect(await db.select().from(characters).where(eq(characters.bookId, bookId))).toHaveLength(0);
    expect(await db.select().from(predictions).where(eq(predictions.bookId, bookId))).toHaveLength(0);
  });
});

describe('addChapterNote — forward-only progress', () => {
  it('advances currentChapter when logging ahead', async () => {
    const bookId = await makeBook();
    await addChapterNote({ bookId, chapterNumber: 5, body: '' });
    const [book] = await bookQuery(bookId);
    expect(book.currentChapter).toBe(5);
  });

  it('never rewinds when logging an earlier chapter', async () => {
    const bookId = await makeBook();
    await addChapterNote({ bookId, chapterNumber: 5, body: '' });
    await addChapterNote({ bookId, chapterNumber: 2, body: '' });
    const [book] = await bookQuery(bookId);
    expect(book.currentChapter).toBe(5);
  });
});

describe('predictions — resolve & reopen', () => {
  it('answerPrediction records outcome + correctness, reopen clears it', async () => {
    const bookId = await makeBook();
    const row = await createPrediction({ bookId, prompt: 'The butler did it' });

    await answerPrediction(row!.id, true, '  it was the butler  ');
    let [p] = await db.select().from(predictions).where(eq(predictions.id, row!.id));
    expect(p.status).toBe('answered');
    expect(p.wasCorrect).toBe(true);
    expect(p.outcome).toBe('it was the butler'); // trimmed

    await reopenPrediction(row!.id);
    [p] = await db.select().from(predictions).where(eq(predictions.id, row!.id));
    expect(p.status).toBe('open');
    expect(p.wasCorrect).toBeNull();
    expect(p.outcome).toBeNull();
  });
});

describe('character merges', () => {
  it('merge writes a normalized alias; unmerge removes it', async () => {
    const bookId = await makeBook();
    await mergeCharacter(bookId, 'Ned', 'Eddard Stark');
    let rows = await aliasesQuery(bookId);
    expect(rows).toHaveLength(1);
    expect(rows[0].alias).toBe('ned');
    expect(rows[0].canonical).toBe('eddard stark');

    await unmergeCharacter(bookId, 'NED');
    rows = await aliasesQuery(bookId);
    expect(rows).toHaveLength(0);
  });

  it('ignores a self-merge', async () => {
    const bookId = await makeBook();
    await mergeCharacter(bookId, 'Ned', 'ned');
    expect(await aliasesQuery(bookId)).toHaveLength(0);
  });

  it('re-merging an alias replaces its previous target', async () => {
    const bookId = await makeBook();
    await mergeCharacter(bookId, 'Ned', 'Eddard');
    await mergeCharacter(bookId, 'Ned', 'Lord Stark');
    const rows = await aliasesQuery(bookId);
    expect(rows).toHaveLength(1);
    expect(rows[0].canonical).toBe('lord stark');
  });

  it('buildAliasMap flattens a chain a -> b -> c', () => {
    const map = buildAliasMap([
      { alias: 'a', canonical: 'b' },
      { alias: 'b', canonical: 'c' },
    ]);
    expect(map.get('a')).toBe('c');
    expect(map.get('b')).toBe('c');
  });

  it('buildAliasMap survives a cycle without hanging', () => {
    const map = buildAliasMap([
      { alias: 'a', canonical: 'b' },
      { alias: 'b', canonical: 'a' },
    ]);
    expect(map.has('a')).toBe(true);
  });
});

describe('surfaced prediction materialization', () => {
  it('answering a `?` line inserts an answered predictions row', async () => {
    const bookId = await makeBook();
    const surfaced = { key: 'winter is coming', noteId: 1, chapter: 3, text: 'Winter is coming' };

    await answerSurfacedPrediction(bookId, surfaced, false, 'it stayed summer');

    const rows = await db.select().from(predictions).where(eq(predictions.bookId, bookId));
    expect(rows).toHaveLength(1);
    expect(rows[0].prompt).toBe('Winter is coming');
    expect(rows[0].madeAtChapter).toBe(3);
    expect(rows[0].status).toBe('answered');
    expect(rows[0].wasCorrect).toBe(false);

    // The raw `?` line is now deduped out of the surfaced view.
    const known = predictionKeys(rows);
    expect(known.has(surfaced.key)).toBe(true);
  });
});
