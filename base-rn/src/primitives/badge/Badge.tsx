import React from 'react';
import { View, ViewStyle } from 'react-native';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface BadgeProps {
  variant?: 'solid' | 'subtle' | 'outline';
  size?: 'sm' | 'md';
  color?: 'neutral' | 'accent' | 'error' | 'warning' | 'success' | 'info';
  style?: ViewStyle;
  children?: React.ReactNode;
}

export function Badge({
  variant = 'subtle',
  size = 'sm',
  color = 'neutral',
  style,
  children,
}: BadgeProps) {
  const { colors, radius, spacing } = useTheme();

  const colorMap = {
    neutral: {
      solid: colors.interactive,
      subtle: colors.bgMuted,
      text: colors.text,
      border: colors.border,
    },
    accent: {
      solid: colors.accent,
      subtle: colors.accentSubtle,
      text: colors.accentText,
      border: colors.accent,
    },
    error: {
      solid: colors.error,
      subtle: colors.errorSubtle,
      text: colors.error,
      border: colors.error,
    },
    warning: {
      solid: colors.warning,
      subtle: colors.warningSubtle,
      text: colors.warning,
      border: colors.warning,
    },
    success: {
      solid: colors.success,
      subtle: colors.successSubtle,
      text: colors.success,
      border: colors.success,
    },
    info: {
      solid: colors.info,
      subtle: colors.infoSubtle,
      text: colors.info,
      border: colors.info,
    },
  };

  const c = colorMap[color];
  const isSmall = size === 'sm';

  const getBg = () => {
    switch (variant) {
      case 'solid':
        return c.solid;
      case 'subtle':
        return c.subtle;
      case 'outline':
        return 'transparent';
    }
  };

  const getTextColor = () => {
    switch (variant) {
      case 'solid':
        return color === 'accent' ? '#000000' : '#ffffff';
      case 'subtle':
      case 'outline':
        return c.text;
    }
  };

  return (
    <View
      style={[
        {
          flexDirection: 'row',
          alignItems: 'center',
          alignSelf: 'flex-start',
          gap: spacing[1],
          backgroundColor: getBg(),
          borderRadius: radius.full,
          paddingHorizontal: isSmall ? spacing[1.5] : spacing[2],
          paddingVertical: isSmall ? spacing[0.5] : spacing[1],
          ...(variant === 'outline' ? { borderWidth: 1, borderColor: c.border } : undefined),
        },
        style,
      ]}
    >
      {children != null && (
        <Text variant="caption" color={getTextColor()}>
          {children}
        </Text>
      )}
    </View>
  );
}
