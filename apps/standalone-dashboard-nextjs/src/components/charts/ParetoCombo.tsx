'use client';

import { useMemo } from 'react';
import dynamic from 'next/dynamic';
import { useDrillHandler } from '@/lib/hooks';
import type { ParetoCategory } from '@/lib/supabase/types';

const Plot = dynamic(() => import('react-plotly.js'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-64">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
    </div>
  ),
});

interface ParetoComboProps {
  data: ParetoCategory[];
  title?: string;
  height?: number;
  loading?: boolean;
  error?: string;
  onDrill?: (category: string, label: string) => void;
}

export default function ParetoCombo({
  data = [],
  title = 'Pareto Analysis',
  height = 400,
  loading = false,
  error,
  onDrill,
}: ParetoComboProps) {
  const { handleDrillDown } = useDrillHandler();

  const chartData = useMemo(() => {
    if (!data?.length) return { bars: [], line: [] };

    // Sort by revenue descending
    const sortedData = [...data].sort((a, b) => b.revenue - a.revenue);
    
    // Calculate cumulative percentages
    let cumulativeRevenue = 0;
    const totalRevenue = sortedData.reduce((sum, item) => sum + item.revenue, 0);
    
    const processedData = sortedData.map((item) => {
      cumulativeRevenue += item.revenue;
      const cumulativePct = (cumulativeRevenue / totalRevenue) * 100;
      return {
        ...item,
        cumulative_pct: cumulativePct,
      };
    });

    // Prepare bar chart data (revenue)
    const bars = {
      x: processedData.map(d => d.category),
      y: processedData.map(d => d.revenue),
      type: 'bar' as const,
      name: 'Revenue',
      marker: {
        color: processedData.map((_, i) => i < processedData.length * 0.2 ? '#1f77b4' : '#aec7e8'),
        line: { color: '#1f77b4', width: 1 },
      },
      yaxis: 'y',
      hovertemplate: '<b>%{x}</b><br>Revenue: ₱%{y:,.0f}<br>Rank: %{customdata}<extra></extra>',
      customdata: processedData.map((_, i) => i + 1),
    };

    // Prepare line chart data (cumulative percentage)
    const line = {
      x: processedData.map(d => d.category),
      y: processedData.map(d => d.cumulative_pct),
      type: 'scatter' as const,
      mode: 'lines+markers' as const,
      name: 'Cumulative %',
      line: {
        color: '#ff7f0e',
        width: 3,
      },
      marker: {
        color: '#ff7f0e',
        size: 6,
      },
      yaxis: 'y2',
      hovertemplate: '<b>%{x}</b><br>Cumulative: %{y:.1f}%<extra></extra>',
    };

    // Add 80% reference line
    const referenceLines = [
      {
        x: processedData.map(d => d.category),
        y: Array(processedData.length).fill(80),
        type: 'scatter' as const,
        mode: 'lines' as const,
        name: '80% Line',
        line: {
          color: '#d62728',
          width: 2,
          dash: 'dash',
        },
        yaxis: 'y2',
        hovertemplate: '80% Reference<extra></extra>',
        showlegend: true,
      }
    ];

    return { bars: [bars], line: [line], referenceLines };
  }, [data]);

  const layout = {
    title: {
      text: title,
      font: { size: 16, color: '#1f2937' },
    },
    xaxis: {
      title: 'Categories',
      tickangle: -45,
      automargin: true,
    },
    yaxis: {
      title: 'Revenue (₱)',
      tickformat: ',.0f',
      side: 'left' as const,
    },
    yaxis2: {
      title: 'Cumulative Percentage (%)',
      tickformat: '.1f',
      side: 'right' as const,
      overlaying: 'y' as const,
      range: [0, 100],
      dtick: 20,
    },
    legend: {
      orientation: 'h' as const,
      y: -0.2,
      x: 0.5,
      xanchor: 'center' as const,
    },
    margin: { t: 50, r: 60, b: 100, l: 80 },
    height,
    hovermode: 'x unified' as const,
    plot_bgcolor: 'transparent',
    paper_bgcolor: 'transparent',
    annotations: [
      {
        x: 0.02,
        y: 0.98,
        xref: 'paper',
        yref: 'paper',
        text: '<b>80/20 Rule:</b> Top 20% of categories typically generate 80% of revenue',
        showarrow: false,
        font: { size: 10, color: '#6b7280' },
        bgcolor: 'rgba(255,255,255,0.8)',
        bordercolor: '#d1d5db',
        borderwidth: 1,
      }
    ],
  };

  const config = {
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d'],
    toImageButtonOptions: {
      format: 'png' as const,
      filename: `pareto_analysis_${Date.now()}`,
      height: 600,
      width: 1000,
      scale: 2,
    },
  };

  const handleClick = (event: any) => {
    if (event.points?.[0]) {
      const point = event.points[0];
      const category = point.x;
      
      if (onDrill) {
        onDrill(category, category);
      } else {
        handleDrillDown('category', category, category);
      }
    }
  };

  if (loading) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-500">Loading Pareto analysis...</p>
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
          <p className="font-medium">Failed to load Pareto analysis</p>
          <p className="text-sm mt-1">{error}</p>
        </div>
      </div>
    );
  }

  if (!data?.length) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center text-gray-500">
          <p className="font-medium">No data available</p>
          <p className="text-sm mt-1">No categories to display in Pareto analysis</p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      <Plot
        data={[
          ...chartData.bars,
          ...chartData.line,
          ...chartData.referenceLines,
        ]}
        layout={layout}
        config={config}
        onClick={handleClick}
        className="w-full"
        useResizeHandler
      />
    </div>
  );
}