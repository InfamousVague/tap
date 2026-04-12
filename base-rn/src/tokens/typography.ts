import { Platform } from 'react-native';

// System font families
export const fontFamily = {
  regular: Platform.select({ ios: 'System', android: 'Roboto', default: 'System' }),
  medium: Platform.select({ ios: 'System', android: 'Roboto-Medium', default: 'System' }),
  semibold: Platform.select({ ios: 'System', android: 'Roboto-Medium', default: 'System' }),
  bold: Platform.select({ ios: 'System', android: 'Roboto-Bold', default: 'System' }),
  mono: Platform.select({ ios: 'Menlo', android: 'monospace', default: 'monospace' }),
} as const;

export const fontWeight = {
  regular: '400' as const,
  medium: '500' as const,
  semibold: '600' as const,
  bold: '700' as const,
};

// Type scale (rem-like, base 16)
export const fontSize = {
  xs: 11,
  sm: 13,
  base: 15,
  md: 17,
  lg: 20,
  xl: 24,
  '2xl': 30,
  '3xl': 36,
  '4xl': 48,
} as const;

export const lineHeight = {
  xs: 16,
  sm: 18,
  base: 22,
  md: 24,
  lg: 28,
  xl: 32,
  '2xl': 38,
  '3xl': 44,
  '4xl': 56,
} as const;

// Pre-composed text styles
export const textStyles = {
  caption: { fontSize: fontSize.xs, lineHeight: lineHeight.xs, fontWeight: fontWeight.regular },
  body: { fontSize: fontSize.base, lineHeight: lineHeight.base, fontWeight: fontWeight.regular },
  bodyMedium: { fontSize: fontSize.base, lineHeight: lineHeight.base, fontWeight: fontWeight.medium },
  label: { fontSize: fontSize.sm, lineHeight: lineHeight.sm, fontWeight: fontWeight.medium },
  title: { fontSize: fontSize.md, lineHeight: lineHeight.md, fontWeight: fontWeight.semibold },
  heading: { fontSize: fontSize.lg, lineHeight: lineHeight.lg, fontWeight: fontWeight.bold },
  display: { fontSize: fontSize['2xl'], lineHeight: lineHeight['2xl'], fontWeight: fontWeight.bold },
  hero: { fontSize: fontSize['3xl'], lineHeight: lineHeight['3xl'], fontWeight: fontWeight.bold },
} as const;

export type TextStyle = keyof typeof textStyles;
