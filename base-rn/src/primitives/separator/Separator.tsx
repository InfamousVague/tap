import React from 'react';
import { View, ViewProps } from 'react-native';
import { useTheme } from '../../theme';

export interface SeparatorProps extends ViewProps {
  direction?: 'horizontal' | 'vertical';
  color?: string;
}

export function Separator({
  direction = 'horizontal',
  color,
  style,
  ...props
}: SeparatorProps) {
  const { colors } = useTheme();
  const resolvedColor = color ?? colors.border;
  const isHorizontal = direction === 'horizontal';

  return (
    <View
      style={[
        {
          backgroundColor: resolvedColor,
          ...(isHorizontal
            ? { height: 1, width: '100%' as any }
            : { width: 1, height: '100%' as any }),
        },
        style,
      ]}
      {...props}
    />
  );
}
