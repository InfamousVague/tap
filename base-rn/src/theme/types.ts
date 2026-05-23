import type { SemanticColors } from '@mattssoftware/base-tokens';

export type ColorMode = 'light' | 'dark';

export interface Theme {
  mode: ColorMode;
  colors: SemanticColors;
}

export type { SemanticColors };
