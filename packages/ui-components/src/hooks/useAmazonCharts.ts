/**
 * Amazon Chart Patterns Hook
 * Converts Dash Plotly patterns to React/Plotly.js
 */

import { useMemo } from 'react';
import { amazonTokens } from '../tokens/amazon-design-tokens';

export interface ChartData {
  x: (string | number)[];
  y: (string | number)[];
  labels?: string[];
  values?: number[];
  text?: string[];
}

export interface UseAmazonChartsOptions {
  colorScheme?: 'primary' | 'chart' | 'custom';
  customColors?: string[];
}

export const useAmazonCharts = (options: UseAmazonChartsOptions = {}) => {
  const { colorScheme = 'chart', customColors } = options;

  const colors = useMemo(() => {
    switch (colorScheme) {
      case 'primary':
        return [amazonTokens.colors.primary];
      case 'chart':
        return amazonTokens.colors.chartAccent;
      case 'custom':
        return customColors || amazonTokens.colors.chartAccent;
      default:
        return amazonTokens.colors.chartAccent;
    }
  }, [colorScheme, customColors]);

  // Amazon Bar Chart Pattern (from purchase_overview.py)
  const createBarChart = (
    data: ChartData,
    title: string,
    options: {
      showText?: boolean;
      textPosition?: 'outside' | 'inside' | 'auto';
    } = {}
  ) => {
    const { showText = true, textPosition = 'outside' } = options;

    return {
      data: [
        {
          x: data.x,
          y: data.y,
          type: 'bar' as const,
          text: showText ? data.text || data.y.map(val => String(val)) : undefined,
          textposition: textPosition,
          texttemplate: showText ? '%{text}' : undefined,
          marker: {
            color: colors[0],
          },
          hoverlabel: {
            bgcolor: 'rgba(255, 255, 255, 0.1)',
            font: { size: 12 },
          },
          hovertemplate: '<b>%{x}</b><br>Value: %{y:,}<extra></extra>',
        },
      ],
      layout: {
        title: {
          text: title,
          font: {
            family: amazonTokens.typography.fontFamily,
            size: 16,
            color: amazonTokens.colors.textPrimary,
          },
        },
        xaxis: {
          title: null,
          showticklabels: true,
          color: amazonTokens.colors.textPrimary,
        },
        yaxis: {
          title: null,
          showticklabels: false,
          color: amazonTokens.colors.textPrimary,
        },
        plot_bgcolor: 'rgba(0, 0, 0, 0)',
        paper_bgcolor: 'rgba(0, 0, 0, 0)',
        margin: { l: 35, r: 35, t: 60, b: 40 },
        font: {
          family: amazonTokens.typography.fontFamily,
          color: amazonTokens.colors.textPrimary,
        },
      },
    };
  };

  // Amazon Treemap Pattern (from purchase_overview.py)
  const createTreemap = (
    data: ChartData,
    title: string,
    options: {
      maxItems?: number;
      showValues?: boolean;
    } = {}
  ) => {
    const { maxItems = 5, showValues = true } = options;

    // Sort and limit data
    const sortedData = data.labels
      ?.map((label, index) => ({
        label,
        value: data.values?.[index] || 0,
      }))
      .sort((a, b) => b.value - a.value)
      .slice(0, maxItems) || [];

    return {
      data: [
        {
          type: 'treemap' as const,
          labels: sortedData.map(item => item.label),
          values: sortedData.map(item => item.value),
          parents: Array(sortedData.length).fill(''),
          textinfo: showValues ? 'label+value' : 'label',
          textfont: { size: 13 },
          marker: {
            colors: colors.slice(0, sortedData.length),
          },
        },
      ],
      layout: {
        title: {
          text: title,
          font: {
            family: amazonTokens.typography.fontFamily,
            size: 16,
            color: amazonTokens.colors.textPrimary,
          },
        },
        margin: { l: 35, r: 35, t: 60, b: 35 },
        font: {
          family: amazonTokens.typography.fontFamily,
          color: amazonTokens.colors.textPrimary,
        },
        hovermode: false,
      },
    };
  };

  // Amazon Pie Chart Pattern
  const createPieChart = (
    data: ChartData,
    title: string,
    options: {
      showPercentages?: boolean;
      hole?: number;
    } = {}
  ) => {
    const { showPercentages = true, hole = 0 } = options;

    return {
      data: [
        {
          type: 'pie' as const,
          labels: data.labels,
          values: data.values,
          textinfo: showPercentages ? 'label+percent' : 'label',
          textposition: 'auto',
          hole: hole,
          marker: {
            colors: colors,
          },
          hovertemplate: '<b>%{label}</b><br>Count: %{value}<br>Percentage: %{percent}<extra></extra>',
        },
      ],
      layout: {
        title: {
          text: title,
          font: {
            family: amazonTokens.typography.fontFamily,
            size: 16,
            color: amazonTokens.colors.textPrimary,
          },
        },
        margin: { l: 35, r: 35, t: 60, b: 35 },
        font: {
          family: amazonTokens.typography.fontFamily,
          color: amazonTokens.colors.textPrimary,
        },
        showlegend: true,
        legend: {
          orientation: 'v',
          x: 1.02,
          y: 0.5,
        },
      },
    };
  };

  // Amazon Histogram Pattern
  const createHistogram = (
    data: ChartData,
    title: string,
    options: {
      nbins?: number;
      showDensity?: boolean;
    } = {}
  ) => {
    const { nbins, showDensity = false } = options;

    return {
      data: [
        {
          x: data.x,
          type: 'histogram' as const,
          nbinsx: nbins,
          histnorm: showDensity ? 'density' : '',
          marker: {
            color: colors[0],
            opacity: 0.8,
          },
          hovertemplate: '<b>Range: %{x}</b><br>Count: %{y}<extra></extra>',
        },
      ],
      layout: {
        title: {
          text: title,
          font: {
            family: amazonTokens.typography.fontFamily,
            size: 16,
            color: amazonTokens.colors.textPrimary,
          },
        },
        xaxis: {
          title: null,
          color: amazonTokens.colors.textPrimary,
        },
        yaxis: {
          title: null,
          color: amazonTokens.colors.textPrimary,
        },
        plot_bgcolor: 'rgba(0, 0, 0, 0)',
        paper_bgcolor: 'rgba(0, 0, 0, 0)',
        margin: { l: 35, r: 35, t: 60, b: 40 },
        font: {
          family: amazonTokens.typography.fontFamily,
          color: amazonTokens.colors.textPrimary,
        },
      },
    };
  };

  return {
    createBarChart,
    createTreemap,
    createPieChart,
    createHistogram,
    colors,
  };
};