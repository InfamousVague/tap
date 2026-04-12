import React from 'react';
import { View, ViewProps, ViewStyle } from 'react-native';
import { useTheme } from '../../theme';
import { SpacingKey } from '../../tokens/spacing';

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
          ...(gap !== undefined && { gap: spacing[gap] }),
          ...(align && { alignItems: align }),
          ...(justify && { justifyContent: justify }),
          ...(wrap && { flexWrap: 'wrap' }),
          ...(flex !== undefined && { flex }),
          ...(padding !== undefined && { padding: spacing[padding] }),
          ...(paddingX !== undefined && { paddingHorizontal: spacing[paddingX] }),
          ...(paddingY !== undefined && { paddingVertical: spacing[paddingY] }),
        },
        style,
      ]}
      {...props}
    >
      {children}
    </View>
  );
}

// Convenience aliases
export function HStack(props: Omit<StackProps, 'direction'>) {
  return <Stack direction="row" {...props} />;
}

export function VStack(props: Omit<StackProps, 'direction'>) {
  return <Stack direction="column" {...props} />;
}
