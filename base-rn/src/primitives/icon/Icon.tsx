import React from 'react';
import { SvgXml } from 'react-native-svg';
import { useTheme } from '../../theme';

export interface IconProps {
  svg: string;
  size?: number;
  color?: string;
}

export function Icon({ svg, size = 20, color }: IconProps) {
  const { colors } = useTheme();
  const resolvedColor = color || colors.text;

  // Replace currentColor in SVG with resolved color
  const coloredSvg = svg.replace(/currentColor/g, resolvedColor);

  return <SvgXml xml={coloredSvg} width={size} height={size} />;
}
