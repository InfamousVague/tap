import React, { createContext, useEffect, useState } from 'react';
import { useColorScheme } from 'react-native';
import { Theme, ColorMode } from './types';
import { lightTheme } from './lightTheme';
import { darkTheme } from './darkTheme';
import { spacing } from '../tokens/spacing';
import { radius } from '../tokens/radius';
import { shadows } from '../tokens/shadows';
import { duration, easing, springConfig } from '../tokens/animation';
import { glass } from '../tokens/glass';
import { fontSize, lineHeight, fontWeight, fontFamily, textStyles } from '../tokens/typography';

export interface ThemeContextValue {
  theme: Theme;
  colors: Theme['colors'];
  spacing: typeof spacing;
  radius: typeof radius;
  shadows: typeof shadows;
  animation: { duration: typeof duration; easing: typeof easing; springConfig: typeof springConfig };
  glass: typeof glass;
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
      ? (systemScheme === 'dark' ? 'dark' : 'light')
      : modeOverride;

  const theme = resolvedMode === 'dark' ? darkTheme : lightTheme;

  const value: ThemeContextValue = {
    theme,
    colors: theme.colors,
    spacing,
    radius,
    shadows,
    animation: { duration, easing, springConfig },
    glass,
    typography: { fontSize, lineHeight, fontWeight, fontFamily, textStyles },
    colorMode: resolvedMode,
    setColorMode: setModeOverride,
  };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}
