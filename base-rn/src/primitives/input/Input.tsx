import React, { useState } from 'react';
import { TextInput, TextInputProps, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { duration } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface InputProps extends Omit<TextInputProps, 'style'> {
  size?: 'sm' | 'md' | 'lg';
  variant?: 'outline' | 'filled' | 'ghost';
  intent?: 'error' | 'warning' | 'success' | 'info';
  label?: string;
  iconLeft?: React.ReactNode;
  iconRight?: React.ReactNode;
}

export function Input({
  size = 'md',
  variant = 'outline',
  intent,
  label,
  iconLeft,
  iconRight,
  onFocus,
  onBlur,
  ...props
}: InputProps) {
  const { colors, radius, spacing, typography } = useTheme();
  const [focused, setFocused] = useState(false);
  const borderProgress = useSharedValue(0);

  const animatedBorder = useAnimatedStyle(() => ({
    borderColor: focused
      ? intent
        ? colors[intent]
        : colors.borderFocus
      : intent
        ? colors[intent]
        : colors.border,
  }));

  const sizes = {
    sm: { height: 32, fontSize: typography.fontSize.sm, paddingH: spacing[2] },
    md: { height: 40, fontSize: typography.fontSize.base, paddingH: spacing[3] },
    lg: { height: 48, fontSize: typography.fontSize.md, paddingH: spacing[4] },
  };

  const s = sizes[size];

  const getBg = () => {
    switch (variant) {
      case 'filled':
        return colors.bgMuted;
      case 'ghost':
        return 'transparent';
      default:
        return colors.bg;
    }
  };

  const getBorderWidth = () => (variant === 'ghost' ? 0 : 1);

  return (
    <View>
      {label != null && (
        <Text
          variant="label"
          color={colors.textSubtle}
          style={{ marginBottom: spacing[1] }}
        >
          {label}
        </Text>
      )}
      <Animated.View
        style={[
          animatedBorder,
          {
            height: s.height,
            backgroundColor: getBg(),
            borderWidth: getBorderWidth(),
            borderRadius: radius.md,
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
            borderProgress.value = withTiming(1, { duration: duration.fast });
            onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocused(false);
            borderProgress.value = withTiming(0, { duration: duration.fast });
            onBlur?.(e);
          }}
          {...props}
        />
        {iconRight}
      </Animated.View>
    </View>
  );
}
