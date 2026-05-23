// ──────────────────────────────────────────────
// Raw color palettes
// ──────────────────────────────────────────────

export const gray = {
  50: '#fafafa',
  100: '#f4f4f5',
  200: '#e4e4e7',
  300: '#d4d4d8',
  400: '#a1a1aa',
  500: '#71717a',
  600: '#52525b',
  700: '#3f3f46',
  800: '#27272a',
  900: '#18181b',
  950: '#09090b',
} as const;

export const amber = {
  50: '#fffbeb',
  100: '#fef3c7',
  200: '#fde68a',
  300: '#fcd34d',
  400: '#fbbf24',
  500: '#f59e0b',
  600: '#d97706',
  700: '#b45309',
  800: '#92400e',
  900: '#78350f',
  950: '#451a03',
} as const;

export const red = {
  50: '#fef2f2',
  100: '#fee2e2',
  200: '#fecaca',
  300: '#fca5a5',
  400: '#f87171',
  500: '#ef4444',
  600: '#dc2626',
  700: '#b91c1c',
  800: '#991b1b',
  900: '#7f1d1d',
} as const;

export const green = {
  50: '#f0fdf4',
  100: '#dcfce7',
  200: '#bbf7d0',
  300: '#86efac',
  400: '#4ade80',
  500: '#22c55e',
  600: '#16a34a',
  700: '#15803d',
  800: '#166534',
  900: '#14532d',
} as const;

export const blue = {
  50: '#eff6ff',
  100: '#dbeafe',
  200: '#bfdbfe',
  300: '#93c5fd',
  400: '#60a5fa',
  500: '#3b82f6',
  600: '#2563eb',
  700: '#1d4ed8',
  800: '#1e40af',
  900: '#1e3a8a',
} as const;

export const orange = {
  50: '#fff7ed',
  100: '#ffedd5',
  200: '#fed7aa',
  300: '#fdba74',
  400: '#fb923c',
  500: '#f97316',
  600: '#ea580c',
  700: '#c2410c',
  800: '#9a3412',
  900: '#7c2d12',
} as const;

export const white = '#ffffff';
export const black = '#000000';
export const transparent = 'transparent';

// ──────────────────────────────────────────────
// Semantic color maps (light / dark)
// ──────────────────────────────────────────────

export interface SemanticColors {
  bg: string;
  bgSubtle: string;
  bgMuted: string;
  bgElevated: string;
  bgInverse: string;

  text: string;
  textSubtle: string;
  textMuted: string;
  textInverse: string;

  border: string;
  borderSubtle: string;
  borderFocus: string;

  accent: string;
  accentSubtle: string;
  accentText: string;
  accentHover: string;

  success: string;
  successSubtle: string;
  error: string;
  errorSubtle: string;
  warning: string;
  warningSubtle: string;
  info: string;
  infoSubtle: string;

  interactive: string;
  interactiveHover: string;
  interactiveActive: string;
  interactiveDisabled: string;

  overlay: string;
  scrim: string;
}

export const lightColors: SemanticColors = {
  bg: white,
  bgSubtle: gray[50],
  bgMuted: gray[100],
  bgElevated: white,
  bgInverse: gray[900],

  text: gray[900],
  textSubtle: gray[600],
  textMuted: gray[400],
  textInverse: white,

  border: gray[200],
  borderSubtle: gray[100],
  borderFocus: amber[500],

  accent: amber[500],
  accentSubtle: amber[50],
  accentText: amber[700],
  accentHover: amber[600],

  success: green[500],
  successSubtle: green[50],
  error: red[500],
  errorSubtle: red[50],
  warning: orange[500],
  warningSubtle: orange[50],
  info: blue[500],
  infoSubtle: blue[50],

  interactive: gray[900],
  interactiveHover: gray[800],
  interactiveActive: gray[700],
  interactiveDisabled: gray[300],

  overlay: 'rgba(0, 0, 0, 0.4)',
  scrim: 'rgba(0, 0, 0, 0.6)',
};

export const darkColors: SemanticColors = {
  bg: gray[950],
  bgSubtle: gray[900],
  bgMuted: gray[800],
  bgElevated: gray[900],
  bgInverse: white,

  text: gray[50],
  textSubtle: gray[400],
  textMuted: gray[600],
  textInverse: gray[900],

  border: gray[800],
  borderSubtle: gray[900],
  borderFocus: amber[500],

  accent: amber[500],
  accentSubtle: 'rgba(245, 158, 11, 0.12)',
  accentText: amber[400],
  accentHover: amber[400],

  success: green[400],
  successSubtle: 'rgba(34, 197, 94, 0.12)',
  error: red[400],
  errorSubtle: 'rgba(239, 68, 68, 0.12)',
  warning: orange[400],
  warningSubtle: 'rgba(249, 115, 22, 0.12)',
  info: blue[400],
  infoSubtle: 'rgba(59, 130, 246, 0.12)',

  interactive: white,
  interactiveHover: gray[200],
  interactiveActive: gray[300],
  interactiveDisabled: gray[700],

  overlay: 'rgba(0, 0, 0, 0.6)',
  scrim: 'rgba(0, 0, 0, 0.8)',
};
