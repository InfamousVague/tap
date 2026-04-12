import React from 'react';
import { View, ViewStyle } from 'react-native';
import { useTheme } from '../../theme';
import { GlassIntensity } from '../../tokens/glass';

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
export function Glass({
  intensity = 'default',
  children,
  style,
}: GlassProps) {
  const { glass: glassTokens, colorMode, radius } = useTheme();
  const config = glassTokens[intensity];
  const isDark = colorMode === 'dark';

  // Fallback implementation (works without blur library)
  // When @react-native-community/blur is installed, replace with BlurView
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
