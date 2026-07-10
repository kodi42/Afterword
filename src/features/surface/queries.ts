import { db } from '@/db/client';
import { characterAliases, predictions } from '@/db/schema';
import { and, eq } from 'drizzle-orm';
import { createPrediction, answerPrediction } from '@/features/reference/queries';
import { normalizeKey, type SurfacedPrediction } from './parser';

/**
 * Persistence overlays for the marker-surfaced reference view.
 *
 * The surfaced entries themselves are computed live from note text (see parser.ts).
 * Only two things can't be derived and must be stored:
 *   1. alias merges — which surfaced names are the same person
 *   2. answered-prediction outcomes — right/wrong + what actually happened
 */

/* ---------- Alias merges ---------- */

/** Live feed of a book's merges, read alongside notes to fold names at parse time. */
export function aliasesQuery(bookId: number) {
  return db.select().from(characterAliases).where(eq(characterAliases.bookId, bookId));
}

/**
 * Fold the surfaced character `aliasName` into `canonicalName`. Both are stored
 * normalized so grouping matches. A name can only fold one way, so re-merging an
 * alias replaces its previous target.
 */
export async function mergeCharacter(
  bookId: number,
  aliasName: string,
  canonicalName: string,
) {
  const alias = normalizeKey(aliasName);
  const canonical = normalizeKey(canonicalName);
  if (!alias || !canonical || alias === canonical) return;

  await db
    .delete(characterAliases)
    .where(and(eq(characterAliases.bookId, bookId), eq(characterAliases.alias, alias)));
  await db.insert(characterAliases).values({ bookId, alias, canonical });
}

/** Split a merged name back out. */
export async function unmergeCharacter(bookId: number, aliasName: string) {
  const alias = normalizeKey(aliasName);
  await db
    .delete(characterAliases)
    .where(and(eq(characterAliases.bookId, bookId), eq(characterAliases.alias, alias)));
}

/**
 * Build the normalized alias -> canonical map the parser expects, flattening
 * chains so A->B->C resolves straight to C in a single lookup. A cycle guard
 * stops a malformed loop (A->B->A) from spinning.
 */
export function buildAliasMap(rows: { alias: string; canonical: string }[]) {
  const direct = new Map<string, string>();
  for (const row of rows) direct.set(row.alias, row.canonical);

  const flat = new Map<string, string>();
  for (const alias of direct.keys()) {
    const seen = new Set<string>([alias]);
    let target = direct.get(alias)!;
    while (direct.has(target) && !seen.has(target)) {
      seen.add(target);
      target = direct.get(target)!;
    }
    flat.set(alias, target);
  }
  return flat;
}

/* ---------- Prediction outcomes ---------- */

/**
 * Answer a marker-derived prediction. It isn't a real row until now: we
 * materialise it into the predictions table (reusing the Phase 3 writers) and
 * mark it answered in one go. Once materialised it shows up in the normal
 * predictions list, and the surfaced view hides the raw `?` line for it
 * (deduped by normalized prompt — see predictionKeys below).
 */
export async function answerSurfacedPrediction(
  bookId: number,
  surfaced: SurfacedPrediction,
  wasCorrect: boolean,
  outcome?: string,
) {
  const row = await createPrediction({
    bookId,
    prompt: surfaced.text,
    madeAtChapter: surfaced.chapter,
  });
  await answerPrediction(row.id, wasCorrect, outcome);
  return row;
}

/**
 * Normalized prompts already living in the predictions table, so the surfaced
 * view can skip any `?` line that's been materialised (or manually entered).
 */
export function predictionKeys(rows: { prompt: string }[]) {
  return new Set(rows.map((r) => normalizeKey(r.prompt)));
}
