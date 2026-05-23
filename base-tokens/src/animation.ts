export const duration = {
  instant: 100,
  fast: 150,
  normal: 250,
  slow: 400,
  slower: 600,
} as const;

export const easingValues = {
  default: [0.25, 0.1, 0.25, 1] as const,
  easeIn: [0.42, 0, 1, 1] as const,
  easeOut: [0, 0, 0.58, 1] as const,
  easeInOut: [0.42, 0, 0.58, 1] as const,
  spring: [0.175, 0.885, 0.32, 1.275] as const,
  bounce: [0.68, -0.55, 0.265, 1.55] as const,
} as const;

export const springConfig = {
  gentle: { damping: 20, stiffness: 150, mass: 1 },
  snappy: { damping: 15, stiffness: 300, mass: 0.8 },
  bouncy: { damping: 10, stiffness: 200, mass: 1 },
  stiff: { damping: 30, stiffness: 400, mass: 1 },
} as const;

export type DurationKey = keyof typeof duration;
export type SpringConfigKey = keyof typeof springConfig;
export type EasingKey = keyof typeof easingValues;
