/**
 * Cover search via the Open Library API. Keyless, free, no recurring cost, and —
 * unlike keyless Google Books, which shares one globally-exhausted anonymous
 * quota and 429s — Open Library actually works without a key.
 *
 * Covers come from openlibrary.org search + the covers.openlibrary.org image
 * host, so they match the real book. This module is pure + fetch only (no native
 * modules) so the parsing is unit testable. The chosen cover is downloaded and
 * persisted locally elsewhere (cover.ts) so it works offline afterward.
 */

export type CoverResult = {
  id: string;
  title: string;
  authors: string;
  thumbnail: string; // https image url
};

/** Open Library cover image url for a numeric cover id. M ≈ 180px wide. */
export function coverImageUrl(coverId: number, size: 'S' | 'M' | 'L' = 'M'): string {
  return `https://covers.openlibrary.org/b/id/${coverId}-${size}.jpg`;
}

/**
 * Turn an Open Library search response into cover candidates. Keeps only docs
 * that actually have a cover (a `cover_i`), de-dupes, and preserves Open
 * Library's relevance order so the first result is the best default.
 */
export function parseCoverResults(json: unknown): CoverResult[] {
  const docs = (json as { docs?: unknown })?.docs;
  if (!Array.isArray(docs)) return [];

  const out: CoverResult[] = [];
  const seen = new Set<number>();

  for (const doc of docs) {
    const d = doc as { cover_i?: unknown; key?: unknown; title?: unknown; author_name?: unknown };
    const coverId = d.cover_i;
    if (typeof coverId !== 'number' || seen.has(coverId)) continue;
    seen.add(coverId);

    out.push({
      id: String(d.key ?? coverId),
      title: typeof d.title === 'string' ? d.title : '',
      authors: Array.isArray(d.author_name) ? d.author_name.join(', ') : '',
      thumbnail: coverImageUrl(coverId, 'M'),
    });
  }

  return out;
}

/** Build the Open Library search URL for a title (+ optional author). */
export function coverSearchUrl(title: string, author?: string | null): string {
  const parts = [
    `title=${encodeURIComponent(title.trim())}`,
    'limit=12',
    'fields=key,title,author_name,cover_i',
  ];
  if (author?.trim()) parts.push(`author=${encodeURIComponent(author.trim())}`);
  return `https://openlibrary.org/search.json?${parts.join('&')}`;
}

/** Search Open Library for cover candidates. Throws on a network/HTTP failure. */
export async function searchBookCovers(title: string, author?: string | null): Promise<CoverResult[]> {
  if (!title.trim()) return [];
  const res = await fetch(coverSearchUrl(title, author));
  if (!res.ok) throw new Error(`Cover search failed (${res.status})`);
  return parseCoverResults(await res.json());
}
