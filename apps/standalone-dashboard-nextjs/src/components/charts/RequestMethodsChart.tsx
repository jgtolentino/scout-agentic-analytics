'use client';

import { useMemo } from 'react';
import dynamic from 'next/dynamic';

const Plot = dynamic(() => import('react-plotly.js'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-64">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
    </div>
  ),
});
import type { RequestMethod, AcceptanceByMethod } from '@/lib/supabase/types';

interface RequestMethodsChartProps {
  requestData: RequestMethod[];
  acceptanceData: AcceptanceByMethod[];
  title?: string;
  height?: number;
  loading?: boolean;
  error?: string;
}

export default function RequestMethodsChart({
  requestData = [],
  acceptanceData = [],
  title = 'Request Methods & Acceptance Rates',
  height = 400,
  loading = false,
  error,
}: RequestMethodsChartProps) {
  const chartData = useMemo(() => {
    if (!requestData?.length && !acceptanceData?.length) return null;

    // Combine request and acceptance data
    const combinedData = requestData.map(req => {
      const acceptance = acceptanceData.find(acc => acc.method === req.method);
      return {
        method: req.method,
        count: req.count,
        acceptance_rate: acceptance?.acceptance_rate || 0,
      };
    });

    // Sort by count (descending)
    combinedData.sort((a, b) => b.count - a.count);

    // Bar chart for request counts
    const barData = {
      x: combinedData.map(d => d.method),
      y: combinedData.map(d => d.count),
      type: 'bar' as const,
      name: 'Request Count',
      marker: {
        color: '#3b82f6',
        opacity: 0.8,
      },
      yaxis: 'y',
      hovertemplate: '<b>%{x}</b><br>Requests: %{y:,.0f}<extra></extra>',
    };

    // Line chart for acceptance rates
    const lineData = {
      x: combinedData.map(d => d.method),
      y: combinedData.map(d => d.acceptance_rate * 100),
      type: 'scatter' as const,
      mode: 'lines+markers' as const,
      name: 'Acceptance Rate (%)',
      line: {
        color: '#f59e0b',
        width: 3,
      },
      marker: {
        color: '#f59e0b',
        size: 8,
      },
      yaxis: 'y2',
      hovertemplate: '<b>%{x}</b><br>Acceptance: %{y:.1f}%<extra></extra>',
    };

    // Add average acceptance rate line
    const avgAcceptance = combinedData.reduce((sum, d) => sum + d.acceptance_rate, 0) / combinedData.length * 100;
    const avgLine = {
      x: combinedData.map(d => d.method),
      y: Array(combinedData.length).fill(avgAcceptance),
      type: 'scatter' as const,
      mode: 'lines' as const,
      name: 'Avg Acceptance',
      line: {
        color: '#ef4444',
        width: 2,
        dash: 'dash',
      },
      yaxis: 'y2',
      hovertemplate: `Average: ${avgAcceptance.toFixed(1)}%<extra></extra>`,
    };

    return { barData, lineData, avgLine, combinedData };
  }, [requestData, acceptanceData]);

  const layout = {
    title: {
      text: title,
      font: { size: 16, color: '#1f2937' },
    },
    xaxis: {
      title: 'Request Method',
      tickangle: -45,
      automargin: true,
    },
    yaxis: {
      title: 'Request Count',
      side: 'left' as const,
    },
    yaxis2: {
      title: 'Acceptance Rate (%)',
      side: 'right' as const,
      overlaying: 'y' as const,
      range: [0, 100],
    },
    legend: {
      orientation: 'h' as const,
      y: -0.2,
      x: 0.5,
      xanchor: 'center' as const,
    },
    margin: { t: 50, r: 60, b: 100, l: 60 },
    height,
    hovermode: 'x unified' as const,
    plot_bgcolor: 'transparent',
    paper_bgcolor: 'transparent',
    font: { 
      family: "Inter, system-ui, -apple-system, 'Segoe UI', Roboto", 
      color: "#2b2b2b" 
    },
  };

  const config = {
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d'],
    toImageButtonOptions: {
      format: 'png' as const,
      filename: `request_methods_${Date.now()}`,
      height: 500,
      width: 800,
      scale: 2,
    },
  };

  if (loading) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-500">Loading request methods...</p>
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
          <p className="font-medium">Failed to load request methods</p>
          <p className="text-sm mt-1">{error}</p>
        </div>
      </div>
    );
  }

  if (!requestData?.length && !acceptanceData?.length || !chartData) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center text-gray-500">
          <p className="font-medium">No request data available</p>
          <p className="text-sm mt-1">Request methods will appear when user interaction data is available</p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      {/* Summary stats */}
      <div className="mb-4 grid grid-cols-1 md:grid-cols-4 gap-4 text-sm">
        <div className="text-center">
          <div className="font-medium text-gray-700">Total Methods</div>
          <div className="text-xl font-bold text-blue-600">
            {chartData.combinedData.length}
          </div>
        </div>
        <div className="text-center">
          <div className="font-medium text-gray-700">Total Requests</div>
          <div className="text-xl font-bold text-green-600">
            {chartData.combinedData.reduce((sum, d) => sum + d.count, 0).toLocaleString()}
          </div>
        </div>
        <div className="text-center">
          <div className="font-medium text-gray-700">Top Method</div>
          <div className="text-lg font-bold text-purple-600">
            {chartData.combinedData[0]?.method || 'N/A'}
          </div>
        </div>
        <div className="text-center">
          <div className="font-medium text-gray-700">Avg Acceptance</div>
          <div className="text-xl font-bold text-orange-600">
            {chartData.combinedData.length > 0
              ? `${(chartData.combinedData.reduce((sum, d) => sum + d.acceptance_rate, 0) / chartData.combinedData.length * 100).toFixed(1)}%`
              : '0%'
            }
          </div>
        </div>
      </div>

      <Plot
        data={[chartData.barData, chartData.lineData, chartData.avgLine]}
        layout={layout}
        config={config}
        className="w-full"
        useResizeHandler
      />
      
      {/* Method descriptions */}
      <div className="mt-4 text-xs text-gray-500 border-t pt-2">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
          <div><strong>Voice:</strong> Voice commands and queries</div>
          <div><strong>Text:</strong> Text-based search and input</div>
          <div><strong>Visual:</strong> Image search and visual queries</div>
          <div><strong>Touch:</strong> Touch gestures and taps</div>
        </div>
      </div>
    </div>
  );
}