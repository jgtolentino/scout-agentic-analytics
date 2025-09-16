'use client';

import { useMemo } from 'react';
import dynamic from 'next/dynamic';
import type { BehaviorKPIs as BehaviorKPIType } from '@/lib/supabase/types';

const Plot = dynamic(() => import('react-plotly.js'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-64">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
    </div>
  ),
});

interface BehaviorKPIsProps {
  data: BehaviorKPIType | null;
  title?: string;
  height?: number;
  loading?: boolean;
  error?: string;
}

export default function BehaviorKPIs({
  data,
  title = 'Behavior KPIs',
  height = 300,
  loading = false,
  error,
}: BehaviorKPIsProps) {
  const chartData = useMemo(() => {
    if (!data) return null;

    const kpis = [
      {
        label: 'Conversion Rate',
        value: data.conversion_rate,
        target: 0.15, // 15% target
        color: '#10b981',
        unit: '%'
      },
      {
        label: 'Suggestion Accept Rate',
        value: data.suggestion_accept_rate,
        target: 0.25, // 25% target
        color: '#3b82f6',
        unit: '%'
      },
      {
        label: 'Brand Loyalty Rate',
        value: data.brand_loyalty_rate,
        target: 0.60, // 60% target
        color: '#8b5cf6',
        unit: '%'
      }
    ];

    // Gauge charts for each KPI
    const gaugeData = kpis.map((kpi, index) => ({
      type: 'indicator' as const,
      mode: 'gauge+number+delta',
      value: kpi.value * 100,
      domain: { 
        row: 0, 
        column: index 
      },
      title: { 
        text: kpi.label,
        font: { size: 14 }
      },
      delta: { 
        reference: kpi.target * 100,
        increasing: { color: '#10b981' },
        decreasing: { color: '#ef4444' }
      },
      gauge: {
        axis: { range: [null, 100] },
        bar: { color: kpi.color },
        steps: [
          { range: [0, 50], color: '#fef3f2' },
          { range: [50, 80], color: '#fef7cd' },
          { range: [80, 100], color: '#f0fdf4' }
        ],
        threshold: {
          line: { color: '#dc2626', width: 4 },
          thickness: 0.75,
          value: kpi.target * 100
        }
      }
    }));

    return gaugeData;
  }, [data]);

  if (loading) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-500">Loading behavior KPIs...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-red-200"
        style={{ height }}
      >
        <div className="text-center text-red-600">
          <p className="font-medium">Failed to load behavior KPIs</p>
          <p className="text-sm mt-1">{error}</p>
        </div>
      </div>
    );
  }

  if (!data || !chartData) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center text-gray-500">
          <p className="font-medium">No behavior data available</p>
          <p className="text-sm mt-1">KPIs will appear when user behavior data is available</p>
        </div>
      </div>
    );
  }

  const layout = {
    title: {
      text: title,
      font: { size: 16, color: '#1f2937' },
    },
    grid: { 
      rows: 1, 
      columns: 3, 
      pattern: 'independent' 
    },
    margin: { t: 50, r: 20, b: 20, l: 20 },
    height,
    paper_bgcolor: 'transparent',
    font: { 
      family: "Inter, system-ui, -apple-system, 'Segoe UI', Roboto", 
      color: "#2b2b2b" 
    },
  };

  const config = {
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d', 'zoom2d'],
    toImageButtonOptions: {
      format: 'png' as const,
      filename: `behavior_kpis_${Date.now()}`,
      height: 400,
      width: 800,
      scale: 2,
    },
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      <Plot
        data={chartData}
        layout={layout}
        config={config}
        className="w-full"
        useResizeHandler
      />
      
      {/* Legend */}
      <div className="mt-4 text-xs text-gray-500 border-t pt-2">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-2">
          <div>
            <strong>Conversion Rate:</strong> Visitors who make a purchase
          </div>
          <div>
            <strong>Suggestion Accept:</strong> Users who accept AI recommendations
          </div>
          <div>
            <strong>Brand Loyalty:</strong> Customers who repeat purchase same brands
          </div>
        </div>
      </div>
    </div>
  );
}