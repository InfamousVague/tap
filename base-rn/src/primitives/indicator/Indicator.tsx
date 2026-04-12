import React from 'react';
import { View, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withRepeat, withTiming } from 'react-native-reanimated';
import { useTheme } from '../../theme';

export interface IndicatorProps {
  status: 'up' | 'down' | 'unknown' | 'warning';
  size?: 'sm' | 'md' | 'lg';
  pulse?: boolean;
  style?: ViewStyle;
}

export function Indicator({
  status,
  size = 'md',
  pulse = false,
  style,
}: IndicatorProps) {
  const { colors } = useTheme();
  const opacity = useSharedValue(1);

  React.useEffect(() => {
    if (pulse && status === 'up') {
      opacity.value = withRepeat(
        withTiming(0.4, { duration: 1000 }),
        -1,
        true
      );
    } else {
      opacity.value = 1;
    }
  }, [pulse, status]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  const sizeMap = { sm: 8, md: 10, lg: 14 };
  const s = sizeMap[size];

  const colorMap = {
    up: colors.success,
    down: colors.error,
    unknown: colors.textMuted,
    warning: colors.warning,
  };

  return (
    <Animated.View
      style={[
        animatedStyle,
        {
          width: s,
          height: s,
          borderRadius: s / 2,
          backgroundColor: colorMap[status],
        },
        style,
      ]}
    />
  );
}
