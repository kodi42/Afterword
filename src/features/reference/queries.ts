import { db } from '@/db/client';
import {
  characters,
  predictions,
  type NewCharacter,
  type NewPrediction,
} from '@/db/schema';
import { asc, desc, eq } from 'drizzle-orm';

/**
 * Reference-section data access: characters and predictions.
 *
 * This is the manual baseline. Phase 5 auto-populates both from markers in
 * chapter notes ( `- Name: desc` and `? guess` ), reusing these same writers —
 * so keep the shape simple and let the extraction layer call in later.
 */

/* ---------- Characters ---------- */

/** Active first, then by name, so the people still in play sit at the top. */
export function charactersQuery(bookId: number) {
  return db
    .select()
    .from(characters)
    .where(eq(characters.bookId, bookId))
    .orderBy(asc(characters.status), asc(characters.name));
}

export async function createCharacter(input: NewCharacter) {
  const [row] = await db.insert(characters).values(input).returning();
  return row;
}

export async function updateCharacter(id: number, patch: Partial<NewCharacter>) {
  await db
    .update(characters)
    .set({ ...patch, updatedAt: new Date() })
    .where(eq(characters.id, id));
}

export async function deleteCharacter(id: number) {
  await db.delete(characters).where(eq(characters.id, id));
}

/* ---------- Predictions ---------- */

/** Open guesses first (still hanging), then newest made. */
export function predictionsQuery(bookId: number) {
  return db
    .select()
    .from(predictions)
    .where(eq(predictions.bookId, bookId))
    .orderBy(asc(predictions.status), desc(predictions.createdAt));
}

export async function createPrediction(input: NewPrediction) {
  const [row] = await db.insert(predictions).values(input).returning();
  return row;
}

export async function updatePrediction(id: number, patch: Partial<NewPrediction>) {
  await db
    .update(predictions)
    .set({ ...patch, updatedAt: new Date() })
    .where(eq(predictions.id, id));
}

export async function deletePrediction(id: number) {
  await db.delete(predictions).where(eq(predictions.id, id));
}

/**
 * Resolve a guess: mark it answered, record whether it panned out, and optionally
 * note what actually happened. This is the mark-right/wrong logic Phase 5 reuses
 * for `?` marker predictions — do it once, here.
 */
export async function answerPrediction(
  id: number,
  wasCorrect: boolean,
  outcome?: string,
) {
  await updatePrediction(id, {
    status: 'answered',
    wasCorrect,
    outcome: outcome?.trim() || null,
  });
}

/** Undo a resolution, dropping the guess back to open. */
export async function reopenPrediction(id: number) {
  await updatePrediction(id, { status: 'open', wasCorrect: null, outcome: null });
}
