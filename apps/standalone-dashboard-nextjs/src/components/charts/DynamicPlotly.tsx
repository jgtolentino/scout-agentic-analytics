'use client';

import { Suspense } from 'react';
import dynamic from 'next/dynamic';
import type { ComponentType } from 'react';

// Loading component for charts
function ChartLoading({ height = 300 }: { height?: number }) {
  return (
    <div 
      className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
      style={{ height }}
    >
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
        <p className="text-gray-500">Loading chart...</p>
      </div>
    </div>
  );
}

// Error boundary component
function ChartError({ height = 300, error }: { height?: number; error?: string }) {
  return (
    <div 
      className="flex items-center justify-center bg-white rounded-lg border border-red-200"
      style={{ height }}
    >
      <div className="text-center text-red-600">
        <p className="font-medium">Failed to load chart</p>
        {error && <p className="text-sm mt-1">{error}</p>}
      </div>
    </div>
  );
}

// Pre-created dynamic chart components with explicit imports
export const DynamicBehaviorKPIs = dynamic(
  () => import('./BehaviorKPIs'),
  {
    ssr: false,
    loading: () => <ChartLoading />,
  }
);

export const DynamicParetoCombo = dynamic(
  () => import('./ParetoCombo'),
  {
    ssr: false,
    loading: () => <ChartLoading />,
  }
);

export const DynamicChordSubstitutions = dynamic(
  () => import('./ChordSubstitutions'),
  {
    ssr: false,
    loading: () => <ChartLoading />,
  }
);

// Temporarily disable PhilippinesMap due to Turbopack module resolution issue
export const DynamicPhilippinesMap = dynamic(
  () => Promise.resolve(() => <ChartError error="PhilippinesMap temporarily disabled - Turbopack resolution issue with react-map-gl" />),
  {
    ssr: false,
    loading: () => <ChartLoading />,
  }
);

export const DynamicPlotlyAmazon = dynamic(
  () => import('./PlotlyAmazon'),
  {
    ssr: false,
    loading: () => <ChartLoading />,
  }
);

export const DynamicRequestMethodsChart = dynamic(
  () => import('./RequestMethodsChart'),
  {
    ssr: false,
    loading: () => <ChartLoading />,
  }
);

// Export the loading and error components for direct use
export { ChartLoading, ChartError };