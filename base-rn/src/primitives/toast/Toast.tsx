import React, { createContext, useContext, useState, useCallback } from 'react';
import { View, Pressable, ViewStyle } from 'react-native';
import Animated, { FadeInUp, FadeOutUp } from 'react-native-reanimated';
import { useTheme } from '../../theme';
import { Text } from '../text';

export type ToastType = 'success' | 'error' | 'warning' | 'info';

interface ToastItem {
  id: string;
  type: ToastType;
  title: string;
  message?: string;
  duration?: number;
}

interface ToastContextValue {
  toast: (item: Omit<ToastItem, 'id'>) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within a Toaster');
  return ctx;
}

interface ToasterProps {
  children: React.ReactNode;
}

export function Toaster({ children }: ToasterProps) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const { colors, radius, spacing, shadows } = useTheme();

  const addToast = useCallback((item: Omit<ToastItem, 'id'>) => {
    const id = Math.random().toString(36).slice(2);
    const toast = { ...item, id };
    setToasts((prev) => [...prev, toast]);

    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, item.duration || 3000);
  }, []);

  const dismiss = (id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  };

  const colorMap = {
    success: colors.success,
    error: colors.error,
    warning: colors.warning,
    info: colors.info,
  };

  return (
    <ToastContext.Provider value={{ toast: addToast }}>
      {children}
      <View
        style={{
          position: 'absolute',
          top: 60,
          left: spacing[4],
          right: spacing[4],
          zIndex: 9999,
          gap: spacing[2],
        }}
        pointerEvents="box-none"
      >
        {toasts.map((t) => (
          <Animated.View
            key={t.id}
            entering={FadeInUp.duration(200)}
            exiting={FadeOutUp.duration(150)}
          >
            <Pressable
              onPress={() => dismiss(t.id)}
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                backgroundColor: colors.bgElevated,
                borderRadius: radius.lg,
                padding: spacing[4],
                gap: spacing[3],
                borderLeftWidth: 4,
                borderLeftColor: colorMap[t.type],
                ...shadows.lg,
              }}
            >
              <View style={{ flex: 1 }}>
                <Text variant="bodyMedium">{t.title}</Text>
                {t.message && (
                  <Text variant="caption" color={colors.textSubtle}>{t.message}</Text>
                )}
              </View>
            </Pressable>
          </Animated.View>
        ))}
      </View>
    </ToastContext.Provider>
  );
}
