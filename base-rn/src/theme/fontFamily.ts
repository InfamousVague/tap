import { Platform } from 'react-native';

export const fontFamily = {
  regular: Platform.select({ ios: 'System', android: 'Roboto', default: 'System' })!,
  medium: Platform.select({ ios: 'System', android: 'Roboto-Medium', default: 'System' })!,
  semibold: Platform.select({ ios: 'System', android: 'Roboto-Medium', default: 'System' })!,
  bold: Platform.select({ ios: 'System', android: 'Roboto-Bold', default: 'System' })!,
  mono: Platform.select({ ios: 'Menlo', android: 'monospace', default: 'monospace' })!,
} as const;
