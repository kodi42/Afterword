import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';
import { useMigrations } from 'drizzle-orm/expo-sqlite/migrator';
import { db } from '@/db/client';
import { colors, type } from '@/theme';

// NOTE: this import resolves only AFTER you run `npm run db:generate` once.
// That command creates src/db/migrations/. See README, Phase 0.
import migrations from '@/db/migrations/migrations';

export default function RootLayout() {
  const { success, error } = useMigrations(db, migrations);

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.err}>Database failed to set up.</Text>
        <Text style={styles.errDetail}>{error.message}</Text>
      </View>
    );
  }

  if (!success) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={colors.accent} />
      </View>
    );
  }

  return (
    <>
      <StatusBar style="dark" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: colors.bg },
          headerShadowVisible: false,
          headerTintColor: colors.ink,
          headerTitleStyle: { ...type.heading },
          contentStyle: { backgroundColor: colors.bg },
        }}
      >
        <Stack.Screen name="index" options={{ title: 'Afterword' }} />
        <Stack.Screen name="book/[id]" options={{ title: '' }} />
        <Stack.Screen
          name="book/new"
          options={{ title: 'Add a book', presentation: 'modal' }}
        />
      </Stack>
    </>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.bg, gap: 8, padding: 24 },
  err: { ...type.heading, color: colors.danger },
  errDetail: { ...type.caption, color: colors.inkSoft, textAlign: 'center' },
});
