import React from 'react';
import { ActivityIndicator, ViewProps } from 'react-native';
import { useTheme } from '../../theme';

export interface SpinnerProps extends ViewProps {
  size?: 'sm' | 'md' | 'lg';
  color?: string;
}

const sizeMap = { sm: 'small', md: 'small', lg: 'large' } as const;

export function Spinner({ size = 'md', color, style, ...props }: SpinnerProps) {
  const { colors } = useTheme();
  return (
    <ActivityIndicator
      size={sizeMap[size]}
      color={color || colors.accent}
      style={style}
      {...props}
    />
  );
}
