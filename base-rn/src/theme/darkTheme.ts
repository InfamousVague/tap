import { Theme } from './types';
import { gray, amber, green, red, orange, blue, white } from '../tokens/colors';

export const darkTheme: Theme = {
  mode: 'dark',
  colors: {
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
  },
};
