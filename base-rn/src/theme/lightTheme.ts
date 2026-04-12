import { Theme } from './types';
import { gray, amber, green, red, orange, blue, white, black } from '../tokens/colors';

export const lightTheme: Theme = {
  mode: 'light',
  colors: {
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
  },
};
