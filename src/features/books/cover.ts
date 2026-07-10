import { File, Directory, Paths } from 'expo-file-system';

/**
 * Local persistence for cover images. Covers are chosen from Google Books
 * (coverSearch.ts) and downloaded here into the app's document directory, so a
 * cover keeps working offline and needs no repeat network call at read time.
 */

const COVERS_DIR = 'covers';

/** Download a remote cover url into document/covers and return the stored uri. */
export async function downloadCover(url: string): Promise<string> {
  const dir = new Directory(Paths.document, COVERS_DIR);
  if (!dir.exists) dir.create({ intermediates: true });
  const dest = new File(dir, `${Date.now()}.jpg`);
  const file = await File.downloadFileAsync(url, dest);
  return file.uri;
}

/** Delete a stored cover file. Safe to call with a missing/absent uri. */
export function deleteCoverFile(uri?: string | null) {
  if (!uri) return;
  try {
    const file = new File(uri);
    if (file.exists) file.delete();
  } catch {
    // Already gone or unreadable — nothing to clean up.
  }
}
