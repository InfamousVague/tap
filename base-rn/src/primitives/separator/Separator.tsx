import React from 'react';
import { View, ViewProps } from 'react-native';
import { useTheme } from '../../theme';
import { SpacingKey } from '../../tokens/spacing';

export interface SeparatorProps extends ViewProps {
  direction?: 'horizontal' | 'vertical';
  spacing?: SpacingKey;
  color?: string;
}

export function Separator({
  direction = 'horizontal',
  spacing: spacingProp,
  color,
  style,
  ...props
}: SeparatorProps) {
  const theme = useTheme();
  const resolvedColor = color || theme.colors.border;
  const margin = spacingProp !== undefined ? theme.spacing[spacingProp] : 0;

  const isHorizontal = direction === 'horizontal';

  return (
    <View
      style={[
        {
          backgroundColor: resolvedColor,
          ...(isHorizontal
            ? { height: 1, width: '100%', marginVertical: margin }
            : { width: 1, height: '100%', marginHorizontal: margin }),
        },
        style,
      ]}
      {...props}
    />
  );
}
