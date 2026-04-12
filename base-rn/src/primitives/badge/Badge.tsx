import React from 'react';
import { View, ViewStyle, Pressable } from 'react-native';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface BadgeProps {
  variant?: 'solid' | 'subtle' | 'outline';
  size?: 'sm' | 'md';
  color?: 'neutral' | 'accent' | 'error' | 'warning' | 'success' | 'info';
  shape?: 'square' | 'default' | 'pill';
  icon?: React.ReactNode;
  dot?: boolean;
  removable?: boolean;
  onRemove?: () => void;
  skeleton?: boolean;
  style?: ViewStyle;
  children?: React.ReactNode;
}

export function Badge({
  variant = 'subtle',
  size = 'sm',
  color = 'neutral',
  shape = 'default',
  icon,
  dot,
  removable,
  onRemove,
  skeleton,
  style,
  children,
}: BadgeProps) {
  const { colors, radius, spacing } = useTheme();

  const colorMap = {
    neutral: { solid: colors.interactive, subtle: colors.bgMuted, text: colors.text, border: colors.border },
    accent: { solid: colors.accent, subtle: colors.accentSubtle, text: colors.accentText, border: colors.accent },
    error: { solid: colors.error, subtle: colors.errorSubtle, text: colors.error, border: colors.error },
    warning: { solid: colors.warning, subtle: colors.warningSubtle, text: colors.warning, border: colors.warning },
    success: { solid: colors.success, subtle: colors.successSubtle, text: colors.success, border: colors.success },
    info: { solid: colors.info, subtle: colors.infoSubtle, text: colors.info, border: colors.info },
  };

  const c = colorMap[color];
  const isSmall = size === 'sm';

  const getBg = () => {
    switch (variant) {
      case 'solid': return c.solid;
      case 'subtle': return c.subtle;
      case 'outline': return 'transparent';
    }
  };

  const getTextColor = () => {
    switch (variant) {
      case 'solid': return color === 'accent' ? '#000' : '#fff';
      case 'subtle': return c.text;
      case 'outline': return c.text;
    }
  };

  const borderRadius = shape === 'pill' ? radius.full : shape === 'square' ? radius.sm : radius.md;

  return (
    <View
      style={[
        {
          flexDirection: 'row',
          alignItems: 'center',
          gap: spacing[1],
          backgroundColor: getBg(),
          borderRadius,
          paddingHorizontal: isSmall ? spacing[1.5] : spacing[2],
          paddingVertical: isSmall ? spacing[0.5] : spacing[1],
          ...(variant === 'outline' && { borderWidth: 1, borderColor: c.border }),
        },
        style,
      ]}
    >
      {dot && (
        <View style={{
          width: 6,
          height: 6,
          borderRadius: 3,
          backgroundColor: c.solid,
        }} />
      )}
      {icon}
      {children && (
        <Text variant="caption" color={getTextColor()}>
          {children}
        </Text>
      )}
      {removable && (
        <Pressable onPress={onRemove} hitSlop={8}>
          <Text variant="caption" color={getTextColor()}>×</Text>
        </Pressable>
      )}
    </View>
  );
}
