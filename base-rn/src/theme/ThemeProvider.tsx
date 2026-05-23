import React, { createContext, useState } from 'react';
import { useColorScheme } from 'react-native';
import {
  spacing,
  radius,
  shadows,
  duration,
  easingValues,
  springConfig,
  fontSize,
  lineHeight,
  fontWeight,
  textStyles,
} from '@mattssoftware/base-tokens';
import type { Theme, ColorMode } from './types';
import { lightTheme, darkTheme } from './themes';
import { fontFamily } from './fontFamily';

export interface ThemeContextValue {
  theme: Theme;
  colors: Theme['colors'];
  spacing: typeof spacing;
  radius: typeof radius;
  shadows: typeof shadows;
  animation: {
    duration: typeof duration;
    easingValues: typeof easingValues;
    springConfig: typeof springConfig;
  };
  typography: {
    fontSize: typeof fontSize;
    lineHeight: typeof lineHeight;
    fontWeight: typeof fontWeight;
    fontFamily: typeof fontFamily;
    textStyles: typeof textStyles;
  };
  colorMode: ColorMode;
  setColorMode: (mode: ColorMode | 'system') => void;
}

export const ThemeContext = createContext<ThemeContextValue | null>(null);

interface ThemeProviderProps {
  children: React.ReactNode;
  defaultMode?: ColorMode | 'system';
}

export function ThemeProvider({ children, defaultMode = 'system' }: ThemeProviderProps) {
  const systemScheme = useColorScheme();
  const [modeOverride, setModeOverride] = useState<ColorMode | 'system'>(defaultMode);

  const resolvedMode: ColorMode =
    modeOverride === 'system'
      ? systemScheme === 'dark'
        ? 'dark'
        : 'light'
      : modeOverride;

  const theme = resolvedMode === 'dark' ? darkTheme : lightTheme;

  const value: ThemeContextValue = {
    theme,
    colors: theme.colors,
    spacing,
    radius,
    shadows,
    animation: { duration, easingValues, springConfig },
    typography: { fontSize, lineHeight, fontWeight, fontFamily, textStyles },
    colorMode: resolvedMode,
    setColorMode: setModeOverride,
  };

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}
