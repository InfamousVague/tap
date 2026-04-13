import React, { useEffect } from 'react';
import { View, ViewStyle } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { useTheme } from '../../theme';

export interface SkeletonProps {
  width?: number | string;
  height?: number | string;
  radius?: number;
  circle?: boolean;
  style?: ViewStyle;
}

export function Skeleton({
  width = '100%',
  height = 20,
  radius: radiusProp,
  circle = false,
  style,
}: SkeletonProps) {
  const { colors, radius } = useTheme();
  const shimmer = useSharedValue(0);

  useEffect(() => {
    shimmer.value = withRepeat(
      withTiming(1, { duration: 1200 }),
      -1,
      false
    );
  }, []);

  const animatedStyle = useAnimatedStyle(() => {
    const opacity = interpolate(shimmer.value, [0, 0.5, 1], [0.3, 0.7, 0.3]);
    return { opacity };
  });

  const size = circle ? (typeof height === 'number' ? height : 40) : undefined;

  return (
    <Animated.View
      style={[
        animatedStyle,
        {
          width: (circle ? size : width) as number | undefined,
          height: (circle ? size : height) as number | undefined,
          borderRadius: circle ? (size! / 2) : (radiusProp ?? radius.md),
          backgroundColor: colors.bgMuted,
        },
        style,
      ]}
    />
  );
}
