import { View, Text, StyleSheet } from 'react-native';
import { colors, spacing, type } from '@/theme';

export function EmptyState({ title, hint }: { title: string; hint?: string }) {
  return (
    <View style={styles.wrap}>
      <Text style={styles.title}>{title}</Text>
      {hint ? <Text style={styles.hint}>{hint}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { alignItems: 'center', justifyContent: 'center', paddingVertical: spacing.xxl, gap: spacing.xs },
  title: { ...type.heading, color: colors.inkSoft, textAlign: 'center' },
  hint: { ...type.caption, color: colors.inkFaint, textAlign: 'center', maxWidth: 260 },
});
