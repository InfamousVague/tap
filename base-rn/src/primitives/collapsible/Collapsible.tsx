import React, { useState } from 'react';
import { Pressable, View } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withTiming } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { Text } from '../text';
import { duration } from '../../tokens/animation';

export interface CollapsibleProps {
  title: string;
  defaultOpen?: boolean;
  children: React.ReactNode;
}

export function Collapsible({ title, defaultOpen = false, children }: CollapsibleProps) {
  const [open, setOpen] = useState(defaultOpen);
  const { colors, spacing } = useTheme();
  const rotation = useSharedValue(defaultOpen ? 90 : 0);

  const chevronStyle = useAnimatedStyle(() => ({
    transform: [{ rotate: `${rotation.value}deg` }],
  }));

  const toggle = () => {
    setOpen(!open);
    rotation.value = withTiming(open ? 0 : 90, { duration: duration.fast });
  };

  return (
    <View>
      <Pressable
        onPress={toggle}
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          paddingVertical: spacing[3],
          gap: spacing[2],
        }}
      >
        <Animated.View style={chevronStyle}>
          <Text color={colors.textSubtle}>›</Text>
        </Animated.View>
        <Text variant="bodyMedium">{title}</Text>
      </Pressable>
      {open && (
        <View style={{ paddingLeft: spacing[6] }}>
          {children}
        </View>
      )}
    </View>
  );
}
