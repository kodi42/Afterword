import { useState } from 'react';
import {
  View,
  Pressable,
  Text,
  Image,
  ActivityIndicator,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Screen, TextField, Button } from '@/components/ui';
import { BookCover } from '@/components/BookCover';
import { searchBookCovers, type CoverResult } from '@/features/books/coverSearch';
import { downloadCover } from '@/features/books/cover';
import { colors, radius, spacing, type } from '@/theme';

export type BookFormValues = {
  title: string;
  author: string | null;
  totalChapters: number | null;
  coverUri: string | null;
};

/**
 * The book title/author/chapters form, shared by the add-book and edit-book
 * modals. Title is the only required field.
 *
 * Cover images are found by searching Apple Books then Open Library for the title
 * (no camera roll, no API key). The picked thumbnail is only downloaded +
 * persisted on save, so we don't fetch covers the reader never keeps.
 */
export function BookForm({
  initial,
  submitLabel,
  onSubmit,
}: {
  initial?: Partial<BookFormValues>;
  submitLabel: string;
  onSubmit: (values: BookFormValues) => Promise<void>;
}) {
  const insets = useSafeAreaInsets();
  const [title, setTitle] = useState(initial?.title ?? '');
  const [author, setAuthor] = useState(initial?.author ?? '');
  const [totalChapters, setTotalChapters] = useState(
    initial?.totalChapters != null ? String(initial.totalChapters) : '',
  );

  // The already-saved cover (a local file uri), an as-yet-undownloaded remote
  // pick, and whether the reader cleared the cover. Resolved on save.
  const [savedCover] = useState<string | null>(initial?.coverUri ?? null);
  const [pickedUrl, setPickedUrl] = useState<string | null>(null);
  const [removed, setRemoved] = useState(false);

  const [results, setResults] = useState<CoverResult[]>([]);
  const [searching, setSearching] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // What the preview shows: a fresh remote pick wins, else the saved cover
  // (unless the reader removed it).
  const previewUri = pickedUrl ?? (removed ? null : savedCover);

  async function findCovers() {
    if (!title.trim()) return;
    setSearching(true);
    setMessage(null);
    try {
      const found = await searchBookCovers(title, author);
      setResults(found);
      if (found.length === 0) {
        setMessage('No covers found — try refining the title.');
      } else {
        // Surface the first (best) result as the default; others are alternatives.
        setPickedUrl(found[0].thumbnail);
        setRemoved(false);
      }
    } catch {
      setMessage('Could not reach the cover service. Check your connection.');
    } finally {
      setSearching(false);
    }
  }

  function selectResult(result: CoverResult) {
    setPickedUrl(result.thumbnail);
    setRemoved(false);
  }

  function removeCover() {
    setPickedUrl(null);
    setRemoved(true);
    setResults([]);
    setMessage(null);
  }

  async function save() {
    if (!title.trim()) return;
    setSaving(true);
    setMessage(null);
    try {
      let coverUri = savedCover;
      if (pickedUrl) coverUri = await downloadCover(pickedUrl);
      else if (removed) coverUri = null;

      await onSubmit({
        title: title.trim(),
        author: author.trim() || null,
        totalChapters: totalChapters.trim() ? Number(totalChapters) : null,
        coverUri,
      });
    } catch {
      setMessage('Could not download that cover. Try another, or save without one.');
      setSaving(false);
    }
  }

  return (
    <Screen>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
        <ScrollView
          contentContainerStyle={{ paddingTop: spacing.md, paddingBottom: spacing.lg }}
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="on-drag"
        >
          <View style={styles.coverRow}>
            <BookCover uri={previewUri} width={72} />
            <View style={{ flex: 1, gap: spacing.xs }}>
              <Pressable onPress={findCovers} disabled={!title.trim() || searching} hitSlop={8}>
                <Text style={[styles.coverAction, (!title.trim() || searching) && styles.disabled]}>
                  {previewUri ? 'Find a different cover' : 'Find cover'}
                </Text>
              </Pressable>
              <Text style={styles.coverHint}>Searches Apple Books, then Open Library.</Text>
              {previewUri ? (
                <Pressable onPress={removeCover} hitSlop={8}>
                  <Text style={styles.coverRemove}>Remove</Text>
                </Pressable>
              ) : null}
            </View>
            {searching ? <ActivityIndicator color={colors.accent} /> : null}
          </View>

          {message ? <Text style={styles.message}>{message}</Text> : null}

          {results.length > 0 ? (
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.resultStrip}
              keyboardShouldPersistTaps="handled"
            >
              {results.map((r) => {
                const selected = pickedUrl === r.thumbnail;
                return (
                  <Pressable key={r.id} onPress={() => selectResult(r)} style={[styles.result, selected && styles.resultSelected]}>
                    <Image source={{ uri: r.thumbnail }} style={styles.resultImg} resizeMode="cover" />
                  </Pressable>
                );
              })}
            </ScrollView>
          ) : null}

          <View style={{ marginTop: spacing.md }}>
            <TextField label="Title" value={title} onChangeText={setTitle} placeholder="Throne of Glass" autoFocus />
            <TextField label="Author (optional)" value={author} onChangeText={setAuthor} placeholder="Sarah J. Maas" />
            <TextField
              label="Total chapters (optional)"
              value={totalChapters}
              onChangeText={setTotalChapters}
              placeholder="59"
              keyboardType="number-pad"
            />
          </View>
        </ScrollView>
        <View style={{ paddingBottom: insets.bottom + spacing.md }}>
          <Button label={submitLabel} onPress={save} disabled={!title.trim()} loading={saving} />
        </View>
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  coverRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginBottom: spacing.sm },
  coverAction: { ...type.label, color: colors.accent },
  coverHint: { ...type.caption, color: colors.inkFaint },
  coverRemove: { ...type.caption, color: colors.danger },
  disabled: { opacity: 0.4 },
  message: { ...type.caption, color: colors.inkSoft, marginBottom: spacing.sm },
  resultStrip: { gap: spacing.sm, paddingVertical: spacing.xs, paddingRight: spacing.md },
  result: { borderRadius: radius.sm, borderWidth: 2, borderColor: 'transparent' },
  resultSelected: { borderColor: colors.accent },
  resultImg: { width: 66, height: 99, borderRadius: radius.sm - 2, backgroundColor: colors.surfaceAlt },
});
