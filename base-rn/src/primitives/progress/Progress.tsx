import React, { useEffect } from 'react';
import { View, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withTiming } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { duration } from '../../tokens/animation';

export interface ProgressProps {
  value: number; // 0-100
  size?: 'sm' | 'md' | 'lg';
  color?: string;
  animated?: boolean;
  style?: ViewStyle;
}

export function Progress({
  value,
  size = 'md',
  color,
  animated = true,
  style,
}: ProgressProps) {
  const { colors, radius } = useTheme();
  const width = useSharedValue(0);

  useEffect(() => {
    const clamped = Math.min(100, Math.max(0, value));
    if (animated) {
      width.value = withTiming(clamped, { duration: duration.normal });
    } else {
      width.value = clamped;
    }
  }, [value]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${width.value}%`,
  }));

  const sizeMap = { sm: 4, md: 8, lg: 12 };
  const height = sizeMap[size];

  return (
    <View
      style={[
        {
          height,
          backgroundColor: colors.bgMuted,
          borderRadius: radius.full,
          overflow: 'hidden',
        },
        style,
      ]}
    >
      <Animated.View
        style={[
          animatedStyle,
          {
            height: '100%',
            backgroundColor: color || colors.accent,
            borderRadius: radius.full,
          },
        ]}
      />
    </View>
  );
}
