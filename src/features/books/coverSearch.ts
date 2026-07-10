/**
 * Cover search via the Google Books API. Keyless, free, no recurring cost — the
 * covers come straight from Google's book catalog, so they match the actual book
 * rather than a generic image guess.
 *
 * This module is pure + fetch only (no native modules), so the parsing is unit
 * testable. The chosen cover is downloaded and persisted locally elsewhere
 * (cover.ts) so it works offline afterward.
 */

export type CoverResult = {
  id: string;
  title: string;
  authors: string;
  thumbnail: string; // https image url
};

/** Google returns http thumbnail links; iOS ATS blocks http, so upgrade them. */
function toHttps(url: string): string {
  return url.replace(/^http:\/\//i, 'https://');
}

/**
 * Turn a Google Books `volumes` response into cover candidates. Skips volumes
 * with no image, de-dupes by thumbnail, and preserves Google's relevance order
 * (so the first result is the best default).
 */
export function parseCoverResults(json: unknown): CoverResult[] {
  const items = (json as { items?: unknown })?.items;
  if (!Array.isArray(items)) return [];

  const out: CoverResult[] = [];
  const seen = new Set<string>();

  for (const item of items) {
    const info = (item as { volumeInfo?: any })?.volumeInfo ?? {};
    const raw: string | undefined = info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail;
    if (!raw) continue;

    const thumbnail = toHttps(raw);
    if (seen.has(thumbnail)) continue;
    seen.add(thumbnail);

    out.push({
      id: String((item as { id?: unknown })?.id ?? thumbnail),
      title: typeof info.title === 'string' ? info.title : '',
      authors: Array.isArray(info.authors) ? info.authors.join(', ') : '',
      thumbnail,
    });
  }

  return out;
}

/** Build the Google Books query URL for a title (+ optional author). */
export function coverSearchUrl(title: string, author?: string | null): string {
  const terms = [`intitle:${title.trim()}`];
  if (author?.trim()) terms.push(`inauthor:${author.trim()}`);
  const q = encodeURIComponent(terms.join(' '));
  return `https://www.googleapis.com/books/v1/volumes?q=${q}&maxResults=12&printType=books&country=US`;
}

/** Search Google Books for cover candidates. Throws on a network/HTTP failure. */
export async function searchBookCovers(title: string, author?: string | null): Promise<CoverResult[]> {
  if (!title.trim()) return [];
  const res = await fetch(coverSearchUrl(title, author));
  if (!res.ok) throw new Error(`Cover search failed (${res.status})`);
  return parseCoverResults(await res.json());
}
