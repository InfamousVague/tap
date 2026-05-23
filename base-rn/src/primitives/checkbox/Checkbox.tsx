import React from 'react';
import { Pressable, View, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { springConfig } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface CheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  disabled?: boolean;
  style?: ViewStyle;
}

export function Checkbox({
  checked,
  onChange,
  label,
  disabled = false,
  style,
}: CheckboxProps) {
  const { colors, radius, spacing } = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const handlePress = () => {
    if (disabled) return;
    scale.value = withSpring(0.85, springConfig.snappy);
    setTimeout(() => {
      scale.value = withSpring(1, springConfig.gentle);
    }, 100);
    onChange(!checked);
  };

  return (
    <Pressable
      onPress={handlePress}
      style={[
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: spacing[2],
          opacity: disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      <Animated.View
        style={[
          animatedStyle,
          {
            width: 22,
            height: 22,
            borderRadius: radius.sm,
            borderWidth: 2,
            borderColor: checked ? colors.accent : colors.border,
            backgroundColor: checked ? colors.accent : 'transparent',
            alignItems: 'center',
            justifyContent: 'center',
          },
        ]}
      >
        {checked && (
          <Text
            style={{
              color: '#000000',
              fontSize: 14,
              fontWeight: '700',
              marginTop: -1,
            }}
          >
            ✓
          </Text>
        )}
      </Animated.View>
      {label != null && <Text variant="body">{label}</Text>}
    </Pressable>
  );
}
