import { describe, it, expect } from 'vitest';
import {
  parseAppleResults,
  appleSearchUrl,
  appleArtworkUrl,
  parseOpenLibraryResults,
  openLibrarySearchUrl,
  coverImageUrl,
  dedupeCovers,
  type CoverResult,
} from '@/features/books/coverSearch';

describe('parseAppleResults', () => {
  it('returns [] for a non-search response', () => {
    expect(parseAppleResults({})).toEqual([]);
    expect(parseAppleResults(null)).toEqual([]);
  });

  it('maps results to hi-res artwork urls', () => {
    const json = {
      results: [
        {
          trackId: 42,
          trackName: 'Throne of Glass',
          artistName: 'Sarah J. Maas',
          artworkUrl100: 'https://is1.mzstatic.com/image/thumb/abc/100x100bb.jpg',
        },
      ],
    };
    const [cover] = parseAppleResults(json);
    expect(cover.id).toBe('apple-42');
    expect(cover.title).toBe('Throne of Glass');
    expect(cover.authors).toBe('Sarah J. Maas');
    // 100x100 is rewritten to a crisp 600x600 render.
    expect(cover.thumbnail).toBe('https://is1.mzstatic.com/image/thumb/abc/600x600bb.jpg');
  });

  it('skips results with no artwork', () => {
    const json = {
      results: [
        { trackId: 1, trackName: 'No Art' },
        { trackId: 2, trackName: 'Has Art', artworkUrl100: 'https://x/100x100bb.jpg' },
      ],
    };
    const results = parseAppleResults(json);
    expect(results).toHaveLength(1);
    expect(results[0].id).toBe('apple-2');
  });

  it('de-dupes repeated track ids', () => {
    const json = {
      results: [
        { trackId: 7, artworkUrl100: 'https://x/100x100bb.jpg' },
        { trackId: 7, artworkUrl100: 'https://y/100x100bb.jpg' },
      ],
    };
    expect(parseAppleResults(json)).toHaveLength(1);
  });

  it('handles a missing artistName', () => {
    const json = { results: [{ trackId: 1, trackName: 'X', artworkUrl100: 'https://x/100x100bb.jpg' }] };
    expect(parseAppleResults(json)[0].authors).toBe('');
  });
});

describe('appleSearchUrl', () => {
  it('builds an ebook term query with title + author', () => {
    const url = appleSearchUrl('Throne of Glass', 'Maas');
    expect(url.startsWith('https://itunes.apple.com/search?')).toBe(true);
    expect(url).toContain('media=ebook');
    expect(decodeURIComponent(url)).toContain('term=Throne of Glass Maas');
  });

  it('omits author when none given', () => {
    expect(decodeURIComponent(appleSearchUrl('Dune'))).toContain('term=Dune');
    expect(decodeURIComponent(appleSearchUrl('Dune'))).not.toContain('Dune ');
  });
});

describe('appleArtworkUrl', () => {
  it('upscales the dimensions segment', () => {
    expect(appleArtworkUrl('https://x/y/100x100bb.jpg')).toBe('https://x/y/600x600bb.jpg');
    expect(appleArtworkUrl('https://x/y/170x170bb.png')).toBe('https://x/y/600x600bb.png');
  });
});

describe('parseOpenLibraryResults', () => {
  it('returns [] for a non-search response', () => {
    expect(parseOpenLibraryResults({})).toEqual([]);
    expect(parseOpenLibraryResults(null)).toEqual([]);
  });

  it('maps docs with a cover to https cover-image urls', () => {
    const json = {
      docs: [
        { key: '/works/OL1W', title: 'Throne of Glass', author_name: ['Sarah J. Maas'], cover_i: 13312488 },
      ],
    };
    const [cover] = parseOpenLibraryResults(json);
    expect(cover.id).toBe('/works/OL1W');
    expect(cover.title).toBe('Throne of Glass');
    expect(cover.authors).toBe('Sarah J. Maas');
    expect(cover.thumbnail).toBe('https://covers.openlibrary.org/b/id/13312488-M.jpg');
  });

  it('skips docs with no cover_i (they resolve to a blank pixel)', () => {
    const json = {
      docs: [
        { key: '/works/A', title: 'No Cover' },
        { key: '/works/B', title: 'Has Cover', cover_i: 42 },
      ],
    };
    const results = parseOpenLibraryResults(json);
    expect(results).toHaveLength(1);
    expect(results[0].id).toBe('/works/B');
  });

  it('de-dupes repeated cover ids', () => {
    const json = {
      docs: [
        { key: '/works/A', cover_i: 7 },
        { key: '/works/B', cover_i: 7 },
      ],
    };
    expect(parseOpenLibraryResults(json)).toHaveLength(1);
  });

  it('handles a missing author_name array', () => {
    const json = { docs: [{ key: '/works/A', title: 'X', cover_i: 1 }] };
    expect(parseOpenLibraryResults(json)[0].authors).toBe('');
  });
});

describe('openLibrarySearchUrl', () => {
  it('encodes the title and adds author when present', () => {
    const url = openLibrarySearchUrl('Throne of Glass', 'Maas');
    expect(url.startsWith('https://openlibrary.org/search.json?')).toBe(true);
    expect(decodeURIComponent(url)).toContain('title=Throne of Glass');
    expect(decodeURIComponent(url)).toContain('author=Maas');
  });

  it('omits author when none given', () => {
    expect(decodeURIComponent(openLibrarySearchUrl('Dune'))).not.toContain('author=');
  });
});

describe('coverImageUrl', () => {
  it('builds sized cover urls', () => {
    expect(coverImageUrl(99, 'L')).toBe('https://covers.openlibrary.org/b/id/99-L.jpg');
  });
});

describe('dedupeCovers', () => {
  it('keeps the first occurrence and drops repeated ids or urls', () => {
    const covers: CoverResult[] = [
      { id: 'apple-1', title: 'A', authors: '', thumbnail: 'https://a/1.jpg' },
      { id: 'apple-1', title: 'A dup id', authors: '', thumbnail: 'https://a/2.jpg' },
      { id: 'ol-1', title: 'B dup url', authors: '', thumbnail: 'https://a/1.jpg' },
      { id: 'ol-2', title: 'C', authors: '', thumbnail: 'https://a/3.jpg' },
    ];
    const out = dedupeCovers(covers);
    expect(out.map((c) => c.id)).toEqual(['apple-1', 'ol-2']);
  });
});
