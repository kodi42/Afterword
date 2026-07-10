import { useEffect, useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { useRouter, Stack } from 'expo-router';
import { Screen, Card, TextField, EmptyState } from '@/components/ui';
import {
  searchAll,
  countResults,
  type SearchResults,
  type NoteHit,
  type CharacterHit,
  type PredictionHit,
} from '@/features/search/queries';
import { colors, spacing, type } from '@/theme';

const EMPTY: SearchResults = { notes: [], characters: [], predictions: [] };

export default function Search() {
  const router = useRouter();
  const [term, setTerm] = useState('');
  const [results, setResults] = useState<SearchResults>(EMPTY);

  // Re-run on every keystroke; ignore stale responses if typing races the query.
  useEffect(() => {
    let cancelled = false;
    searchAll(term).then((r) => {
      if (!cancelled) setResults(r);
    });
    return () => {
      cancelled = true;
    };
  }, [term]);

  const trimmed = term.trim();
  const total = countResults(results);

  function openBook(bookId: number, tab: 'Chapters' | 'Reference', jump?: number) {
    router.push({
      pathname: '/book/[id]',
      params: { id: String(bookId), tab, ...(jump != null ? { jump: String(jump) } : {}) },
    });
  }

  return (
    <Screen>
      <Stack.Screen options={{ title: 'Search' }} />
      <View style={{ paddingTop: spacing.sm }}>
        <TextField
          value={term}
          onChangeText={setTerm}
          placeholder="Search notes and reference…"
          autoFocus
          autoCapitalize="none"
          autoCorrect={false}
          returnKeyType="search"
        />
      </View>

      {!trimmed ? (
        <EmptyState title="Search across every book" hint="Chapter notes, characters, and predictions — all of it, at once." />
      ) : total === 0 ? (
        <EmptyState title="No matches" hint={`Nothing found for “${trimmed}”.`} />
      ) : (
        <ScrollView contentContainerStyle={{ paddingBottom: 40, gap: spacing.md }} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag">
          <Group label="Chapter notes" count={results.notes.length}>
            {results.notes.map((n) => (
              <NoteResult key={n.noteId} hit={n} onPress={() => openBook(n.bookId, 'Chapters', n.chapterNumber)} />
            ))}
          </Group>
          <Group label="Characters" count={results.characters.length}>
            {results.characters.map((c) => (
              <CharacterResult key={c.id} hit={c} onPress={() => openBook(c.bookId, 'Reference')} />
            ))}
          </Group>
          <Group label="Predictions" count={results.predictions.length}>
            {results.predictions.map((p) => (
              <PredictionResult key={p.id} hit={p} onPress={() => openBook(p.bookId, 'Reference')} />
            ))}
          </Group>
        </ScrollView>
      )}
    </Screen>
  );
}

function Group({ label, count, children }: { label: string; count: number; children: React.ReactNode }) {
  if (count === 0) return null;
  return (
    <View style={{ gap: spacing.sm }}>
      <Text style={styles.groupLabel}>
        {label} · {count}
      </Text>
      {children}
    </View>
  );
}

function NoteResult({ hit, onPress }: { hit: NoteHit; onPress: () => void }) {
  return (
    <Card onPress={onPress}>
      <Text style={styles.context}>{hit.bookTitle}</Text>
      <Text style={styles.heading}>
        Chapter {hit.chapterNumber}
        {hit.title ? ` — ${hit.title}` : ''}
      </Text>
      <Text style={styles.body} numberOfLines={2}>
        {hit.body || '(empty)'}
      </Text>
    </Card>
  );
}

function CharacterResult({ hit, onPress }: { hit: CharacterHit; onPress: () => void }) {
  return (
    <Card onPress={onPress}>
      <Text style={styles.context}>{hit.bookTitle}</Text>
      <Text style={styles.heading}>{hit.name}</Text>
      {hit.description ? (
        <Text style={styles.body} numberOfLines={2}>
          {hit.description}
        </Text>
      ) : null}
    </Card>
  );
}

function PredictionResult({ hit, onPress }: { hit: PredictionHit; onPress: () => void }) {
  return (
    <Card onPress={onPress}>
      <Text style={styles.context}>{hit.bookTitle}</Text>
      <Text style={styles.body} numberOfLines={2}>
        {hit.prompt}
      </Text>
      <Text style={styles.context}>{hit.status === 'answered' ? 'Answered' : 'Open'}</Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  groupLabel: { ...type.label, color: colors.inkSoft, textTransform: 'uppercase', letterSpacing: 0.5 },
  context: { ...type.caption, color: colors.inkFaint },
  heading: { ...type.heading, color: colors.accent, marginTop: 2, marginBottom: spacing.xs },
  body: { ...type.body, color: colors.ink },
});
