import React from 'react';
import { Pressable, ViewStyle } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring, interpolateColor } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { springConfig } from '../../tokens/animation';

export interface ToggleProps {
  value: boolean;
  onValueChange: (value: boolean) => void;
  disabled?: boolean;
  size?: 'sm' | 'md';
  style?: ViewStyle;
}

export function Toggle({
  value,
  onValueChange,
  disabled = false,
  size = 'md',
  style,
}: ToggleProps) {
  const { colors } = useTheme();
  const progress = useSharedValue(value ? 1 : 0);

  React.useEffect(() => {
    progress.value = withSpring(value ? 1 : 0, springConfig.snappy);
  }, [value]);

  const sizes = {
    sm: { width: 40, height: 24, knob: 18, padding: 3 },
    md: { width: 50, height: 30, knob: 24, padding: 3 },
  };

  const s = sizes[size];

  const trackStyle = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(
      progress.value,
      [0, 1],
      [colors.bgMuted, colors.accent]
    ),
  }));

  const knobStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: progress.value * (s.width - s.knob - s.padding * 2) }],
  }));

  return (
    <Pressable
      onPress={() => !disabled && onValueChange(!value)}
      style={[{ opacity: disabled ? 0.5 : 1 }, style]}
    >
      <Animated.View
        style={[
          trackStyle,
          {
            width: s.width,
            height: s.height,
            borderRadius: s.height / 2,
            padding: s.padding,
            justifyContent: 'center',
          },
        ]}
      >
        <Animated.View
          style={[
            knobStyle,
            {
              width: s.knob,
              height: s.knob,
              borderRadius: s.knob / 2,
              backgroundColor: '#ffffff',
              shadowColor: '#000',
              shadowOffset: { width: 0, height: 1 },
              shadowOpacity: 0.15,
              shadowRadius: 2,
              elevation: 2,
            },
          ]}
        />
      </Animated.View>
    </Pressable>
  );
}
