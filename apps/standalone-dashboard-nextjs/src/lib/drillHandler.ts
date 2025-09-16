'use client';

import { useRouter } from 'next/navigation';
import { useFilterBus, Filters } from './store';

export type DrillConfig = {
  field: keyof Filters;
  targetPage?: string;
  breadcrumbLabel?: (value: string) => string;
};

export const useDrillHandler = () => {
  const router = useRouter();
  const { set: setFilters, pushCrumb } = useFilterBus();

  const handleDrill = (
    value: string,
    config: DrillConfig,
    currentPage: string = ''
  ) => {
    // Create breadcrumb
    const labelFn = config.breadcrumbLabel || ((v) => v);
    const crumb = {
      label: labelFn(value),
      filters: { [config.field]: value },
      path: config.targetPage || currentPage
    };

    // Push breadcrumb first
    pushCrumb(crumb);

    // Update filters
    setFilters({ [config.field]: value });

    // Navigate if target page specified
    if (config.targetPage && config.targetPage !== currentPage) {
      router.push(config.targetPage);
    }
  };

  return { handleDrill };
};

// Plotly click handler helper
export const createPlotlyDrillHandler = (
  config: DrillConfig,
  currentPage: string = ''
) => {
  return (data: any) => {
    const point = data.points?.[0];
    if (!point) return;
    
    // Extract value from different chart types
    let value: string;
    
    if (point.label) {
      // Pie charts, treemaps
      value = String(point.label);
    } else if (point.x) {
      // Bar charts, scatter plots
      value = String(point.x);
    } else if (point.y) {
      // Horizontal bars
      value = String(point.y);
    } else if (point.text) {
      // Text annotations
      value = String(point.text);
    } else {
      console.warn('Could not extract drill value from point:', point);
      return;
    }

    // Use the drill handler
    const { handleDrill } = useDrillHandler();
    handleDrill(value, config, currentPage);
  };
};

// Common drill configurations
export const DRILL_CONFIGS = {
  categoryToBehavior: {
    field: 'category' as keyof Filters,
    targetPage: '/behavior',
    breadcrumbLabel: (v: string) => `Category: ${v}`
  },
  categoryToProductMix: {
    field: 'category' as keyof Filters,
    targetPage: '/product-mix',
    breadcrumbLabel: (v: string) => `Category: ${v}`
  },
  brandToProductMix: {
    field: 'brand' as keyof Filters,
    targetPage: '/product-mix',
    breadcrumbLabel: (v: string) => `Brand: ${v}`
  },
  regionToExecutive: {
    field: 'region' as keyof Filters,
    targetPage: '/',
    breadcrumbLabel: (v: string) => `Region: ${v}`
  },
  daypartToBehavior: {
    field: 'daypart' as keyof Filters,
    targetPage: '/behavior',
    breadcrumbLabel: (v: string) => `Time: ${v}`
  }
} as const;