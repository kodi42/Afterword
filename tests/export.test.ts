import { describe, it, expect, beforeEach } from 'vitest';
import { resetDb } from '@/db/client.testenv';
import { createBook, markFinished } from '@/features/books/queries';
import { addChapterNote } from '@/features/chapters/queries';
import { createCharacter } from '@/features/reference/queries';
import { createPrediction, answerPrediction } from '@/features/reference/queries';
import { mergeCharacter } from '@/features/surface/queries';
import { buildExportJSON } from '@/features/export/buildExport';

beforeEach(() => resetDb());

describe('buildExportJSON', () => {
  it('exports an empty library as version 1 with no books', async () => {
    const payload = JSON.parse(await buildExportJSON());
    expect(payload.version).toBe(1);
    expect(payload.books).toEqual([]);
  });

  it('exports a book with all children in the import schema shape', async () => {
    const book = await createBook({ title: 'A Game of Thrones', author: 'GRRM', totalChapters: 73 });
    const bookId = book!.id;
    await addChapterNote({
      bookId,
      chapterNumber: 1,
      title: 'Bran',
      body: '- Ned: Warden of the North\n* The direwolves are found\n? Bran will climb again',
    });
    await createCharacter({ bookId, name: 'Eddard Stark', description: 'Lord of Winterfell' });
    const pred = await createPrediction({ bookId, prompt: 'Ned loses his head', madeAtChapter: 5 });
    await answerPrediction(pred!.id, true, 'he did');
    await mergeCharacter(bookId, 'Ned', 'Eddard Stark');

    const payload = JSON.parse(await buildExportJSON());
    expect(payload.books).toHaveLength(1);
    const b = payload.books[0];
    expect(b.title).toBe('A Game of Thrones');
    expect(b.status).toBe('reading');

    // Highlights travel inside the note body (the `* ` line is preserved verbatim).
    expect(b.chapterNotes).toHaveLength(1);
    expect(b.chapterNotes[0].body).toContain('* The direwolves are found');

    expect(b.characters[0]).toMatchObject({ name: 'Eddard Stark', description: 'Lord of Winterfell' });
    expect(b.predictions[0]).toMatchObject({ prompt: 'Ned loses his head', status: 'answered', wasCorrect: true });
    expect(b.aliases[0]).toMatchObject({ alias: 'ned', canonical: 'eddard stark' });
  });

  it('records finished status and epoch timestamps as numbers', async () => {
    const book = await createBook({ title: 'Dune' });
    await markFinished(book!.id);
    const payload = JSON.parse(await buildExportJSON());
    const b = payload.books[0];
    expect(b.status).toBe('finished');
    expect(typeof b.finishedAt).toBe('number');
  });
});
