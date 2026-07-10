import { describe, it, expect, beforeEach } from 'vitest';
import { resetDb } from '@/db/client.testenv';
import { createBook } from '@/features/books/queries';
import { addChapterNote } from '@/features/chapters/queries';
import { createCharacter, createPrediction } from '@/features/reference/queries';
import { searchAll, countResults } from '@/features/search/queries';

beforeEach(() => resetDb());

async function seed() {
  const got = await createBook({ title: 'A Game of Thrones' });
  const dune = await createBook({ title: 'Dune' });
  const gotId = got!.id;
  const duneId = dune!.id;
  await addChapterNote({ bookId: gotId, chapterNumber: 3, title: 'Bran', body: 'Ned rides south with the king.' });
  await createCharacter({ bookId: gotId, name: 'Eddard Stark', description: 'Warden of the North' });
  await createPrediction({ bookId: gotId, prompt: 'Ned will lose his head' });
  await addChapterNote({ bookId: duneId, chapterNumber: 1, body: 'Paul dreams of Arrakis.' });
  return { gotId, duneId };
}

describe('searchAll', () => {
  it('returns nothing for a blank term', async () => {
    await seed();
    expect(countResults(await searchAll('   '))).toBe(0);
  });

  it('is case-insensitive and searches note bodies', async () => {
    await seed();
    const r = await searchAll('NED');
    expect(r.notes).toHaveLength(1);
    expect(r.notes[0].chapterNumber).toBe(3);
    expect(r.notes[0].bookTitle).toBe('A Game of Thrones');
  });

  it('matches characters by name and description', async () => {
    await seed();
    expect((await searchAll('eddard')).characters).toHaveLength(1);
    expect((await searchAll('warden')).characters).toHaveLength(1);
  });

  it('matches predictions by prompt', async () => {
    await seed();
    const r = await searchAll('lose his head');
    expect(r.predictions).toHaveLength(1);
    expect(r.predictions[0].status).toBe('open');
  });

  it('spans multiple books', async () => {
    await seed();
    const r = await searchAll('a'); // appears in both book titles' notes text
    const bookTitles = new Set(r.notes.map((n) => n.bookTitle));
    expect(bookTitles.has('A Game of Thrones')).toBe(true);
    expect(bookTitles.has('Dune')).toBe(true);
  });

  it('treats LIKE wildcards in the term as literal text', async () => {
    const book = await createBook({ title: 'Test' });
    await addChapterNote({ bookId: book!.id, chapterNumber: 1, body: 'literal 100% match here' });
    await addChapterNote({ bookId: book!.id, chapterNumber: 2, body: 'no percent sign' });
    // '%' must match the literal character, not act as a wildcard.
    const r = await searchAll('100%');
    expect(r.notes).toHaveLength(1);
    expect(r.notes[0].chapterNumber).toBe(1);
  });
});
