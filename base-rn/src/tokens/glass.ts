export const glass = {
  subtle: {
    blurAmount: 8,
    bgLight: 'rgba(255, 255, 255, 0.6)',
    bgDark: 'rgba(24, 24, 27, 0.6)',
    borderLight: 'rgba(255, 255, 255, 0.3)',
    borderDark: 'rgba(255, 255, 255, 0.08)',
  },
  default: {
    blurAmount: 16,
    bgLight: 'rgba(255, 255, 255, 0.72)',
    bgDark: 'rgba(24, 24, 27, 0.72)',
    borderLight: 'rgba(255, 255, 255, 0.4)',
    borderDark: 'rgba(255, 255, 255, 0.12)',
  },
  elevated: {
    blurAmount: 24,
    bgLight: 'rgba(255, 255, 255, 0.85)',
    bgDark: 'rgba(24, 24, 27, 0.85)',
    borderLight: 'rgba(255, 255, 255, 0.5)',
    borderDark: 'rgba(255, 255, 255, 0.16)',
  },
} as const;

export type GlassIntensity = keyof typeof glass;
