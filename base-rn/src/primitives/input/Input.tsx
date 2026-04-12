import React, { useState } from 'react';
import { TextInput, TextInputProps, View, Pressable } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withTiming } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { duration } from '../../tokens/animation';

export interface InputProps extends Omit<TextInputProps, 'style'> {
  size?: 'sm' | 'md' | 'lg';
  variant?: 'outline' | 'filled' | 'ghost';
  shape?: 'square' | 'default' | 'pill';
  intent?: 'error' | 'warning' | 'success' | 'info';
  loading?: boolean;
  skeleton?: boolean;
  iconLeft?: React.ReactNode;
  iconRight?: React.ReactNode;
  onClear?: () => void;
  label?: string;
}

export function Input({
  size = 'md',
  variant = 'outline',
  shape = 'default',
  intent,
  loading,
  skeleton,
  iconLeft,
  iconRight,
  onClear,
  label,
  onFocus,
  onBlur,
  ...props
}: InputProps) {
  const { colors, radius, spacing, typography } = useTheme();
  const [focused, setFocused] = useState(false);
  const borderColor = useSharedValue(colors.border);

  const animatedBorder = useAnimatedStyle(() => ({
    borderColor: borderColor.value,
  }));

  const sizes = {
    sm: { height: 32, fontSize: typography.fontSize.sm, paddingH: spacing[2] },
    md: { height: 40, fontSize: typography.fontSize.base, paddingH: spacing[3] },
    lg: { height: 48, fontSize: typography.fontSize.md, paddingH: spacing[4] },
  };

  const s = sizes[size];
  const borderRadius = shape === 'pill' ? radius.full : shape === 'square' ? radius.sm : radius.md;

  const getBg = () => {
    switch (variant) {
      case 'filled': return colors.bgMuted;
      case 'ghost': return 'transparent';
      default: return colors.bg;
    }
  };

  const getBorderWidth = () => {
    switch (variant) {
      case 'ghost': return 0;
      default: return 1;
    }
  };

  const getBorderColor = () => {
    if (intent) return colors[intent];
    if (focused) return colors.borderFocus;
    return colors.border;
  };

  return (
    <Animated.View
      style={[
        animatedBorder,
        {
          height: s.height,
          backgroundColor: getBg(),
          borderWidth: getBorderWidth(),
          borderColor: getBorderColor(),
          borderRadius,
          flexDirection: 'row',
          alignItems: 'center',
          paddingHorizontal: s.paddingH,
          gap: spacing[2],
        },
      ]}
    >
      {iconLeft}
      <TextInput
        style={{
          flex: 1,
          height: '100%',
          fontSize: s.fontSize,
          color: colors.text,
          fontFamily: typography.fontFamily.regular,
        }}
        placeholderTextColor={colors.textMuted}
        onFocus={(e) => {
          setFocused(true);
          onFocus?.(e);
        }}
        onBlur={(e) => {
          setFocused(false);
          onBlur?.(e);
        }}
        {...props}
      />
      {iconRight}
    </Animated.View>
  );
}
