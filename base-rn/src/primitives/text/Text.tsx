import React from 'react';
import { Text as RNText, TextProps as RNTextProps, TextStyle } from 'react-native';
import { useTheme } from '../../theme';
import { TextStyle as TextStyleKey, textStyles } from '../../tokens/typography';

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
  const resolvedColor = color || colors.text;

  return (
    <RNText
      style={[
        {
          ...baseStyle,
          color: resolvedColor,
          textAlign: align,
          ...(weight && { fontWeight: weight }),
          ...(mono && { fontFamily: typography.fontFamily.mono }),
        },
        style,
      ]}
      {...props}
    >
      {children}
    </RNText>
  );
}
