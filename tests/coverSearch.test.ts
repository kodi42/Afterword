import { describe, it, expect } from 'vitest';
import { parseCoverResults, coverSearchUrl, coverImageUrl } from '@/features/books/coverSearch';

describe('parseCoverResults', () => {
  it('returns [] for a non-search response', () => {
    expect(parseCoverResults({})).toEqual([]);
    expect(parseCoverResults(null)).toEqual([]);
  });

  it('maps docs with a cover to https cover-image urls', () => {
    const json = {
      docs: [
        { key: '/works/OL1W', title: 'Throne of Glass', author_name: ['Sarah J. Maas'], cover_i: 13312488 },
      ],
    };
    const [cover] = parseCoverResults(json);
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
    const results = parseCoverResults(json);
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
    expect(parseCoverResults(json)).toHaveLength(1);
  });

  it('handles a missing author_name array', () => {
    const json = { docs: [{ key: '/works/A', title: 'X', cover_i: 1 }] };
    expect(parseCoverResults(json)[0].authors).toBe('');
  });
});

describe('coverSearchUrl', () => {
  it('encodes the title and adds author when present', () => {
    const url = coverSearchUrl('Throne of Glass', 'Maas');
    expect(url.startsWith('https://openlibrary.org/search.json?')).toBe(true);
    expect(decodeURIComponent(url)).toContain('title=Throne of Glass');
    expect(decodeURIComponent(url)).toContain('author=Maas');
  });

  it('omits author when none given', () => {
    expect(decodeURIComponent(coverSearchUrl('Dune'))).not.toContain('author=');
  });
});

describe('coverImageUrl', () => {
  it('builds sized cover urls', () => {
    expect(coverImageUrl(99, 'L')).toBe('https://covers.openlibrary.org/b/id/99-L.jpg');
  });
});
