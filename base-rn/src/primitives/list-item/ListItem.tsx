import React from 'react';
import { Pressable, View, ViewStyle } from 'react-native';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface ListItemProps {
  title: string;
  subtitle?: string;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  chevron?: boolean;
  onPress?: () => void;
  disabled?: boolean;
  style?: ViewStyle;
}

export function ListItem({
  title,
  subtitle,
  leading,
  trailing,
  chevron = true,
  onPress,
  disabled,
  style,
}: ListItemProps) {
  const { colors, spacing } = useTheme();

  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      style={({ pressed }) => [
        {
          flexDirection: 'row',
          alignItems: 'center',
          paddingVertical: spacing[3],
          paddingHorizontal: spacing[4],
          gap: spacing[3],
          backgroundColor: pressed ? colors.bgMuted : 'transparent',
          opacity: disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      {leading}
      <View style={{ flex: 1 }}>
        <Text variant="bodyMedium">{title}</Text>
        {subtitle && <Text variant="caption" color={colors.textSubtle}>{subtitle}</Text>}
      </View>
      {trailing}
      {chevron && !trailing && (
        <Text color={colors.textMuted} variant="body">›</Text>
      )}
    </Pressable>
  );
}
