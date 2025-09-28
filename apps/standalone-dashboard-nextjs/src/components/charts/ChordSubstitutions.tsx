'use client';

import { useMemo, useRef } from 'react';
import dynamic from 'next/dynamic';

const Plot = dynamic(() => import('react-plotly.js'), {
  ssr: false,
  loading: () => (
    <div className="flex items-center justify-center h-64">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
    </div>
  ),
});
import { useDrillHandler } from '@/lib/hooks';
import type { BasketPair } from '@/lib/types';

interface ChordSubstitutionsProps {
  data: BasketPair[];
  title?: string;
  height?: number;
  loading?: boolean;
  error?: string;
  minSupport?: number;
  minLift?: number;
  onDrill?: (categoryA: string, categoryB: string) => void;
}

export default function ChordSubstitutions({
  data = [],
  title = 'Market Basket Analysis - Category Associations',
  height = 500,
  loading = false,
  error,
  minSupport = 0.01,
  minLift = 1.0,
  onDrill,
}: ChordSubstitutionsProps) {
  const { handleDrillDown } = useDrillHandler();
  const plotRef = useRef<any>(null);

  const chartData = useMemo(() => {
    if (!data?.length) return null;

    // Filter data by minimum thresholds
    const filteredData = data.filter(
      item => item.support >= minSupport && item.lift >= minLift
    );

    if (!filteredData.length) return null;

    // Get unique categories
    const categories = Array.from(
      new Set([
        ...filteredData.map(d => d.category_a),
        ...filteredData.map(d => d.category_b)
      ])
    ).sort();

    // Create adjacency matrix for chord diagram
    const matrix = categories.map(() => categories.map(() => 0));
    const hoverText = categories.map(() => categories.map(() => ''));

    filteredData.forEach(item => {
      const indexA = categories.indexOf(item.category_a);
      const indexB = categories.indexOf(item.category_b);
      
      if (indexA !== -1 && indexB !== -1) {
        // Use lift as the strength of connection
        matrix[indexA][indexB] = item.lift;
        matrix[indexB][indexA] = item.lift; // Make symmetric for better visualization
        
        const hoverInfo = `
          <b>${item.category_a} → ${item.category_b}</b><br>
          Support: ${(item.support * 100).toFixed(2)}%<br>
          Confidence: ${(item.confidence * 100).toFixed(1)}%<br>
          Lift: ${item.lift.toFixed(2)}x
        `.trim();
        
        hoverText[indexA][indexB] = hoverInfo;
        hoverText[indexB][indexA] = hoverInfo;
      }
    });

    // Create sankey diagram as alternative to chord (plotly doesn't have native chord)
    const sankeyData = {
      type: 'sankey' as const,
      node: {
        pad: 15,
        thickness: 20,
        line: { color: 'black', width: 0.5 },
        label: categories,
        color: categories.map((_, i) => {
          const colors = [
            '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd',
            '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'
          ];
          return colors[i % colors.length];
        }),
        hovertemplate: '<b>%{label}</b><br>Total Connections: %{value}<extra></extra>',
      },
      link: {
        source: [] as number[],
        target: [] as number[],
        value: [] as number[],
        color: [] as string[],
        hovertemplate: '%{customdata}<extra></extra>',
        customdata: [] as string[],
      },
    };

    // Populate links
    filteredData.forEach(item => {
      const indexA = categories.indexOf(item.category_a);
      const indexB = categories.indexOf(item.category_b);
      
      if (indexA !== -1 && indexB !== -1 && indexA !== indexB) {
        sankeyData.link.source.push(indexA);
        sankeyData.link.target.push(indexB);
        sankeyData.link.value.push(item.lift);
        
        // Color based on lift strength
        const opacity = Math.min(item.lift / 3, 0.8); // Scale opacity by lift
        sankeyData.link.color.push(`rgba(0,116,217,${opacity})`);
        
        sankeyData.link.customdata.push(`
          <b>${item.category_a} → ${item.category_b}</b><br>
          Support: ${(item.support * 100).toFixed(2)}%<br>
          Confidence: ${(item.confidence * 100).toFixed(1)}%<br>
          Lift: ${item.lift.toFixed(2)}x<br>
          <i>Click to drill down</i>
        `.trim());
      }
    });

    return { sankeyData, categories, filteredData };
  }, [data, minSupport, minLift]);

  const layout = {
    title: {
      text: title,
      font: { size: 16, color: '#1f2937' },
    },
    font: { size: 10 },
    margin: { t: 50, r: 20, b: 20, l: 20 },
    height,
    plot_bgcolor: 'transparent',
    paper_bgcolor: 'transparent',
    annotations: [
      {
        x: 0.02,
        y: 0.98,
        xref: 'paper',
        yref: 'paper',
        text: `<b>Association Rules:</b> Support ≥ ${(minSupport * 100).toFixed(1)}%, Lift ≥ ${minLift.toFixed(1)}x`,
        showarrow: false,
        font: { size: 10, color: '#6b7280' },
        bgcolor: 'rgba(255,255,255,0.9)',
        bordercolor: '#d1d5db',
        borderwidth: 1,
      },
      {
        x: 0.02,
        y: 0.02,
        xref: 'paper',
        yref: 'paper',
        text: '<b>Flow Direction:</b> Left to Right shows "When buying A, also buy B"',
        showarrow: false,
        font: { size: 9, color: '#6b7280' },
        bgcolor: 'rgba(255,255,255,0.9)',
        bordercolor: '#d1d5db',
        borderwidth: 1,
      }
    ],
  };

  const config = {
    displayModeBar: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['pan2d', 'lasso2d', 'select2d', 'zoom2d'],
    toImageButtonOptions: {
      format: 'png' as const,
      filename: `basket_analysis_${Date.now()}`,
      height: 600,
      width: 1000,
      scale: 2,
    },
  };

  const handleClick = (event: any) => {
    if (event.points?.[0] && chartData) {
      const point = event.points[0];
      
      if (point.source !== undefined && point.target !== undefined) {
        const sourceCategory = chartData.categories[point.source];
        const targetCategory = chartData.categories[point.target];
        
        if (onDrill) {
          onDrill(sourceCategory, targetCategory);
        } else {
          // Drill down to the source category
          handleDrillDown('category', sourceCategory, sourceCategory);
        }
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
          <p className="text-gray-500">Loading basket analysis...</p>
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
          <p className="font-medium">Failed to load basket analysis</p>
          <p className="text-sm mt-1">{error}</p>
        </div>
      </div>
    );
  }

  if (!data?.length || !chartData) {
    return (
      <div 
        className="flex items-center justify-center bg-white rounded-lg border border-gray-200"
        style={{ height }}
      >
        <div className="text-center text-gray-500">
          <p className="font-medium">No associations found</p>
          <p className="text-sm mt-1">Try lowering the minimum support or lift thresholds</p>
          <div className="mt-3 text-xs">
            <p>Current filters: Support ≥ {(minSupport * 100).toFixed(1)}%, Lift ≥ {minLift.toFixed(1)}x</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      {/* Controls */}
      <div className="mb-4 flex flex-wrap gap-4 text-sm text-gray-600">
        <div>
          <span className="font-medium">Total Pairs:</span> {chartData.filteredData.length}
        </div>
        <div>
          <span className="font-medium">Categories:</span> {chartData.categories.length}
        </div>
        <div>
          <span className="font-medium">Avg Lift:</span> {
            (chartData.filteredData.reduce((sum, item) => sum + item.lift, 0) / chartData.filteredData.length).toFixed(2)
          }x
        </div>
      </div>
      
      <Plot
        ref={plotRef}
        data={[chartData.sankeyData]}
        layout={layout}
        config={config}
        onClick={handleClick}
        className="w-full"
        useResizeHandler
      />
      
      {/* Legend */}
      <div className="mt-4 text-xs text-gray-500 border-t pt-2">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-2">
          <div><strong>Support:</strong> How frequently items appear together</div>
          <div><strong>Confidence:</strong> Likelihood of buying B when buying A</div>
          <div><strong>Lift:</strong> How much more likely to buy together than separately</div>
        </div>
      </div>
    </div>
  );
}