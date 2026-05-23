import React from 'react';
import { View, ViewProps, ViewStyle } from 'react-native';
import type { SpacingKey } from '@mattssoftware/base-tokens';
import { useTheme } from '../../theme';

export interface StackProps extends ViewProps {
  direction?: 'row' | 'column';
  gap?: SpacingKey;
  align?: ViewStyle['alignItems'];
  justify?: ViewStyle['justifyContent'];
  wrap?: boolean;
  flex?: number;
  padding?: SpacingKey;
  paddingX?: SpacingKey;
  paddingY?: SpacingKey;
}

export function Stack({
  direction = 'column',
  gap,
  align,
  justify,
  wrap,
  flex,
  padding,
  paddingX,
  paddingY,
  style,
  children,
  ...props
}: StackProps) {
  const { spacing } = useTheme();

  return (
    <View
      style={[
        {
          flexDirection: direction,
          ...(gap !== undefined ? { gap: spacing[gap] } : undefined),
          ...(align ? { alignItems: align } : undefined),
          ...(justify ? { justifyContent: justify } : undefined),
          ...(wrap ? { flexWrap: 'wrap' } : undefined),
          ...(flex !== undefined ? { flex } : undefined),
          ...(padding !== undefined ? { padding: spacing[padding] } : undefined),
          ...(paddingX !== undefined ? { paddingHorizontal: spacing[paddingX] } : undefined),
          ...(paddingY !== undefined ? { paddingVertical: spacing[paddingY] } : undefined),
        },
        style,
      ]}
      {...props}
    >
      {children}
    </View>
  );
}

export function HStack(props: Omit<StackProps, 'direction'>) {
  return <Stack direction="row" {...props} />;
}

export function VStack(props: Omit<StackProps, 'direction'>) {
  return <Stack direction="column" {...props} />;
}
