import React from 'react';
import { Modal, View, Pressable, ViewStyle } from 'react-native';
import Animated, { FadeIn, FadeOut, SlideInDown, SlideOutDown } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { Text } from '../text';
import { Button } from '../button';

export interface DialogProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  description?: string;
  children?: React.ReactNode;
  actions?: React.ReactNode;
  closeOnOverlay?: boolean;
}

export function Dialog({
  visible,
  onClose,
  title,
  description,
  children,
  actions,
  closeOnOverlay = true,
}: DialogProps) {
  const { colors, radius, spacing, shadows } = useTheme();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="none"
      onRequestClose={onClose}
    >
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
          onPress={closeOnOverlay ? onClose : undefined}
        />
        <Animated.View
          entering={SlideInDown.duration(200)}
          exiting={SlideOutDown.duration(150)}
          style={{
            backgroundColor: colors.bgElevated,
            borderRadius: radius.xl,
            padding: spacing[6],
            width: '100%',
            maxWidth: 400,
            gap: spacing[4],
            ...shadows.xl,
          }}
        >
          {title && <Text variant="heading">{title}</Text>}
          {description && <Text variant="body" color={colors.textSubtle}>{description}</Text>}
          {children}
          {actions && (
            <View style={{ flexDirection: 'row', justifyContent: 'flex-end', gap: spacing[2], marginTop: spacing[2] }}>
              {actions}
            </View>
          )}
        </Animated.View>
      </Animated.View>
    </Modal>
  );
}
