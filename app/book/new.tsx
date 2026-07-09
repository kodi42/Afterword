import { useState } from 'react';
import { View, StyleSheet, KeyboardAvoidingView, Platform } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { Screen, TextField, Button } from '@/components/ui';
import { createBook } from '@/features/books/queries';
import { spacing } from '@/theme';

export default function NewBook() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [totalChapters, setTotalChapters] = useState('');
  const [saving, setSaving] = useState(false);

  async function save() {
    if (!title.trim()) return;
    setSaving(true);
    const book = await createBook({
      title: title.trim(),
      author: author.trim() || null,
      totalChapters: totalChapters ? Number(totalChapters) : null,
      status: 'reading',
      startedAt: new Date(),
    });
    setSaving(false);
    router.replace({ pathname: '/book/[id]', params: { id: String(book.id) } });
  }

  return (
    <Screen>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1 }}
      >
        <View style={{ paddingTop: spacing.md, flex: 1 }}>
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
        <View style={{ paddingBottom: insets.bottom + spacing.md }}>
          <Button label="Add book" onPress={save} disabled={!title.trim()} loading={saving} />
        </View>
      </KeyboardAvoidingView>
    </Screen>
  );
}

const styles = StyleSheet.create({});
