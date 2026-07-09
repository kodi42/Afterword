/**
 * Design tokens. One warm "paper and ink" theme for v1.
 * Everything visual references these. Change a value here, it changes everywhere.
 * A dark theme later is just a second object with the same shape.
 */
export const colors = {
  bg: '#F6F1E7',          // warm paper
  surface: '#FFFFFF',     // cards
  surfaceAlt: '#EFE7D6',  // subtle fills, segmented control track
  ink: '#26221C',         // primary text
  inkSoft: '#6B6357',     // secondary text
  inkFaint: '#A79E8C',    // hints, placeholders
  accent: '#B4562B',      // terracotta, for actions and highlights
  accentSoft: '#F0DDCF',
  border: '#E3DACA',
  success: '#3F7A55',
  danger: '#B23A38',
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
};

export const radius = {
  sm: 8,
  md: 12,
  lg: 20,
  pill: 999,
};

export const type = {
  display: { fontSize: 28, fontWeight: '700' as const, letterSpacing: -0.3 },
  title: { fontSize: 20, fontWeight: '700' as const },
  heading: { fontSize: 17, fontWeight: '600' as const },
  body: { fontSize: 16, fontWeight: '400' as const, lineHeight: 24 },
  label: { fontSize: 14, fontWeight: '600' as const },
  caption: { fontSize: 13, fontWeight: '400' as const },
};
