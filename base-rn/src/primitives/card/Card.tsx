import React from 'react';
import { View, ViewProps, Pressable } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { springConfig } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';

export interface CardProps extends ViewProps {
  variant?: 'outline' | 'filled';
  padding?: 'none' | 'sm' | 'md' | 'lg';
  onPress?: () => void;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function Card({
  variant = 'outline',
  padding = 'md',
  onPress,
  style,
  children,
  ...props
}: CardProps) {
  const { colors, radius, spacing } = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const paddingMap = {
    none: 0,
    sm: spacing[2],
    md: spacing[4],
    lg: spacing[6],
  };

  const cardStyle = {
    backgroundColor: variant === 'filled' ? colors.bgMuted : colors.bgElevated,
    borderRadius: radius.lg,
    padding: paddingMap[padding],
    ...(variant === 'outline' ? { borderWidth: 1, borderColor: colors.border } : undefined),
  };

  if (onPress) {
    return (
      <AnimatedPressable
        onPress={onPress}
        onPressIn={() => {
          scale.value = withSpring(0.96, springConfig.snappy);
        }}
        onPressOut={() => {
          scale.value = withSpring(1, springConfig.gentle);
        }}
        style={[animatedStyle, cardStyle, style]}
        {...props}
      >
        {children}
      </AnimatedPressable>
    );
  }

  return (
    <View style={[cardStyle, style]} {...props}>
      {children}
    </View>
  );
}
