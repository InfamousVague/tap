export interface Shadow {
  shadowColor: string;
  shadowOffset: { width: number; height: number };
  shadowOpacity: number;
  shadowRadius: number;
  elevation: number;
}

function createShadow(
  offsetY: number,
  blurRadius: number,
  opacity: number,
  elevation: number,
  color = '#000000',
): Shadow {
  return {
    shadowColor: color,
    shadowOffset: { width: 0, height: offsetY },
    shadowOpacity: opacity,
    shadowRadius: blurRadius,
    elevation,
  };
}

export const shadows = {
  none: createShadow(0, 0, 0, 0),
  sm: createShadow(1, 2, 0.05, 2),
  md: createShadow(2, 4, 0.08, 4),
  lg: createShadow(4, 8, 0.12, 8),
  xl: createShadow(8, 16, 0.16, 12),
} as const;

export type ShadowKey = keyof typeof shadows;
