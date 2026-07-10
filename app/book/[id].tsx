import { useEffect, useMemo, useRef, useState } from 'react';
import { View, Text, StyleSheet, Alert, Pressable } from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { useLocalSearchParams, useRouter, Stack } from 'expo-router';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import { Screen, Card, TextField, Button, SegmentedControl, EmptyState, SwipeableRow } from '@/components/ui';
import { ReferenceTab } from '@/components/reference/ReferenceTab';
import { BookCover } from '@/components/BookCover';
import { bookQuery, markFinished, markReading, deleteBook } from '@/features/books/queries';
import { deleteCoverFile } from '@/features/books/cover';
import {
  chapterNotesQuery,
  addChapterNote,
  updateChapterNote,
  deleteChapterNote,
} from '@/features/chapters/queries';
import type { Book, ChapterNote } from '@/db/schema';
import { colors, spacing, type } from '@/theme';

const TABS = ['Chapters', 'Reference'];

/** A request to reveal a chapter note, carried across the tab switch. The nonce
 *  lets the same chapter be re-targeted (tapping the same tag twice). */
type JumpTarget = { chapter: number; nonce: number };

export default function BookDetail() {
  const { id, tab: tabParam, jump: jumpParam } = useLocalSearchParams<{
    id: string;
    tab?: string;
    jump?: string;
  }>();
  const router = useRouter();
  const bookId = Number(id);
  const [tab, setTab] = useState(tabParam === 'Reference' ? 'Reference' : TABS[0]);
  const [jump, setJump] = useState<JumpTarget | null>(null);
  const jumpNonce = useRef(0);

  const { data: bookRows } = useLiveQuery(bookQuery(bookId));
  const book = (bookRows?.[0] as Book | undefined) ?? undefined;

  // Tapping a chapter tag in Reference brings the reader to that note.
  function jumpToChapter(chapter: number) {
    jumpNonce.current += 1;
    setJump({ chapter, nonce: jumpNonce.current });
    setTab('Chapters');
  }

  // Arriving from a search result that points at a specific chapter note.
  useEffect(() => {
    if (jumpParam) jumpToChapter(Number(jumpParam));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [jumpParam]);

  function confirmDeleteBook() {
    if (!book) return;
    Alert.alert('Delete this book?', 'Its chapter notes and reference entries go too. This can\'t be undone.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          const coverUri = book.coverUri;
          await deleteBook(bookId);
          deleteCoverFile(coverUri); // tidy up the stored image file
          router.back();
        },
      },
    ]);
  }

  function openActions() {
    if (!book) return;
    const finishAction =
      book.status === 'finished'
        ? { text: 'Move back to reading', onPress: () => markReading(bookId) }
        : { text: 'Mark as finished', onPress: () => markFinished(bookId) };
    Alert.alert(book.title, undefined, [
      { text: 'Edit details', onPress: () => router.push({ pathname: '/book/edit', params: { id: String(bookId) } }) },
      finishAction,
      { text: 'Delete book', style: 'destructive', onPress: confirmDeleteBook },
      { text: 'Cancel', style: 'cancel' },
    ]);
  }

  return (
    <Screen>
      <Stack.Screen
        options={{
          title: book?.title ?? 'Book',
          headerRight: () =>
            book ? (
              <Pressable onPress={openActions} hitSlop={12}>
                <Text style={styles.headerAction}>Edit</Text>
              </Pressable>
            ) : null,
        }}
      />
      <View style={styles.header}>
        <BookCover uri={book?.coverUri} width={56} />
        <View style={{ flex: 1 }}>
          <View style={styles.titleRow}>
            <Text style={[styles.title, { flex: 1 }]}>{book?.title}</Text>
            {book?.status === 'finished' ? <Text style={styles.finishedTag}>Finished</Text> : null}
          </View>
          {book?.author ? <Text style={styles.author}>{book.author}</Text> : null}
        </View>
      </View>

      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      <View style={{ flex: 1, marginTop: spacing.md }}>
        {tab === 'Chapters' ? (
          <ChaptersTab bookId={bookId} jumpTarget={jump} onJumpConsumed={() => setJump(null)} />
        ) : (
          <ReferenceTab bookId={bookId} onJumpToChapter={jumpToChapter} />
        )}
      </View>
    </Screen>
  );
}

function ChaptersTab({
  bookId,
  jumpTarget,
  onJumpConsumed,
}: {
  bookId: number;
  jumpTarget: JumpTarget | null;
  onJumpConsumed: () => void;
}) {
  const { data } = useLiveQuery(chapterNotesQuery(bookId));
  const notes = (data ?? []) as ChapterNote[];
  const [adding, setAdding] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [highlightChapter, setHighlightChapter] = useState<number | null>(null);

  // Scroll-to-note support for jumps from the Reference tab or a search result.
  const scrollRef = useRef<ScrollView>(null);
  const offsets = useRef<Record<number, number>>({});
  // A jump can land before its target note has laid out (fresh tab mount, or the
  // list still loading). When that happens we stash the chapter here and let the
  // note's own onLayout perform the scroll once its position is known.
  const pendingJump = useRef<number | null>(null);

  function scrollToOffset(y: number) {
    scrollRef.current?.scrollTo({ y: Math.max(0, y - spacing.md), animated: true });
  }

  useEffect(() => {
    if (!jumpTarget) return;
    const { chapter } = jumpTarget;
    setHighlightChapter(chapter);
    onJumpConsumed();
    const y = offsets.current[chapter];
    if (y != null) scrollToOffset(y);
    else pendingJump.current = chapter; // scroll when it lays out
    const timer = setTimeout(() => setHighlightChapter(null), 1800);
    return () => clearTimeout(timer);
  }, [jumpTarget?.nonce]);

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
      ref={scrollRef}
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

      {notes.map((note) => (
        <View
          key={note.id}
          onLayout={(e) => {
            const y = e.nativeEvent.layout.y;
            offsets.current[note.chapterNumber] = y;
            if (pendingJump.current === note.chapterNumber) {
              pendingJump.current = null;
              // Defer one frame so the ScrollView's content size is settled.
              requestAnimationFrame(() => scrollToOffset(y));
            }
          }}
        >
          {editingId === note.id ? (
            <NoteForm
              bookId={bookId}
              defaultChapter={nextChapter}
              initial={note}
              onDone={() => setEditingId(null)}
            />
          ) : (
            <SwipeableRow onEdit={() => startEditing(note)} onDelete={() => confirmDelete(note)}>
              <Card style={highlightChapter === note.chapterNumber ? styles.highlighted : undefined}>
                <Text style={styles.chapterLabel}>
                  Chapter {note.chapterNumber}
                  {note.title ? ` — ${note.title}` : ''}
                </Text>
                <Text style={styles.body}>{note.body || '(empty)'}</Text>
                <Text style={styles.hint}>Swipe left to edit or delete</Text>
              </Card>
            </SwipeableRow>
          )}
        </View>
      ))}
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
  header: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, paddingTop: spacing.sm, paddingBottom: spacing.md },
  titleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  headerAction: { ...type.label, color: colors.accent },
  finishedTag: { ...type.caption, color: colors.success, fontWeight: '600' },
  author: { ...type.body, color: colors.inkSoft, marginTop: 2 },
  chapterLabel: { ...type.heading, color: colors.accent, marginBottom: spacing.xs },
  body: { ...type.body, color: colors.ink },
  hint: { ...type.caption, color: colors.inkFaint, marginTop: spacing.sm },
  highlighted: { borderColor: colors.accent, borderWidth: 2 },
});
