import React, { useEffect } from 'react';
import { View, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withTiming } from 'react-native-reanimated';
import { duration } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';

export interface ProgressProps {
  /** 0 to 1 */
  value: number;
  size?: 'sm' | 'md';
  color?: string;
  style?: ViewStyle;
}

export function Progress({
  value,
  size = 'md',
  color,
  style,
}: ProgressProps) {
  const { colors, radius } = useTheme();
  const width = useSharedValue(0);

  useEffect(() => {
    const clamped = Math.min(1, Math.max(0, value)) * 100;
    width.value = withTiming(clamped, { duration: duration.normal });
  }, [value]);

  const animatedStyle = useAnimatedStyle(() => ({
    width: `${width.value}%` as any,
  }));

  const sizeMap = { sm: 4, md: 8 };
  const h = sizeMap[size];

  return (
    <View
      style={[
        {
          height: h,
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
            backgroundColor: color ?? colors.accent,
            borderRadius: radius.full,
          },
        ]}
      />
    </View>
  );
}
