import { useMemo, useState } from 'react';
import { View, Text, ScrollView, StyleSheet, Alert } from 'react-native';
import { useLocalSearchParams, Stack } from 'expo-router';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import { Screen, Card, TextField, Button, SegmentedControl, EmptyState } from '@/components/ui';
import { bookQuery } from '@/features/books/queries';
import {
  chapterNotesQuery,
  addChapterNote,
  updateChapterNote,
  deleteChapterNote,
} from '@/features/chapters/queries';
import type { Book, ChapterNote } from '@/db/schema';
import { colors, spacing, type } from '@/theme';

const TABS = ['Chapters', 'Reference'];

export default function BookDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const bookId = Number(id);
  const [tab, setTab] = useState(TABS[0]);

  const { data: bookRows } = useLiveQuery(bookQuery(bookId));
  const book = (bookRows?.[0] as Book | undefined) ?? undefined;

  return (
    <Screen>
      <Stack.Screen options={{ title: book?.title ?? 'Book' }} />
      <View style={{ paddingTop: spacing.sm, paddingBottom: spacing.md }}>
        <Text style={styles.title}>{book?.title}</Text>
        {book?.author ? <Text style={styles.author}>{book.author}</Text> : null}
      </View>

      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      <View style={{ flex: 1, marginTop: spacing.md }}>
        {tab === 'Chapters' ? (
          <ChaptersTab bookId={bookId} />
        ) : (
          <EmptyState
            title="Reference is coming in Phase 3"
            hint="Characters, plot threads, and predictions will live here. The tables already exist in the schema."
          />
        )}
      </View>
    </Screen>
  );
}

function ChaptersTab({ bookId }: { bookId: number }) {
  const { data } = useLiveQuery(chapterNotesQuery(bookId));
  const notes = (data ?? []) as ChapterNote[];
  const [adding, setAdding] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);

  // notes come back newest-chapter-first; the next chapter is one past the max.
  const nextChapter = useMemo(() => {
    if (notes.length === 0) return 1;
    return Math.max(...notes.map((n) => n.chapterNumber)) + 1;
  }, [notes]);

  function startAdding() {
    setEditingId(null);
    setAdding(true);
  }

  function startEditing(note: ChapterNote) {
    setAdding(false);
    setEditingId(note.id);
  }

  function promptActions(note: ChapterNote) {
    Alert.alert(
      `Chapter ${note.chapterNumber}${note.title ? ` — ${note.title}` : ''}`,
      undefined,
      [
        { text: 'Edit', onPress: () => startEditing(note) },
        { text: 'Delete', style: 'destructive', onPress: () => confirmDelete(note) },
        { text: 'Cancel', style: 'cancel' },
      ],
    );
  }

  function confirmDelete(note: ChapterNote) {
    Alert.alert('Delete this note?', "This can't be undone.", [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          if (editingId === note.id) setEditingId(null);
          deleteChapterNote(note.id);
        },
      },
    ]);
  }

  return (
    <ScrollView
      contentContainerStyle={{ paddingBottom: 40, gap: spacing.sm }}
      keyboardShouldPersistTaps="handled"
      keyboardDismissMode="on-drag"
      automaticallyAdjustKeyboardInsets
    >
      {adding ? (
        <NoteForm bookId={bookId} defaultChapter={nextChapter} onDone={() => setAdding(false)} />
      ) : (
        <Button label={`Add note for chapter ${nextChapter}`} onPress={startAdding} />
      )}

      {notes.length === 0 && !adding ? (
        <EmptyState title="No chapter notes yet" hint="Finish a chapter, then jot down what happened and what you thought." />
      ) : null}

      {notes.map((note) =>
        editingId === note.id ? (
          <NoteForm
            key={note.id}
            bookId={bookId}
            defaultChapter={nextChapter}
            initial={note}
            onDone={() => setEditingId(null)}
          />
        ) : (
          <Card key={note.id} onLongPress={() => promptActions(note)}>
            <Text style={styles.chapterLabel}>
              Chapter {note.chapterNumber}
              {note.title ? ` — ${note.title}` : ''}
            </Text>
            <Text style={styles.body}>{note.body || '(empty)'}</Text>
            <Text style={styles.hint}>Long-press to edit or delete</Text>
          </Card>
        ),
      )}
    </ScrollView>
  );
}

function NoteForm({
  bookId,
  defaultChapter,
  initial,
  onDone,
}: {
  bookId: number;
  defaultChapter: number;
  initial?: ChapterNote;
  onDone: () => void;
}) {
  const isEdit = !!initial;
  const [chapter, setChapter] = useState(String(initial?.chapterNumber ?? defaultChapter));
  const [title, setTitle] = useState(initial?.title ?? '');
  const [body, setBody] = useState(initial?.body ?? '');
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    const chapterNumber = Number(chapter) || initial?.chapterNumber || defaultChapter;
    if (isEdit && initial) {
      await updateChapterNote(initial.id, {
        chapterNumber,
        title: title.trim() || null,
        body: body.trim(),
      });
    } else {
      await addChapterNote({
        bookId,
        chapterNumber,
        title: title.trim() || null,
        body: body.trim(),
      });
    }
    setSaving(false);
    onDone();
  }

  return (
    <Card style={{ gap: 0 }}>
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <View style={{ width: 90 }}>
          <TextField label="Chapter" value={chapter} onChangeText={setChapter} keyboardType="number-pad" />
        </View>
        <View style={{ flex: 1 }}>
          <TextField label="Title (optional)" value={title} onChangeText={setTitle} placeholder="The trial begins" />
        </View>
      </View>
      <TextField
        label="What happened / your thoughts"
        value={body}
        onChangeText={setBody}
        placeholder="Write freely..."
        multiline
        autoFocus
      />
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <View style={{ flex: 1 }}>
          <Button label="Cancel" variant="ghost" onPress={onDone} />
        </View>
        <View style={{ flex: 1 }}>
          <Button label={isEdit ? 'Save changes' : 'Save note'} onPress={save} loading={saving} />
        </View>
      </View>
    </Card>
  );
}

const styles = StyleSheet.create({
  title: { ...type.display, color: colors.ink },
  author: { ...type.body, color: colors.inkSoft, marginTop: 2 },
  chapterLabel: { ...type.heading, color: colors.accent, marginBottom: spacing.xs },
  body: { ...type.body, color: colors.ink },
  hint: { ...type.caption, color: colors.inkFaint, marginTop: spacing.sm },
});
