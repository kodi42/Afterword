/**
 * Cover search across two keyless, free sources, modern-first:
 *   1. Apple Books (the iTunes Search API) — current commercial editions with
 *      high-resolution artwork, so we stop recommending only dated library scans.
 *   2. Open Library — appended as a fallback so obscure / out-of-print titles
 *      Apple doesn't sell still turn up a cover.
 *
 * Google Books is deliberately avoided: its keyless anonymous quota is globally
 * exhausted and 429s. Covers come straight from Apple's / Open Library's image
 * hosts, so they match the real book. This module is pure + fetch only (no native
 * modules) so the parsing is unit testable. The chosen cover is downloaded and
 * persisted locally elsewhere (cover.ts) so it works offline afterward.
 */

export type CoverResult = {
  id: string;
  title: string;
  authors: string;
  thumbnail: string; // https image url
};

// ---------------------------------------------------------------------------
// Apple Books (iTunes Search API)
// ---------------------------------------------------------------------------

/**
 * The iTunes Search API returns a small `artworkUrl100` (100px). Rewrite the
 * dimensions segment to request a crisp 600px render of the same artwork.
 */
export function appleArtworkUrl(raw: string): string {
  return raw.replace(/\/\d+x\d+bb\./, '/600x600bb.');
}

/** Build the iTunes Search API URL for a title (+ optional author). */
export function appleSearchUrl(title: string, author?: string | null): string {
  const term = [title.trim(), author?.trim()].filter(Boolean).join(' ');
  const parts = [
    'media=ebook',
    `term=${encodeURIComponent(term)}`,
    'limit=12',
    'country=US',
  ];
  return `https://itunes.apple.com/search?${parts.join('&')}`;
}

/**
 * Turn an iTunes Search response into cover candidates. Keeps only results that
 * actually have artwork, de-dupes by track id, and preserves Apple's relevance
 * order so the first result is the best modern default.
 */
export function parseAppleResults(json: unknown): CoverResult[] {
  const results = (json as { results?: unknown })?.results;
  if (!Array.isArray(results)) return [];

  const out: CoverResult[] = [];
  const seen = new Set<number>();

  for (const item of results) {
    const d = item as {
      trackId?: unknown;
      trackName?: unknown;
      artistName?: unknown;
      artworkUrl100?: unknown;
    };
    if (typeof d.artworkUrl100 !== 'string') continue;
    const trackId = typeof d.trackId === 'number' ? d.trackId : undefined;
    if (trackId !== undefined) {
      if (seen.has(trackId)) continue;
      seen.add(trackId);
    }

    out.push({
      id: trackId !== undefined ? `apple-${trackId}` : d.artworkUrl100,
      title: typeof d.trackName === 'string' ? d.trackName : '',
      authors: typeof d.artistName === 'string' ? d.artistName : '',
      thumbnail: appleArtworkUrl(d.artworkUrl100),
    });
  }

  return out;
}

/** Search Apple Books for cover candidates. Throws on a network/HTTP failure. */
export async function searchAppleBooks(title: string, author?: string | null): Promise<CoverResult[]> {
  if (!title.trim()) return [];
  const res = await fetch(appleSearchUrl(title, author));
  if (!res.ok) throw new Error(`Apple cover search failed (${res.status})`);
  return parseAppleResults(await res.json());
}

// ---------------------------------------------------------------------------
// Open Library
// ---------------------------------------------------------------------------

/** Open Library cover image url for a numeric cover id. M ≈ 180px wide. */
export function coverImageUrl(coverId: number, size: 'S' | 'M' | 'L' = 'M'): string {
  return `https://covers.openlibrary.org/b/id/${coverId}-${size}.jpg`;
}

/**
 * Turn an Open Library search response into cover candidates. Keeps only docs
 * that actually have a cover (a `cover_i`), de-dupes, and preserves Open
 * Library's relevance order.
 */
export function parseOpenLibraryResults(json: unknown): CoverResult[] {
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
export function openLibrarySearchUrl(title: string, author?: string | null): string {
  const parts = [
    `title=${encodeURIComponent(title.trim())}`,
    'limit=12',
    'fields=key,title,author_name,cover_i',
  ];
  if (author?.trim()) parts.push(`author=${encodeURIComponent(author.trim())}`);
  return `https://openlibrary.org/search.json?${parts.join('&')}`;
}

/** Search Open Library for cover candidates. Throws on a network/HTTP failure. */
export async function searchOpenLibrary(title: string, author?: string | null): Promise<CoverResult[]> {
  if (!title.trim()) return [];
  const res = await fetch(openLibrarySearchUrl(title, author));
  if (!res.ok) throw new Error(`Open Library cover search failed (${res.status})`);
  return parseOpenLibraryResults(await res.json());
}

// ---------------------------------------------------------------------------
// Merged search
// ---------------------------------------------------------------------------

/** De-dupe a merged list, keeping the first (Apple) occurrence. Guards on both
 * the image URL and `id` so React lists never see a repeated key. */
export function dedupeCovers(results: CoverResult[]): CoverResult[] {
  const seenUrl = new Set<string>();
  const seenId = new Set<string>();
  const out: CoverResult[] = [];
  for (const r of results) {
    if (seenUrl.has(r.thumbnail) || seenId.has(r.id)) continue;
    seenUrl.add(r.thumbnail);
    seenId.add(r.id);
    out.push(r);
  }
  return out;
}

/**
 * Search for cover candidates, Apple Books first then Open Library, de-duped.
 * Each source is queried concurrently and tolerated independently: if only one
 * fails we still return the other's covers; only when *both* error do we throw
 * (so the UI can show a connection message).
 */
export async function searchBookCovers(title: string, author?: string | null): Promise<CoverResult[]> {
  if (!title.trim()) return [];
  const [apple, openLibrary] = await Promise.all([
    searchAppleBooks(title, author).catch(() => null),
    searchOpenLibrary(title, author).catch(() => null),
  ]);
  if (apple === null && openLibrary === null) {
    throw new Error('Cover search failed');
  }
  return dedupeCovers([...(apple ?? []), ...(openLibrary ?? [])]);
}
