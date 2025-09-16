'use client';

import { useState, useEffect } from 'react';
import { useFilterBus } from '../../lib/store';
import { competitiveAPI, type CohortRetentionData } from '../../lib/api/competitive';

interface CohortRetentionProps {
  height?: number;
  showMetadata?: boolean;
  onCellClick?: (cohort: string, period: string, retention: number) => void;
}

export function CohortRetention({ 
  height = 400, 
  showMetadata = true,
  onCellClick 
}: CohortRetentionProps) {
  const { filters, updateFilters } = useFilterBus();
  const [data, setData] = useState<CohortRetentionData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [hoveredCell, setHoveredCell] = useState<{ cohort: number; period: number } | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      setError(null);
      try {
        const result = await competitiveAPI.getCohortRetention(filters);
        setData(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load cohort data');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [filters]);

  const getRetentionColor = (retention: number): string => {
    if (retention >= 80) return 'bg-emerald-600';
    if (retention >= 70) return 'bg-emerald-500';
    if (retention >= 60) return 'bg-yellow-500';
    if (retention >= 50) return 'bg-yellow-400';
    if (retention >= 40) return 'bg-orange-400';
    if (retention >= 30) return 'bg-orange-500';
    if (retention >= 20) return 'bg-red-400';
    return 'bg-red-500';
  };

  const getRetentionOpacity = (retention: number): string => {
    const intensity = Math.min(retention / 100, 1);
    return `opacity-${Math.max(20, Math.floor(intensity * 100))}`;
  };

  const handleCellClick = (cohortIndex: number, periodIndex: number, retention: number) => {
    if (!data) return;
    
    // Generate cohort labels from the retention data
    const cohortLabels = ['Jul 2024', 'Aug 2024', 'Sep 2024', 'Oct 2024', 'Nov 2024', 'Dec 2024'];
    const cohort = cohortLabels[cohortIndex] || `Cohort ${cohortIndex}`;
    const period = data.periods[periodIndex];
    
    // Update global filters to drill down
    updateFilters({ cohort });
    
    // Notify parent component
    if (onCellClick) {
      onCellClick(cohort, period, retention);
    }
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height }}>
        <div className="flex items-center justify-center h-full">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
          <span className="ml-2 text-gray-600">Loading cohort data...</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height }}>
        <div className="flex items-center justify-center h-full text-red-600">
          <span>Error: {error instanceof Error ? error.message : String(error || 'Unknown error')}</span>
        </div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height }}>
        <div className="flex items-center justify-center h-full text-gray-500">
          <span>No cohort data available</span>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height }}>
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Brand Cohort Retention</h3>
          <p className="text-sm text-gray-600">Customer retention by acquisition cohort over time</p>
        </div>
        {showMetadata && data.metadata && (
          <div className="text-right">
            <div className="text-sm text-gray-500">Avg Retention</div>
            <div className="text-xl font-bold text-gray-900">{data.metadata.averageRetention}%</div>
          </div>
        )}
      </div>

      {/* Heatmap Container */}
      <div className="relative overflow-auto" style={{ height: height - 120 }}>
        <div className="min-w-max">
          {/* Period Headers */}
          <div className="grid grid-flow-col gap-1 mb-2 ml-24">
            {data.periods.map((period, index) => (
              <div 
                key={period} 
                className="text-xs font-medium text-gray-700 text-center p-2 w-16"
              >
                {period}
              </div>
            ))}
          </div>

          {/* Heatmap Grid */}
          <div className="space-y-1">
            {data.retention.map((cohortRetention, cohortIndex) => {
              const cohortLabels = ['Jul 2024', 'Aug 2024', 'Sep 2024', 'Oct 2024', 'Nov 2024', 'Dec 2024'];
              return (
                <div key={cohortIndex} className="flex items-center gap-1">
                  {/* Cohort Label */}
                  <div className="w-20 text-xs font-medium text-gray-700 text-right pr-2">
                    {cohortLabels[cohortIndex] || `Cohort ${cohortIndex}`}
                  </div>
                
                {/* Customer Count */}
                <div className="w-12 text-xs text-gray-500 text-center">
                  {data.customerCounts[cohortIndex]?.toLocaleString() || '-'}
                </div>

                {/* Retention Cells */}
                <div className="grid grid-flow-col gap-1">
                  {cohortRetention.map((retention, periodIndex) => (
                    <div
                      key={`${cohortIndex}-${periodIndex}`}
                      className={`
                        w-16 h-8 rounded cursor-pointer transition-all duration-200
                        flex items-center justify-center text-xs font-medium text-white
                        ${getRetentionColor(retention)}
                        ${hoveredCell?.cohort === cohortIndex && hoveredCell?.period === periodIndex 
                          ? 'ring-2 ring-indigo-500 transform scale-105' 
                          : 'hover:ring-1 hover:ring-gray-300'
                        }
                      `}
                      onClick={() => handleCellClick(cohortIndex, periodIndex, retention)}
                      onMouseEnter={() => setHoveredCell({ cohort: cohortIndex, period: periodIndex })}
                      onMouseLeave={() => setHoveredCell(null)}
                      title={`${data.periods[periodIndex]}: ${retention}% retention`}
                    >
                      {retention.toFixed(0)}%
                    </div>
                  ))}
                </div>
              </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Legend & Metadata */}
      <div className="flex items-center justify-between pt-4 border-t border-gray-100">
        {/* Color Legend */}
        <div className="flex items-center space-x-2">
          <span className="text-xs text-gray-500">Retention Rate:</span>
          <div className="flex items-center space-x-1">
            <div className="w-3 h-3 rounded bg-red-500"></div>
            <span className="text-xs text-gray-500">20%</span>
            <div className="w-3 h-3 rounded bg-yellow-500"></div>
            <span className="text-xs text-gray-500">60%</span>
            <div className="w-3 h-3 rounded bg-emerald-600"></div>
            <span className="text-xs text-gray-500">80%+</span>
          </div>
        </div>

        {/* Metadata */}
        {showMetadata && data.metadata && (
          <div className="flex items-center space-x-6 text-xs text-gray-500">
            <div>
              <span className="font-medium">Total Cohorts:</span> {data.metadata.totalCohorts}
            </div>
            <div>
              <span className="font-medium">Best Performing:</span> {data.metadata.bestPerformingCohort}
            </div>
          </div>
        )}
      </div>

      {/* Tooltip for hovered cell */}
      {hoveredCell && data && (
        <div className="absolute z-10 bg-gray-900 text-white text-xs rounded px-2 py-1 pointer-events-none">
          <div className="font-medium">
            {['Jul 2024', 'Aug 2024', 'Sep 2024', 'Oct 2024', 'Nov 2024', 'Dec 2024'][hoveredCell.cohort] || `Cohort ${hoveredCell.cohort}`}
          </div>
          <div>
            {data.periods[hoveredCell.period]}: {data.retention[hoveredCell.cohort][hoveredCell.period].toFixed(1)}%
          </div>
          <div className="text-gray-300">
            {data.customerCounts[hoveredCell.cohort]?.toLocaleString()} customers
          </div>
        </div>
      )}
    </div>
  );
}