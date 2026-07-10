import { useMemo, useState } from 'react';
import { View, Text, StyleSheet, Alert, Pressable } from 'react-native';
import { ScrollView } from 'react-native-gesture-handler';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import { Card, TextField, Button, SegmentedControl, EmptyState, SwipeableRow } from '@/components/ui';
import {
  charactersQuery,
  createCharacter,
  updateCharacter,
  deleteCharacter,
  predictionsQuery,
  createPrediction,
  updatePrediction,
  deletePrediction,
  answerPrediction,
  reopenPrediction,
} from '@/features/reference/queries';
import {
  aliasesQuery,
  buildAliasMap,
  mergeCharacter,
  unmergeCharacter,
  answerSurfacedPrediction,
  predictionKeys,
} from '@/features/surface/queries';
import {
  parseMarkers,
  type SurfacedCharacter,
  type SurfacedHighlight,
  type SurfacedPrediction,
} from '@/features/surface/parser';
import { chapterNotesQuery } from '@/features/chapters/queries';
import type { Character, Prediction, ChapterNote, CharacterAlias } from '@/db/schema';
import { colors, radius, spacing, type } from '@/theme';

const SECTIONS = ['Characters', 'Highlights', 'Predictions'];

/**
 * The Reference tab. Two layers stacked in each sub-section:
 *   - surfaced entries, computed live from `- Name:` / `*` / `?` markers in the
 *     chapter notes (Phase 4), and
 *   - manual entries typed straight in (the Phase 3 baseline / escape hatch).
 * A search box filters the active section across both layers.
 */
export function ReferenceTab({
  bookId,
  onJumpToChapter,
}: {
  bookId: number;
  onJumpToChapter?: (chapter: number) => void;
}) {
  const [section, setSection] = useState(SECTIONS[0]);
  const [query, setQuery] = useState('');

  const { data: noteData } = useLiveQuery(chapterNotesQuery(bookId));
  const { data: aliasData } = useLiveQuery(aliasesQuery(bookId));
  const notes = (noteData ?? []) as ChapterNote[];
  const aliases = (aliasData ?? []) as CharacterAlias[];

  const parsed = useMemo(
    () => parseMarkers(notes, buildAliasMap(aliases)),
    [notes, aliases],
  );

  const q = query.trim().toLowerCase();

  return (
    <View style={{ flex: 1, gap: spacing.md }}>
      <TextField
        value={query}
        onChangeText={setQuery}
        placeholder="Search reference…"
        autoCapitalize="none"
        autoCorrect={false}
        style={{ marginBottom: 0 }}
      />
      <SegmentedControl options={SECTIONS} value={section} onChange={setSection} />
      {section === 'Characters' ? (
        <CharactersSection bookId={bookId} q={q} surfaced={parsed.characters} aliases={aliases} onJump={onJumpToChapter} />
      ) : section === 'Highlights' ? (
        <HighlightsSection q={q} highlights={parsed.highlights} onJump={onJumpToChapter} />
      ) : (
        <PredictionsSection bookId={bookId} q={q} surfaced={parsed.predictions} onJump={onJumpToChapter} />
      )}
    </View>
  );
}

/* ======================= Characters ======================= */

function CharactersSection({
  bookId,
  q,
  surfaced,
  aliases,
  onJump,
}: {
  bookId: number;
  q: string;
  surfaced: SurfacedCharacter[];
  aliases: CharacterAlias[];
  onJump?: (chapter: number) => void;
}) {
  const { data } = useLiveQuery(charactersQuery(bookId));
  const manual = (data ?? []) as Character[];
  const [adding, setAdding] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);

  const shownSurfaced = surfaced.filter(
    (c) => !q || c.name.toLowerCase().includes(q) || (c.description ?? '').toLowerCase().includes(q),
  );
  const shownManual = manual.filter(
    (c) => !q || c.name.toLowerCase().includes(q) || (c.description ?? '').toLowerCase().includes(q),
  );

  function confirmDelete(row: Character) {
    Alert.alert('Delete this character?', "This can't be undone.", [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          if (editingId === row.id) setEditingId(null);
          deleteCharacter(row.id);
        },
      },
    ]);
  }

  const empty = shownSurfaced.length === 0 && shownManual.length === 0 && !adding;

  return (
    <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag" automaticallyAdjustKeyboardInsets>
      {adding ? (
        <CharacterForm bookId={bookId} onDone={() => setAdding(false)} />
      ) : (
        <Button label="Add character" onPress={() => { setEditingId(null); setAdding(true); }} />
      )}

      {empty ? (
        <EmptyState
          title={q ? 'No matches' : 'No characters yet'}
          hint={q ? undefined : 'Write `- Name: who they are` in a chapter note and they appear here — or add one by hand.'}
        />
      ) : null}

      {shownSurfaced.map((c) => (
        <SurfacedCharacterCard
          key={c.key}
          bookId={bookId}
          character={c}
          allNames={surfaced}
          aliases={aliases}
          onJump={onJump}
        />
      ))}

      {shownManual.map((row) =>
        editingId === row.id ? (
          <CharacterForm key={row.id} bookId={bookId} initial={row} onDone={() => setEditingId(null)} />
        ) : (
          <SwipeableRow key={row.id} onEdit={() => { setAdding(false); setEditingId(row.id); }} onDelete={() => confirmDelete(row)}>
            <Card>
              <View style={styles.rowHead}>
                <Text style={styles.name}>{row.name}</Text>
                <StatusBadge label={row.status === 'gone' ? 'Gone' : 'Active'} tone={row.status === 'gone' ? 'muted' : 'active'} />
              </View>
              {row.description ? <Text style={styles.body}>{row.description}</Text> : null}
              {row.firstSeenChapter != null ? <Text style={styles.meta}>First seen in chapter {row.firstSeenChapter}</Text> : null}
            </Card>
          </SwipeableRow>
        ),
      )}
    </ScrollView>
  );
}

/** A read-only character built from markers: headline + a chapter-tagged timeline. */
function SurfacedCharacterCard({
  bookId,
  character,
  allNames,
  aliases,
  onJump,
}: {
  bookId: number;
  character: SurfacedCharacter;
  allNames: SurfacedCharacter[];
  aliases: CharacterAlias[];
  onJump?: (chapter: number) => void;
}) {
  const [merging, setMerging] = useState(false);
  // Aliases currently folded into this card, so they can be split back out.
  const foldedIn = aliases.filter((a) => a.canonical === character.key);
  // Other surfaced names this one could fold into.
  const mergeTargets = allNames.filter((c) => c.key !== character.key);

  return (
    <Card>
      <View style={styles.rowHead}>
        <Text style={styles.name}>{character.name}</Text>
        <SurfacedBadge />
      </View>
      {character.description ? <Text style={styles.body}>{character.description}</Text> : null}

      <View style={styles.tagRow}>
        {character.mentions.map((m, i) => (
          <ChapterTag key={`${m.noteId}-${i}`} chapter={m.chapter} onPress={onJump ? () => onJump(m.chapter) : undefined} />
        ))}
      </View>

      {foldedIn.length > 0 ? (
        <View style={styles.tagRow}>
          {foldedIn.map((a) => (
            <Pressable key={a.id} style={styles.aliasChip} onPress={() => unmergeCharacter(bookId, a.alias)}>
              <Text style={styles.aliasChipText}>also “{a.alias}”  ✕</Text>
            </Pressable>
          ))}
        </View>
      ) : null}

      {mergeTargets.length > 0 ? (
        merging ? (
          <View style={{ gap: spacing.xs, marginTop: spacing.sm }}>
            <Text style={styles.meta}>Fold “{character.name}” into…</Text>
            <View style={styles.tagRow}>
              {mergeTargets.map((t) => (
                <Pressable
                  key={t.key}
                  style={styles.mergeChip}
                  onPress={() => { mergeCharacter(bookId, character.name, t.name); setMerging(false); }}
                >
                  <Text style={styles.mergeChipText}>{t.name}</Text>
                </Pressable>
              ))}
            </View>
            <Button label="Cancel" variant="ghost" onPress={() => setMerging(false)} />
          </View>
        ) : (
          <View style={{ marginTop: spacing.sm }}>
            <Button label="Merge" variant="ghost" onPress={() => setMerging(true)} />
          </View>
        )
      ) : null}
    </Card>
  );
}

function CharacterForm({ bookId, initial, onDone }: { bookId: number; initial?: Character; onDone: () => void }) {
  const isEdit = !!initial;
  const [name, setName] = useState(initial?.name ?? '');
  const [description, setDescription] = useState(initial?.description ?? '');
  const [chapter, setChapter] = useState(initial?.firstSeenChapter != null ? String(initial.firstSeenChapter) : '');
  const [gone, setGone] = useState(initial?.status === 'gone');
  const [saving, setSaving] = useState(false);

  async function save() {
    if (!name.trim()) return;
    setSaving(true);
    const patch = {
      name: name.trim(),
      description: description.trim() || null,
      firstSeenChapter: chapter.trim() ? Number(chapter) : null,
      status: gone ? 'gone' : 'active',
    };
    if (isEdit && initial) await updateCharacter(initial.id, patch);
    else await createCharacter({ bookId, ...patch });
    setSaving(false);
    onDone();
  }

  return (
    <Card style={{ gap: 0 }}>
      <TextField label="Name" value={name} onChangeText={setName} placeholder="Eddard Stark" autoFocus />
      <TextField label="Who they are (optional)" value={description} onChangeText={setDescription} placeholder="Warden of the North" multiline />
      <View style={{ flexDirection: 'row', gap: spacing.sm, alignItems: 'flex-end' }}>
        <View style={{ width: 120 }}>
          <TextField label="First seen ch." value={chapter} onChangeText={setChapter} keyboardType="number-pad" placeholder="—" />
        </View>
        <View style={{ flex: 1, marginBottom: spacing.md }}>
          <SegmentedControl options={['Active', 'Gone']} value={gone ? 'Gone' : 'Active'} onChange={(v) => setGone(v === 'Gone')} />
        </View>
      </View>
      <FormButtons isEdit={isEdit} saving={saving} onCancel={onDone} onSave={save} saveDisabled={!name.trim()} />
    </Card>
  );
}

/* ======================= Highlights ======================= */

function HighlightsSection({
  q,
  highlights,
  onJump,
}: {
  q: string;
  highlights: SurfacedHighlight[];
  onJump?: (chapter: number) => void;
}) {
  const shown = highlights.filter((h) => !q || h.text.toLowerCase().includes(q));

  return (
    <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
      {shown.length === 0 ? (
        <EmptyState
          title={q ? 'No matches' : 'No highlights yet'}
          hint={q ? undefined : 'Mark a key beat with a `* ...` line in a chapter note and it surfaces here.'}
        />
      ) : null}
      {shown.map((h, i) => (
        <Card key={`${h.noteId}-${i}`}>
          <Text style={styles.body}>{h.text}</Text>
          <View style={styles.tagRow}>
            <ChapterTag chapter={h.chapter} onPress={onJump ? () => onJump(h.chapter) : undefined} />
          </View>
        </Card>
      ))}
    </ScrollView>
  );
}

/* ======================= Predictions ======================= */

function PredictionsSection({
  bookId,
  q,
  surfaced,
  onJump,
}: {
  bookId: number;
  q: string;
  surfaced: SurfacedPrediction[];
  onJump?: (chapter: number) => void;
}) {
  const { data } = useLiveQuery(predictionsQuery(bookId));
  const stored = (data ?? []) as Prediction[];
  const [adding, setAdding] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [answeringId, setAnsweringId] = useState<number | null>(null);
  const [answeringSurfaced, setAnsweringSurfaced] = useState<string | null>(null);

  // Hide surfaced `?` lines already materialised (answered) or typed manually.
  const known = predictionKeys(stored);
  const openSurfaced = surfaced.filter(
    (p) => !known.has(p.key) && (!q || p.text.toLowerCase().includes(q)),
  );
  const shownStored = stored.filter(
    (p) => !q || p.prompt.toLowerCase().includes(q) || (p.outcome ?? '').toLowerCase().includes(q),
  );

  function confirmDelete(row: Prediction) {
    Alert.alert('Delete this prediction?', "This can't be undone.", [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: () => {
          if (editingId === row.id) setEditingId(null);
          if (answeringId === row.id) setAnsweringId(null);
          deletePrediction(row.id);
        },
      },
    ]);
  }

  const empty = openSurfaced.length === 0 && shownStored.length === 0 && !adding;

  return (
    <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled" keyboardDismissMode="on-drag" automaticallyAdjustKeyboardInsets>
      {adding ? (
        <PredictionForm bookId={bookId} onDone={() => setAdding(false)} />
      ) : (
        <Button label="Make a prediction" onPress={() => { setEditingId(null); setAdding(true); }} />
      )}

      {empty ? (
        <EmptyState
          title={q ? 'No matches' : 'No predictions yet'}
          hint={q ? undefined : 'Write `? your guess` in a chapter note, then come back and mark it right or wrong.'}
        />
      ) : null}

      {/* Surfaced, still-open guesses from `?` markers. */}
      {openSurfaced.map((p) =>
        answeringSurfaced === p.key ? (
          <SurfacedAnswerForm
            key={p.key}
            prediction={p}
            onDone={() => setAnsweringSurfaced(null)}
            onResolve={(wasCorrect, outcome) => answerSurfacedPrediction(bookId, p, wasCorrect, outcome)}
          />
        ) : (
          <Card key={p.key}>
            <View style={styles.rowHead}>
              <Text style={[styles.body, { flex: 1 }]}>{p.text}</Text>
              <SurfacedBadge />
            </View>
            <View style={styles.tagRow}>
              <ChapterTag chapter={p.chapter} onPress={onJump ? () => onJump(p.chapter) : undefined} />
            </View>
            <Button label="Mark answered" variant="ghost" onPress={() => setAnsweringSurfaced(p.key)} />
          </Card>
        ),
      )}

      {/* Stored predictions: manual, plus surfaced ones already answered. */}
      {shownStored.map((row) => {
        if (editingId === row.id) {
          return <PredictionForm key={row.id} bookId={bookId} initial={row} onDone={() => setEditingId(null)} />;
        }
        if (answeringId === row.id) {
          return <StoredAnswerForm key={row.id} prediction={row} onDone={() => setAnsweringId(null)} />;
        }
        return (
          <SwipeableRow key={row.id} onEdit={() => { setAdding(false); setAnsweringId(null); setEditingId(row.id); }} onDelete={() => confirmDelete(row)}>
            <Card>
              <View style={styles.rowHead}>
                <Text style={[styles.body, { flex: 1 }]}>{row.prompt}</Text>
                {row.status === 'answered' ? (
                  <StatusBadge label={row.wasCorrect ? 'Right' : 'Wrong'} tone={row.wasCorrect ? 'correct' : 'wrong'} />
                ) : (
                  <StatusBadge label="Open" tone="active" />
                )}
              </View>
              {row.madeAtChapter != null ? <Text style={styles.meta}>Guessed at chapter {row.madeAtChapter}</Text> : null}
              {row.status === 'answered' && row.outcome ? <Text style={styles.outcome}>What happened: {row.outcome}</Text> : null}
              {row.status === 'open' ? (
                <Button label="Mark answered" variant="ghost" onPress={() => { setEditingId(null); setAnsweringId(row.id); }} />
              ) : (
                <Button label="Reopen" variant="ghost" onPress={() => reopenPrediction(row.id)} />
              )}
            </Card>
          </SwipeableRow>
        );
      })}
    </ScrollView>
  );
}

function PredictionForm({ bookId, initial, onDone }: { bookId: number; initial?: Prediction; onDone: () => void }) {
  const isEdit = !!initial;
  const [prompt, setPrompt] = useState(initial?.prompt ?? '');
  const [chapter, setChapter] = useState(initial?.madeAtChapter != null ? String(initial.madeAtChapter) : '');
  const [saving, setSaving] = useState(false);

  async function save() {
    if (!prompt.trim()) return;
    setSaving(true);
    const patch = { prompt: prompt.trim(), madeAtChapter: chapter.trim() ? Number(chapter) : null };
    if (isEdit && initial) await updatePrediction(initial.id, patch);
    else await createPrediction({ bookId, ...patch });
    setSaving(false);
    onDone();
  }

  return (
    <Card style={{ gap: 0 }}>
      <TextField label="Your guess" value={prompt} onChangeText={setPrompt} placeholder="The mentor is secretly the villain" multiline autoFocus />
      <View style={{ width: 140 }}>
        <TextField label="Guessed at ch." value={chapter} onChangeText={setChapter} keyboardType="number-pad" placeholder="—" />
      </View>
      <FormButtons isEdit={isEdit} saving={saving} onCancel={onDone} onSave={save} saveDisabled={!prompt.trim()} />
    </Card>
  );
}

/** Resolve a stored (manual/materialised) prediction. */
function StoredAnswerForm({ prediction, onDone }: { prediction: Prediction; onDone: () => void }) {
  return (
    <AnswerFields
      prompt={prediction.prompt}
      initialOutcome={prediction.outcome ?? ''}
      onDone={onDone}
      onResolve={(wasCorrect, outcome) => answerPrediction(prediction.id, wasCorrect, outcome)}
    />
  );
}

/** Resolve a surfaced `?` guess — materialises it on save via onResolve. */
function SurfacedAnswerForm({
  prediction,
  onDone,
  onResolve,
}: {
  prediction: SurfacedPrediction;
  onDone: () => void;
  onResolve: (wasCorrect: boolean, outcome?: string) => Promise<unknown>;
}) {
  return <AnswerFields prompt={prediction.text} initialOutcome="" onDone={onDone} onResolve={onResolve} />;
}

function AnswerFields({
  prompt,
  initialOutcome,
  onDone,
  onResolve,
}: {
  prompt: string;
  initialOutcome: string;
  onDone: () => void;
  onResolve: (wasCorrect: boolean, outcome?: string) => Promise<unknown>;
}) {
  const [outcome, setOutcome] = useState(initialOutcome);
  const [saving, setSaving] = useState(false);

  async function resolve(wasCorrect: boolean) {
    setSaving(true);
    await onResolve(wasCorrect, outcome);
    setSaving(false);
    onDone();
  }

  return (
    <Card style={{ gap: 0 }}>
      <Text style={[styles.body, { marginBottom: spacing.sm }]}>{prompt}</Text>
      <TextField label="What actually happened (optional)" value={outcome} onChangeText={setOutcome} placeholder="Turned out to be the mentor's twin" multiline autoFocus />
      <View style={{ flexDirection: 'row', gap: spacing.sm }}>
        <View style={{ flex: 1 }}>
          <Button label="Got it wrong" variant="ghost" onPress={() => resolve(false)} loading={saving} />
        </View>
        <View style={{ flex: 1 }}>
          <Button label="Got it right" onPress={() => resolve(true)} loading={saving} />
        </View>
      </View>
      <View style={{ marginTop: spacing.sm }}>
        <Button label="Cancel" variant="ghost" onPress={onDone} />
      </View>
    </Card>
  );
}

/* ======================= shared bits ======================= */

function FormButtons({
  isEdit,
  saving,
  onCancel,
  onSave,
  saveDisabled,
}: {
  isEdit: boolean;
  saving: boolean;
  onCancel: () => void;
  onSave: () => void;
  saveDisabled: boolean;
}) {
  return (
    <View style={{ flexDirection: 'row', gap: spacing.sm }}>
      <View style={{ flex: 1 }}>
        <Button label="Cancel" variant="ghost" onPress={onCancel} />
      </View>
      <View style={{ flex: 1 }}>
        <Button label={isEdit ? 'Save changes' : 'Save'} onPress={onSave} loading={saving} disabled={saveDisabled} />
      </View>
    </View>
  );
}

function ChapterTag({ chapter, onPress }: { chapter: number; onPress?: () => void }) {
  return (
    <Pressable style={styles.chapterTag} onPress={onPress} disabled={!onPress}>
      <Text style={styles.chapterTagText}>ch. {chapter}</Text>
    </Pressable>
  );
}

/** Marks a card as auto-surfaced from note markers, not typed by hand. */
function SurfacedBadge() {
  return (
    <View style={[styles.badge, styles.surfacedBadge]}>
      <Text style={[styles.badgeText, { color: colors.inkSoft }]}>From notes</Text>
    </View>
  );
}

type Tone = 'active' | 'muted' | 'correct' | 'wrong';

function StatusBadge({ label, tone }: { label: string; tone: Tone }) {
  return (
    <View style={[styles.badge, badgeTone[tone]]}>
      <Text style={[styles.badgeText, badgeTextTone[tone]]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: { paddingBottom: 40, gap: spacing.sm },
  rowHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.xs },
  name: { ...type.heading, color: colors.ink, flex: 1 },
  body: { ...type.body, color: colors.ink },
  meta: { ...type.caption, color: colors.inkFaint, marginTop: spacing.xs },
  outcome: { ...type.caption, color: colors.inkSoft, marginTop: spacing.xs },
  tagRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs, marginTop: spacing.sm },
  chapterTag: { backgroundColor: colors.surfaceAlt, paddingHorizontal: spacing.sm, paddingVertical: 4, borderRadius: radius.pill },
  chapterTagText: { ...type.caption, color: colors.accent, fontWeight: '600' },
  aliasChip: { backgroundColor: colors.surfaceAlt, paddingHorizontal: spacing.sm, paddingVertical: 4, borderRadius: radius.pill },
  aliasChipText: { ...type.caption, color: colors.inkSoft },
  mergeChip: { backgroundColor: colors.accentSoft, paddingHorizontal: spacing.sm, paddingVertical: 6, borderRadius: radius.pill },
  mergeChipText: { ...type.caption, color: colors.accent, fontWeight: '600' },
  badge: { paddingHorizontal: spacing.sm, paddingVertical: 2, borderRadius: radius.pill },
  surfacedBadge: { backgroundColor: colors.surfaceAlt },
  badgeText: { ...type.caption, fontWeight: '600' },
});

const badgeTone: Record<Tone, { backgroundColor: string }> = {
  active: { backgroundColor: colors.accentSoft },
  muted: { backgroundColor: colors.surfaceAlt },
  correct: { backgroundColor: '#DCEBE1' },
  wrong: { backgroundColor: '#F3D9D8' },
};

const badgeTextTone: Record<Tone, { color: string }> = {
  active: { color: colors.accent },
  muted: { color: colors.inkSoft },
  correct: { color: colors.success },
  wrong: { color: colors.danger },
};
