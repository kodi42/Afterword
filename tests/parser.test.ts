import { describe, it, expect } from 'vitest';
import { parseMarkers, normalizeKey } from '@/features/surface/parser';
import type { ChapterNote } from '@/db/schema';

/** Minimal note factory — only the fields the parser reads. */
function note(id: number, chapterNumber: number, body: string): ChapterNote {
  return { id, chapterNumber, body } as ChapterNote;
}

describe('normalizeKey', () => {
  it('trims, flattens whitespace, lowercases', () => {
    expect(normalizeKey('  Ned   Stark ')).toBe('ned stark');
  });
});

describe('parseMarkers — characters', () => {
  it('extracts `- Name: desc`, ignoring prose and colon-less bullets', () => {
    const { characters } = parseMarkers([
      note(1, 1, 'Intro paragraph.\n- Ned: Warden of the North\n- just a bullet\nsome - dash in prose'),
    ]);
    expect(characters).toHaveLength(1);
    expect(characters[0].name).toBe('Ned');
    expect(characters[0].description).toBe('Warden of the North');
  });

  it('groups case-insensitively and builds an ascending chapter timeline', () => {
    const { characters } = parseMarkers([
      note(2, 3, '- ned: still brooding'),
      note(1, 1, '- Ned: Warden of the North'),
    ]);
    expect(characters).toHaveLength(1);
    const ned = characters[0];
    expect(ned.firstSeenChapter).toBe(1);
    expect(ned.chapters).toEqual([1, 3]);
    expect(ned.description).toBe('Warden of the North'); // earliest headline
    expect(ned.mentions.map((m) => m.chapter)).toEqual([1, 3]);
  });

  it('folds aliases via the map (Eddard -> Ned)', () => {
    const aliasMap = new Map([['eddard', 'ned']]);
    const { characters } = parseMarkers(
      [note(1, 1, '- Ned: lord'), note(2, 2, '- Eddard: same guy')],
      aliasMap,
    );
    expect(characters).toHaveLength(1);
    expect(characters[0].chapters).toEqual([1, 2]);
  });

  it('sorts characters by first-seen chapter', () => {
    const { characters } = parseMarkers([
      note(1, 1, '- Ned: a'),
      note(2, 2, '- Jon: b'),
      note(3, 3, '- Robert: c'),
    ]);
    expect(characters.map((c) => c.name)).toEqual(['Ned', 'Jon', 'Robert']);
  });
});

describe('parseMarkers — highlights & predictions', () => {
  it('collects `*` highlights newest chapter first', () => {
    const { highlights } = parseMarkers([
      note(1, 1, '* The king arrives'),
      note(2, 2, '* Duel at the tower'),
    ]);
    expect(highlights.map((h) => h.text)).toEqual(['Duel at the tower', 'The king arrives']);
  });

  it('collects `?` predictions newest first with a normalized key', () => {
    const { predictions } = parseMarkers([
      note(1, 1, '? Ned will die'),
      note(2, 3, '?  Winter is coming'),
    ]);
    expect(predictions.map((p) => p.text)).toEqual(['Winter is coming', 'Ned will die']);
    expect(predictions[0].key).toBe('winter is coming');
  });

  it('never misreads a `?` or `*` inside prose (must start the line)', () => {
    const { highlights, predictions } = parseMarkers([
      note(1, 1, 'What happens next? Nobody knows. A star * is not a marker.'),
    ]);
    expect(highlights).toHaveLength(0);
    expect(predictions).toHaveLength(0);
  });
});
