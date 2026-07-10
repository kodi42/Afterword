import { Image, View, Text, StyleSheet } from 'react-native';
import { colors, radius } from '@/theme';

/**
 * A book's cover thumbnail, or a paper-toned placeholder when there isn't one.
 * Fixed 2:3 portrait ratio so rows and headers line up.
 */
export function BookCover({ uri, width = 44 }: { uri?: string | null; width?: number }) {
  const height = Math.round(width * 1.5);
  if (uri) {
    return <Image source={{ uri }} style={[styles.base, { width, height }]} resizeMode="cover" />;
  }
  return (
    <View style={[styles.base, styles.placeholder, { width, height }]}>
      <Text style={{ fontSize: width * 0.5, opacity: 0.5 }}>📖</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  base: { borderRadius: radius.sm, backgroundColor: colors.surfaceAlt },
  placeholder: {
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.border,
  },
});
