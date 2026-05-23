import React from 'react';
import { Pressable, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { springConfig } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface ChipProps {
  label: string;
  selected?: boolean;
  onPress?: () => void;
  removable?: boolean;
  onRemove?: () => void;
  disabled?: boolean;
  style?: ViewStyle;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function Chip({
  label,
  selected = false,
  onPress,
  removable = false,
  onRemove,
  disabled = false,
  style,
}: ChipProps) {
  const { colors, radius, spacing } = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      onPress={disabled ? undefined : onPress}
      onPressIn={() => {
        scale.value = withSpring(0.96, springConfig.snappy);
      }}
      onPressOut={() => {
        scale.value = withSpring(1, springConfig.gentle);
      }}
      style={[
        animatedStyle,
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: spacing[1.5],
          paddingHorizontal: spacing[3],
          paddingVertical: spacing[1.5],
          borderRadius: radius.full,
          backgroundColor: selected ? colors.accentSubtle : colors.bgMuted,
          borderWidth: 1,
          borderColor: selected ? colors.accent : colors.border,
          opacity: disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      <Text variant="label" color={selected ? colors.accentText : colors.text}>
        {label}
      </Text>
      {removable && (
        <Pressable onPress={onRemove} hitSlop={8}>
          <Text variant="caption" color={selected ? colors.accentText : colors.textMuted}>
            x
          </Text>
        </Pressable>
      )}
    </AnimatedPressable>
  );
}
