import { describe, it, expect } from 'vitest';
import { parseCoverResults, coverSearchUrl } from '@/features/books/coverSearch';

describe('parseCoverResults', () => {
  it('returns [] for a non-Books response', () => {
    expect(parseCoverResults({})).toEqual([]);
    expect(parseCoverResults(null)).toEqual([]);
  });

  it('maps volumes to covers and upgrades http thumbnails to https', () => {
    const json = {
      items: [
        {
          id: 'abc',
          volumeInfo: {
            title: 'Throne of Glass',
            authors: ['Sarah J. Maas'],
            imageLinks: { thumbnail: 'http://books.google.com/x?id=abc&img=1' },
          },
        },
      ],
    };
    const [cover] = parseCoverResults(json);
    expect(cover.id).toBe('abc');
    expect(cover.title).toBe('Throne of Glass');
    expect(cover.authors).toBe('Sarah J. Maas');
    expect(cover.thumbnail.startsWith('https://')).toBe(true);
  });

  it('skips volumes without any image link', () => {
    const json = {
      items: [
        { id: '1', volumeInfo: { title: 'No Cover' } },
        { id: '2', volumeInfo: { title: 'Has Cover', imageLinks: { smallThumbnail: 'https://x/y.jpg' } } },
      ],
    };
    const results = parseCoverResults(json);
    expect(results).toHaveLength(1);
    expect(results[0].id).toBe('2');
  });

  it('falls back to smallThumbnail and de-dupes identical thumbnails', () => {
    const json = {
      items: [
        { id: '1', volumeInfo: { imageLinks: { thumbnail: 'https://same.jpg' } } },
        { id: '2', volumeInfo: { imageLinks: { thumbnail: 'https://same.jpg' } } },
      ],
    };
    expect(parseCoverResults(json)).toHaveLength(1);
  });

  it('handles a missing authors array', () => {
    const json = { items: [{ id: '1', volumeInfo: { title: 'X', imageLinks: { thumbnail: 'https://x.jpg' } } }] };
    expect(parseCoverResults(json)[0].authors).toBe('');
  });
});

describe('coverSearchUrl', () => {
  it('encodes intitle and adds inauthor when present', () => {
    const url = coverSearchUrl('Throne of Glass', 'Maas');
    expect(url).toContain('intitle');
    expect(decodeURIComponent(url)).toContain('intitle:Throne of Glass');
    expect(decodeURIComponent(url)).toContain('inauthor:Maas');
  });

  it('omits inauthor when no author', () => {
    expect(decodeURIComponent(coverSearchUrl('Dune'))).not.toContain('inauthor');
  });
});
