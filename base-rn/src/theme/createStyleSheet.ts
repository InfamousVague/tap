import { StyleSheet, ViewStyle, TextStyle, ImageStyle } from 'react-native';
import { ThemeContextValue } from './ThemeProvider';

type NamedStyles<T> = { [P in keyof T]: ViewStyle | TextStyle | ImageStyle };
type StyleFactory<T> = (theme: ThemeContextValue) => T;

/**
 * Creates a themed StyleSheet factory.
 * Usage:
 *   const useStyles = createStyleSheet((theme) => ({
 *     container: { backgroundColor: theme.colors.bg },
 *   }));
 *
 *   // In component:
 *   const theme = useTheme();
 *   const styles = useStyles(theme);
 */
export function createStyleSheet<T extends NamedStyles<T>>(
  factory: StyleFactory<T>
): (theme: ThemeContextValue) => T {
  // Cache per color mode to avoid recreating on every render
  const cache = new Map<string, T>();

  return (theme: ThemeContextValue) => {
    const key = theme.colorMode;
    if (cache.has(key)) {
      return cache.get(key)!;
    }
    const styles = StyleSheet.create(factory(theme)) as T;
    cache.set(key, styles);
    return styles;
  };
}
