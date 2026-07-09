import { useId } from 'react';
import { TextInput, Text, View, StyleSheet, TextInputProps, Platform } from 'react-native';
import { colors, radius, spacing, type } from '@/theme';
import { KeyboardDoneBar } from './KeyboardAccessory';

type Props = TextInputProps & { label?: string };

export function TextField({ label, style, inputAccessoryViewID, ...props }: Props) {
  // Each field owns its own Done bar with a unique id, so bars never collide
  // across stacked screens. A caller can still pass its own id to opt out.
  const autoId = useId();
  const renderOwnBar = Platform.OS === 'ios' && !inputAccessoryViewID;
  const accessoryId = renderOwnBar ? autoId : inputAccessoryViewID;

  return (
    <View style={styles.wrap}>
      {label ? <Text style={styles.label}>{label}</Text> : null}
      <TextInput
        placeholderTextColor={colors.inkFaint}
        inputAccessoryViewID={accessoryId}
        style={[styles.input, props.multiline && styles.multiline, style]}
        {...props}
      />
      {renderOwnBar ? <KeyboardDoneBar nativeID={autoId} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginBottom: spacing.md },
  label: { ...type.label, color: colors.inkSoft, marginBottom: spacing.xs },
  input: {
    ...type.body,
    color: colors.ink,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm + 2,
    minHeight: 48,
  },
  multiline: { minHeight: 140, textAlignVertical: 'top', paddingTop: spacing.sm + 2 },
});
