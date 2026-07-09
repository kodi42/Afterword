import { useMemo } from 'react';
import { FlatList, Pressable, Text, View, StyleSheet } from 'react-native';
import { Link, useRouter } from 'expo-router';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import { Screen, Card, EmptyState } from '@/components/ui';
import { booksQuery } from '@/features/books/queries';
import type { Book } from '@/db/schema';
import { colors, radius, spacing, type } from '@/theme';

export default function Library() {
  const router = useRouter();
  const { data: books } = useLiveQuery(booksQuery);

  const { reading, finished } = useMemo(() => {
    const all = (books ?? []) as Book[];
    return {
      reading: all.filter((b) => b.status !== 'finished'),
      finished: all.filter((b) => b.status === 'finished'),
    };
  }, [books]);

  const sections = [
    { key: 'reading', label: 'Currently reading', items: reading },
    { key: 'finished', label: 'Finished', items: finished },
  ].filter((s) => s.items.length > 0);

  return (
    <Screen>
      {(!books || books.length === 0) ? (
        <EmptyState
          title="No books yet"
          hint="Add the book you're reading now and start logging notes after each chapter."
        />
      ) : (
        <FlatList
          data={sections}
          keyExtractor={(s) => s.key}
          contentContainerStyle={{ paddingBottom: 96, paddingTop: spacing.sm }}
          renderItem={({ item: section }) => (
            <View style={{ marginBottom: spacing.lg }}>
              <Text style={styles.sectionLabel}>{section.label}</Text>
              <View style={{ gap: spacing.sm }}>
                {section.items.map((book) => (
                  <BookRow key={book.id} book={book} />
                ))}
              </View>
            </View>
          )}
        />
      )}

      <Pressable style={styles.fab} onPress={() => router.push('/book/new')}>
        <Text style={styles.fabLabel}>＋</Text>
      </Pressable>
    </Screen>
  );
}

function BookRow({ book }: { book: Book }) {
  const progress =
    book.currentChapter && book.totalChapters
      ? `Ch ${book.currentChapter} of ${book.totalChapters}`
      : book.currentChapter
        ? `Ch ${book.currentChapter}`
        : null;

  return (
    <Link href={{ pathname: '/book/[id]', params: { id: String(book.id) } }} asChild>
      <Card>
        <Text style={styles.bookTitle} numberOfLines={1}>{book.title}</Text>
        {book.author ? <Text style={styles.bookAuthor}>{book.author}</Text> : null}
        {progress ? <Text style={styles.progress}>{progress}</Text> : null}
      </Card>
    </Link>
  );
}

const styles = StyleSheet.create({
  sectionLabel: { ...type.label, color: colors.inkSoft, marginBottom: spacing.sm, textTransform: 'uppercase', letterSpacing: 0.5 },
  bookTitle: { ...type.title, color: colors.ink },
  bookAuthor: { ...type.body, color: colors.inkSoft, marginTop: 2 },
  progress: { ...type.caption, color: colors.accent, marginTop: spacing.sm },
  fab: {
    position: 'absolute',
    right: spacing.lg,
    bottom: spacing.xl,
    width: 60,
    height: 60,
    borderRadius: radius.pill,
    backgroundColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 4 },
    elevation: 4,
  },
  fabLabel: { color: '#fff', fontSize: 30, lineHeight: 34, marginTop: -2 },
});
