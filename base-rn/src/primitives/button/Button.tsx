import React from 'react';
import { Pressable, PressableProps, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { Text } from '../text';
import { Spinner } from '../spinner';
import { springConfig } from '../../tokens/animation';

export interface ButtonProps extends Omit<PressableProps, 'style'> {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  intent?: 'error' | 'warning' | 'success' | 'info';
  shape?: 'square' | 'default' | 'pill';
  loading?: boolean;
  skeleton?: boolean;
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
  skeleton = false,
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

  // Size mappings
  const sizes = {
    sm: { height: 32, paddingH: spacing[3], fontSize: 13 as const },
    md: { height: 40, paddingH: spacing[4], fontSize: 15 as const },
    lg: { height: 48, paddingH: spacing[6], fontSize: 17 as const },
  };

  const s = sizes[size];

  // Colors based on variant + intent
  const getColors = () => {
    if (intent) {
      const intentColor = colors[intent];
      const intentSubtle = colors[`${intent}Subtle` as keyof typeof colors];
      switch (variant) {
        case 'primary': return { bg: intentColor, text: '#fff' };
        case 'secondary': return { bg: intentSubtle, text: intentColor };
        case 'ghost': return { bg: 'transparent', text: intentColor };
      }
    }
    switch (variant) {
      case 'primary': return { bg: colors.accent, text: '#000' };
      case 'secondary': return { bg: colors.bgMuted, text: colors.text };
      case 'ghost': return { bg: 'transparent', text: colors.text };
    }
  };

  const c = getColors();

  // Border radius based on shape
  const borderRadius = shape === 'pill' ? radius.full : shape === 'square' ? radius.sm : radius.md;

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
          ...(variant === 'secondary' && { borderWidth: 1, borderColor: colors.border }),
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
          {!iconOnly && children && (
            <Text
              variant="label"
              color={c.text}
              style={{ fontSize: s.fontSize }}
            >
              {children}
            </Text>
          )}
        </>
      )}
    </AnimatedPressable>
  );
}
