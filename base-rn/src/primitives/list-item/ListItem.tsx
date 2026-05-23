import React from 'react';
import { Pressable, View, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';
import { springConfig } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface ListItemProps {
  title: string;
  subtitle?: string;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  onPress?: () => void;
  disabled?: boolean;
  style?: ViewStyle;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export function ListItem({
  title,
  subtitle,
  leading,
  trailing,
  onPress,
  disabled = false,
  style,
}: ListItemProps) {
  const { colors, spacing } = useTheme();
  const scale = useSharedValue(1);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      onPress={disabled ? undefined : onPress}
      onPressIn={() => {
        if (onPress) scale.value = withSpring(0.96, springConfig.snappy);
      }}
      onPressOut={() => {
        scale.value = withSpring(1, springConfig.gentle);
      }}
      style={[
        animatedStyle,
        {
          flexDirection: 'row',
          alignItems: 'center',
          paddingVertical: spacing[3],
          paddingHorizontal: spacing[4],
          gap: spacing[3],
          opacity: disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      {leading}
      <View style={{ flex: 1 }}>
        <Text variant="bodyMedium">{title}</Text>
        {subtitle != null && (
          <Text variant="caption" color={colors.textSubtle}>
            {subtitle}
          </Text>
        )}
      </View>
      {trailing}
    </AnimatedPressable>
  );
}
