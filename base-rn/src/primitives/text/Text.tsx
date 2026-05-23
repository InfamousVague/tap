import React from 'react';
import { Text as RNText, TextProps as RNTextProps, TextStyle } from 'react-native';
import { textStyles } from '@mattssoftware/base-tokens';
import type { TextStyleKey } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';

export interface TextProps extends RNTextProps {
  variant?: TextStyleKey;
  color?: string;
  align?: TextStyle['textAlign'];
  weight?: '400' | '500' | '600' | '700';
  mono?: boolean;
}

export function Text({
  variant = 'body',
  color,
  align,
  weight,
  mono,
  style,
  children,
  ...props
}: TextProps) {
  const { colors, typography } = useTheme();

  const baseStyle = textStyles[variant];
  const resolvedColor = color ?? colors.text;

  return (
    <RNText
      style={[
        {
          ...baseStyle,
          color: resolvedColor,
          textAlign: align,
          ...(weight ? { fontWeight: weight } : undefined),
          ...(mono ? { fontFamily: typography.fontFamily.mono } : undefined),
        },
        style,
      ]}
      {...props}
    >
      {children}
    </RNText>
  );
}
