import type { ChapterNote } from '@/db/schema';

/**
 * MARKER PARSER — the Phase 4 engine. Pure string work, no DB, no AI, no cost.
 *
 * Reads marker lines the reader already types into chapter notes and turns them
 * into reference entries. A line only counts if it *starts* with the marker
 * (after optional leading whitespace), so ordinary prose is never misread.
 *
 *   - Name: description   -> a character / reference entry
 *   * something           -> a highlight (a key beat)
 *   ? something           -> a prediction
 *
 * Everything here is deterministic and re-runs from scratch on every read, so
 * the surfaced view always reflects the current note text. The only persisted
 * overlays live elsewhere: alias merges (character_aliases) and answered
 * prediction outcomes (materialised into the predictions table).
 */

/** Collapse a name/prompt to its grouping key: trimmed, whitespace-flattened, lower-cased. */
export function normalizeKey(s: string): string {
  return s.trim().replace(/\s+/g, ' ').toLowerCase();
}

const CHARACTER_RE = /^-\s+([^:]+?):\s*(.*)$/;
const HIGHLIGHT_RE = /^\*\s+(.+)$/;
const PREDICTION_RE = /^\?\s+(.+)$/;

export type CharacterMention = {
  noteId: number;
  chapter: number;
  description: string | null;
};

export type SurfacedCharacter = {
  key: string; // normalized canonical name — stable id for the group
  name: string; // display name, taken from the earliest mention
  description: string | null; // headline: earliest non-empty description
  firstSeenChapter: number;
  chapters: number[]; // every chapter the name appears in, ascending, de-duped
  mentions: CharacterMention[]; // ascending by chapter, for the timeline
};

export type SurfacedHighlight = {
  noteId: number;
  chapter: number;
  text: string;
};

export type SurfacedPrediction = {
  key: string; // normalized prompt — matches against materialised predictions
  noteId: number;
  chapter: number;
  text: string;
};

export type ParsedMarkers = {
  characters: SurfacedCharacter[];
  highlights: SurfacedHighlight[];
  predictions: SurfacedPrediction[];
};

type RawCharacter = { name: string } & CharacterMention;

/**
 * Parse every note's body for markers.
 *
 * @param notes    a book's chapter notes (any order)
 * @param aliasMap normalized-alias -> normalized-canonical, from character_aliases.
 *                 Any character whose key matches an alias folds into the canonical group.
 */
export function parseMarkers(
  notes: ChapterNote[],
  aliasMap: Map<string, string> = new Map(),
): ParsedMarkers {
  const rawCharacters: RawCharacter[] = [];
  const highlights: SurfacedHighlight[] = [];
  const predictions: SurfacedPrediction[] = [];

  for (const note of notes) {
    const body = note.body ?? '';
    for (const rawLine of body.split('\n')) {
      const line = rawLine.trim();
      if (!line) continue;

      const charMatch = CHARACTER_RE.exec(line);
      if (charMatch) {
        const name = charMatch[1].trim();
        const description = charMatch[2].trim();
        if (name) {
          rawCharacters.push({
            name,
            noteId: note.id,
            chapter: note.chapterNumber,
            description: description || null,
          });
        }
        continue;
      }

      const highlightMatch = HIGHLIGHT_RE.exec(line);
      if (highlightMatch) {
        highlights.push({
          noteId: note.id,
          chapter: note.chapterNumber,
          text: highlightMatch[1].trim(),
        });
        continue;
      }

      const predictionMatch = PREDICTION_RE.exec(line);
      if (predictionMatch) {
        const text = predictionMatch[1].trim();
        predictions.push({
          key: normalizeKey(text),
          noteId: note.id,
          chapter: note.chapterNumber,
          text,
        });
      }
    }
  }

  return {
    characters: groupCharacters(rawCharacters, aliasMap),
    // Highlights and predictions read newest-chapter-first.
    highlights: sortByChapterDesc(highlights),
    predictions: sortByChapterDesc(predictions),
  };
}

/** Group raw mentions by canonical key, building each character's timeline. */
function groupCharacters(
  raw: RawCharacter[],
  aliasMap: Map<string, string>,
): SurfacedCharacter[] {
  const groups = new Map<string, RawCharacter[]>();

  for (const mention of raw) {
    const rawKey = normalizeKey(mention.name);
    const key = aliasMap.get(rawKey) ?? rawKey;
    const bucket = groups.get(key);
    if (bucket) bucket.push(mention);
    else groups.set(key, [mention]);
  }

  const result: SurfacedCharacter[] = [];
  for (const [key, mentions] of groups) {
    // Earliest chapter is the headline; ties broken by original note order.
    const ordered = [...mentions].sort((a, b) => a.chapter - b.chapter);
    const firstSeenChapter = ordered[0].chapter;
    const headline = ordered.find((m) => m.description)?.description ?? null;
    const chapters = [...new Set(ordered.map((m) => m.chapter))];

    result.push({
      key,
      name: ordered[0].name,
      description: headline,
      firstSeenChapter,
      chapters,
      mentions: ordered,
    });
  }

  // People still being written about first: earliest first-seen, then name.
  return result.sort(
    (a, b) => a.firstSeenChapter - b.firstSeenChapter || a.name.localeCompare(b.name),
  );
}

function sortByChapterDesc<T extends { chapter: number; noteId: number }>(items: T[]): T[] {
  return [...items].sort((a, b) => b.chapter - a.chapter || a.noteId - b.noteId);
}
