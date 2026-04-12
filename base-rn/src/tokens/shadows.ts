import { Platform } from 'react-native';

export type Shadow = {
  shadowColor: string;
  shadowOffset: { width: number; height: number };
  shadowOpacity: number;
  shadowRadius: number;
  elevation: number;
};

const createShadow = (
  offsetY: number,
  radius: number,
  opacity: number,
  elevation: number,
  color = '#000000'
): Shadow => ({
  shadowColor: color,
  shadowOffset: { width: 0, height: offsetY },
  shadowOpacity: Platform.OS === 'ios' ? opacity : 0,
  shadowRadius: radius,
  elevation: Platform.OS === 'android' ? elevation : 0,
});

export const shadows = {
  none: createShadow(0, 0, 0, 0),
  sm: createShadow(1, 2, 0.05, 2),
  md: createShadow(2, 4, 0.08, 4),
  lg: createShadow(4, 8, 0.12, 8),
  xl: createShadow(8, 16, 0.16, 12),
} as const;

export type ShadowKey = keyof typeof shadows;
