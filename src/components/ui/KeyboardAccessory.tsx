import {
  InputAccessoryView,
  Keyboard,
  Platform,
  PlatformColor,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { colors, spacing, type } from '@/theme';

/**
 * A "Done" bar docked above the keyboard, dismissing it on tap. iOS only.
 *
 * Rendered once per TextField with a unique nativeID (see TextField): two bars
 * sharing an id — e.g. one per screen in the nav stack — bind ambiguously and
 * the bar silently fails to appear.
 *
 * The surface is a single opaque, full-width system-gray fill flush with the
 * keyboard, so it reads as part of the keyboard chrome with no gap or seam. It
 * intentionally uses an iOS system color (not the paper theme) to match the
 * keyboard, and adapts to light/dark automatically. Only the branded "Done"
 * label pulls from the theme.
 */
export function KeyboardDoneBar({ nativeID }: { nativeID: string }) {
  if (Platform.OS !== 'ios') return null;
  return (
    <InputAccessoryView nativeID={nativeID}>
      <View style={styles.bar}>
        <Pressable
          onPress={() => Keyboard.dismiss()}
          hitSlop={8}
          style={({ pressed }) => [styles.button, pressed && styles.pressed]}
        >
          <Text style={styles.label}>Done</Text>
        </Pressable>
      </View>
    </InputAccessoryView>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    minHeight: 44, // standard iOS keyboard toolbar height
    paddingHorizontal: spacing.sm,
    backgroundColor: PlatformColor('systemGray5'), // opaque, matches keyboard, no see-through gap
  },
  button: { paddingHorizontal: spacing.md, paddingVertical: spacing.sm },
  pressed: { opacity: 0.5 },
  label: { ...type.label, color: colors.accent, fontSize: 17 },
});
