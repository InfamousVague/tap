import React from 'react';
import { Modal, View, Pressable } from 'react-native';
import Animated, { FadeIn, FadeOut, SlideInDown, SlideOutDown } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { Text } from '../text';

export interface DialogProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  children?: React.ReactNode;
  size?: 'sm' | 'md' | 'lg';
}

export function Dialog({
  visible,
  onClose,
  title,
  children,
  size = 'md',
}: DialogProps) {
  const { colors, radius, spacing, shadows } = useTheme();

  const maxWidthMap = { sm: 320, md: 400, lg: 500 };

  return (
    <Modal visible={visible} transparent animationType="none" onRequestClose={onClose}>
      <Animated.View
        entering={FadeIn.duration(150)}
        exiting={FadeOut.duration(100)}
        style={{
          flex: 1,
          justifyContent: 'center',
          alignItems: 'center',
          backgroundColor: colors.overlay,
          padding: spacing[6],
        }}
      >
        <Pressable
          style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
          onPress={onClose}
        />
        <Animated.View
          entering={SlideInDown.duration(200)}
          exiting={SlideOutDown.duration(150)}
          style={{
            backgroundColor: colors.bgElevated,
            borderRadius: radius.xl,
            padding: spacing[6],
            width: '100%',
            maxWidth: maxWidthMap[size],
            gap: spacing[4],
            ...shadows.xl,
          }}
        >
          {title != null && <Text variant="heading">{title}</Text>}
          {children}
        </Animated.View>
      </Animated.View>
    </Modal>
  );
}
