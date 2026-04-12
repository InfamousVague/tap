import React from 'react';
import { View, ViewProps, Pressable } from 'react-native';
import { useTheme } from '../../theme';

export interface CardProps extends ViewProps {
  variant?: 'elevated' | 'outline' | 'filled';
  padding?: 'none' | 'sm' | 'md' | 'lg';
  onPress?: () => void;
}

export function Card({
  variant = 'elevated',
  padding = 'md',
  onPress,
  style,
  children,
  ...props
}: CardProps) {
  const { colors, radius, spacing, shadows } = useTheme();

  const paddingMap = {
    none: 0,
    sm: spacing[2],
    md: spacing[4],
    lg: spacing[6],
  };

  const cardStyle = {
    backgroundColor: colors.bgElevated,
    borderRadius: radius.lg,
    padding: paddingMap[padding],
    ...(variant === 'elevated' && shadows.md),
    ...(variant === 'outline' && { borderWidth: 1, borderColor: colors.border }),
    ...(variant === 'filled' && { backgroundColor: colors.bgMuted }),
  };

  if (onPress) {
    return (
      <Pressable onPress={onPress} style={[cardStyle, style]} {...props}>
        {children}
      </Pressable>
    );
  }

  return (
    <View style={[cardStyle, style]} {...props}>
      {children}
    </View>
  );
}
