import React from 'react';
import { Pressable, PressableProps, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { springConfig } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';
import { Text } from '../text';
import { Spinner } from '../spinner';

export interface ButtonProps extends Omit<PressableProps, 'style'> {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  intent?: 'error' | 'warning' | 'success' | 'info';
  shape?: 'default' | 'pill' | 'square';
  loading?: boolean;
  disabled?: boolean;
  icon?: React.ReactNode;
  iconOnly?: boolean;
  style?: ViewStyle;
  children?: React.ReactNode;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function Button({
  variant = 'primary',
  size = 'md',
  intent,
  shape = 'default',
  loading = false,
  disabled = false,
  icon,
  iconOnly = false,
  style,
  children,
  onPress,
  ...props
}: ButtonProps) {
  const { colors, radius, spacing } = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePressIn = () => {
    scale.value = withSpring(0.96, springConfig.snappy);
  };

  const handlePressOut = () => {
    scale.value = withSpring(1, springConfig.gentle);
  };

  const sizes = {
    sm: { height: 32, paddingH: spacing[3], fontSize: 13 as const, lineHeight: 16 as const },
    md: { height: 40, paddingH: spacing[4], fontSize: 15 as const, lineHeight: 20 as const },
    lg: { height: 48, paddingH: spacing[6], fontSize: 17 as const, lineHeight: 22 as const },
  };

  const s = sizes[size];

  const getColors = (): { bg: string; text: string } => {
    if (intent) {
      const intentColor = colors[intent];
      const intentSubtle = colors[`${intent}Subtle` as keyof typeof colors];
      switch (variant) {
        case 'primary':
          return { bg: intentColor, text: '#ffffff' };
        case 'secondary':
          return { bg: intentSubtle, text: intentColor };
        case 'ghost':
          return { bg: 'transparent', text: intentColor };
      }
    }
    switch (variant) {
      case 'primary':
        return { bg: colors.accent, text: '#ffffff' };
      case 'secondary':
        return { bg: colors.bgMuted, text: colors.text };
      case 'ghost':
        return { bg: 'transparent', text: colors.text };
    }
  };

  const c = getColors();

  const borderRadius =
    shape === 'pill' ? radius.full : shape === 'square' ? radius.sm : radius.md;

  const isDisabled = disabled || loading;

  return (
    <AnimatedPressable
      onPress={isDisabled ? undefined : onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      style={[
        animatedStyle,
        {
          height: s.height,
          paddingHorizontal: iconOnly ? 0 : s.paddingH,
          width: iconOnly ? s.height : undefined,
          backgroundColor: c.bg,
          borderRadius,
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
          gap: spacing[2],
          opacity: isDisabled ? 0.5 : 1,
          ...(variant === 'secondary' ? { borderWidth: 1, borderColor: colors.border } : undefined),
        },
        style,
      ]}
      {...props}
    >
      {loading ? (
        <Spinner size="sm" color={c.text} />
      ) : (
        <>
          {icon}
          {!iconOnly && children != null && (
            <Text
              variant="label"
              color={c.text}
              style={
                { fontSize: s.fontSize, lineHeight: s.lineHeight, includeFontPadding: false } as any
              }
            >
              {children}
            </Text>
          )}
        </>
      )}
    </AnimatedPressable>
  );
}
