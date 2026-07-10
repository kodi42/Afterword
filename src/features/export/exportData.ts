import { File, Paths } from 'expo-file-system';
import * as Sharing from 'expo-sharing';
import { buildExportJSON } from './buildExport';

/**
 * One-shot data export, for migrating this Expo library into the native SwiftUI
 * app. Writes the JSON payload (built in buildExport.ts) to a file and opens the
 * share sheet so it can be saved to Files or AirDropped. The native app's Import
 * reads this same schema.
 *
 * Covers are local image files and don't travel; the native app can re-fetch a
 * cover per book. Highlights aren't exported directly — they live as `* ` lines
 * inside note bodies, so exporting the notes carries them across.
 */
export async function exportAllData(): Promise<boolean> {
  const json = await buildExportJSON();

  const file = new File(Paths.cache, 'afterword-export.json');
  if (file.exists) file.delete();
  file.create();
  file.write(json);

  if (!(await Sharing.isAvailableAsync())) return false;
  await Sharing.shareAsync(file.uri, {
    mimeType: 'application/json',
    UTI: 'public.json',
    dialogTitle: 'Export Afterword data',
  });
  return true;
}
