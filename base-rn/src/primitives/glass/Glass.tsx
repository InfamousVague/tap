import React from 'react';
import { View, ViewStyle } from 'react-native';
import { useTheme } from '../../theme';

export type GlassIntensity = 'subtle' | 'default' | 'elevated';

const glassConfig = {
  subtle: {
    blurAmount: 8,
    bgLight: 'rgba(255, 255, 255, 0.6)',
    bgDark: 'rgba(24, 24, 27, 0.6)',
    borderLight: 'rgba(255, 255, 255, 0.3)',
    borderDark: 'rgba(255, 255, 255, 0.08)',
  },
  default: {
    blurAmount: 16,
    bgLight: 'rgba(255, 255, 255, 0.72)',
    bgDark: 'rgba(24, 24, 27, 0.72)',
    borderLight: 'rgba(255, 255, 255, 0.4)',
    borderDark: 'rgba(255, 255, 255, 0.12)',
  },
  elevated: {
    blurAmount: 24,
    bgLight: 'rgba(255, 255, 255, 0.85)',
    bgDark: 'rgba(24, 24, 27, 0.85)',
    borderLight: 'rgba(255, 255, 255, 0.5)',
    borderDark: 'rgba(255, 255, 255, 0.16)',
  },
} as const;

export interface GlassProps {
  intensity?: GlassIntensity;
  children: React.ReactNode;
  style?: ViewStyle;
}

/**
 * Glassmorphism container.
 * Uses @react-native-community/blur when available,
 * falls back to translucent background.
 */
export function Glass({ intensity = 'default', children, style }: GlassProps) {
  const { colorMode, radius } = useTheme();
  const config = glassConfig[intensity];
  const isDark = colorMode === 'dark';

  return (
    <View
      style={[
        {
          backgroundColor: isDark ? config.bgDark : config.bgLight,
          borderWidth: 1,
          borderColor: isDark ? config.borderDark : config.borderLight,
          borderRadius: radius.lg,
          overflow: 'hidden',
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}
