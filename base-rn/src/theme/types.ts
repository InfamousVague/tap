export type ColorMode = 'light' | 'dark';

export interface SemanticColors {
  // Backgrounds
  bg: string;
  bgSubtle: string;
  bgMuted: string;
  bgElevated: string;
  bgInverse: string;

  // Foreground / Text
  text: string;
  textSubtle: string;
  textMuted: string;
  textInverse: string;

  // Borders
  border: string;
  borderSubtle: string;
  borderFocus: string;

  // Accent (Amber)
  accent: string;
  accentSubtle: string;
  accentText: string;
  accentHover: string;

  // Status
  success: string;
  successSubtle: string;
  error: string;
  errorSubtle: string;
  warning: string;
  warningSubtle: string;
  info: string;
  infoSubtle: string;

  // Interactive
  interactive: string;
  interactiveHover: string;
  interactiveActive: string;
  interactiveDisabled: string;

  // Overlay
  overlay: string;
  scrim: string;
}

export interface Theme {
  mode: ColorMode;
  colors: SemanticColors;
}
