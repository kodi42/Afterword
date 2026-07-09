import { ReactNode } from 'react';
import { View, StyleSheet, ViewStyle, Keyboard, TouchableWithoutFeedback } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { colors, spacing } from '@/theme';

export function Screen({ children, style }: { children: ReactNode; style?: ViewStyle }) {
  // Tapping any empty area dismisses the keyboard. Taps that land on an input,
  // button, or list row are captured by those children, so this only fires on
  // otherwise-dead space. Scroll gestures are moves, not taps, so lists still scroll.
  // (The keyboard's Done bar is mounted once at the app root, not here.)
  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <TouchableWithoutFeedback onPress={Keyboard.dismiss} accessible={false}>
        <View style={[styles.inner, style]}>{children}</View>
      </TouchableWithoutFeedback>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.bg },
  inner: { flex: 1, paddingHorizontal: spacing.md },
});
