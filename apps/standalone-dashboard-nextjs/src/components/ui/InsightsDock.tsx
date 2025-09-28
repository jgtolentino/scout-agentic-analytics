'use client';

import { useState, useMemo } from 'react';
import { useInsights } from '@/lib/hooks';
import type { Insight } from '@/lib/types';

interface InsightsDockProps {
  filters?: any;
  position?: 'right' | 'left' | 'bottom';
  className?: string;
  maxInsights?: number;
  autoRefresh?: boolean;
}

const INSIGHT_ICONS = {
  trend: '📈',
  anomaly: '🚨',
  forecast: '🔮',
  recommendation: '💡',
} as const;

const INSIGHT_COLORS = {
  trend: 'bg-green-50 border-green-200 text-green-800',
  anomaly: 'bg-red-50 border-red-200 text-red-800',
  forecast: 'bg-purple-50 border-purple-200 text-purple-800',
  recommendation: 'bg-blue-50 border-blue-200 text-blue-800',
} as const;

export default function InsightsDock({
  filters,
  position = 'right',
  className = '',
  maxInsights = 5,
  autoRefresh = true,
}: InsightsDockProps) {
  const [isExpanded, setIsExpanded] = useState(true);
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [showDetails, setShowDetails] = useState<string | null>(null);

  const { data: insights = [], isLoading, error, mutate } = useInsights(filters);

  // Filter and sort insights
  const processedInsights = useMemo(() => {
    let filteredInsights = insights;

    // Filter by type if selected
    if (selectedType) {
      filteredInsights = insights.filter(insight => insight.type === selectedType);
    }

    // Sort by confidence and timestamp
    filteredInsights.sort((a, b) => {
      // First by confidence (descending)
      if (b.confidence !== a.confidence) {
        return b.confidence - a.confidence;
      }
      // Then by timestamp (most recent first)
      return new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime();
    });

    return filteredInsights.slice(0, maxInsights);
  }, [insights, selectedType, maxInsights]);

  // Get insight type counts
  const typeCounts = useMemo(() => {
    const counts = insights.reduce((acc, insight) => {
      acc[insight.type] = (acc[insight.type] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    return counts;
  }, [insights]);

  const handleRefresh = () => {
    mutate();
  };

  const formatTimestamp = (timestamp: string) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  const getPositionClasses = () => {
    switch (position) {
      case 'left':
        return 'left-0 top-20 bottom-20';
      case 'bottom':
        return 'bottom-0 left-20 right-20 max-h-80';
      case 'right':
      default:
        return 'right-0 top-20 bottom-20';
    }
  };

  const getExpandDirection = () => {
    switch (position) {
      case 'left':
        return isExpanded ? 'translate-x-0' : '-translate-x-full';
      case 'bottom':
        return isExpanded ? 'translate-y-0' : 'translate-y-full';
      case 'right':
      default:
        return isExpanded ? 'translate-x-0' : 'translate-x-full';
    }
  };

  return (
    <div
      className={`fixed ${getPositionClasses()} z-30 transition-transform duration-300 ${getExpandDirection()} ${className}`}
    >
      <div className="h-full flex flex-col bg-white border-l border-gray-200 shadow-lg">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
          <div className="flex items-center gap-2">
            <div className="text-lg">🔍</div>
            <h3 className="font-medium text-gray-900">Insights</h3>
            {insights.length > 0 && (
              <span className="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded-full">
                {insights.length}
              </span>
            )}
          </div>
          
          <div className="flex items-center gap-1">
            {/* Refresh button */}
            <button
              onClick={handleRefresh}
              className="p-1.5 text-gray-500 hover:text-gray-700 hover:bg-gray-200 rounded-md transition-colors"
              title="Refresh insights"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            </button>

            {/* Collapse button */}
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              className="p-1.5 text-gray-500 hover:text-gray-700 hover:bg-gray-200 rounded-md transition-colors"
              title={isExpanded ? 'Collapse' : 'Expand'}
            >
              <svg
                className={`w-4 h-4 transition-transform ${position === 'right' && isExpanded ? 'rotate-180' : ''}`}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
        </div>

        {/* Type filters */}
        <div className="p-3 border-b border-gray-200 bg-gray-50">
          <div className="flex flex-wrap gap-1">
            <button
              onClick={() => setSelectedType(null)}
              className={`px-2 py-1 text-xs rounded-md transition-colors ${
                selectedType === null
                  ? 'bg-blue-100 text-blue-800 border border-blue-200'
                  : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
              }`}
            >
              All ({insights.length})
            </button>
            {Object.entries(typeCounts).map(([type, count]) => (
              <button
                key={type}
                onClick={() => setSelectedType(selectedType === type ? null : type)}
                className={`px-2 py-1 text-xs rounded-md transition-colors capitalize ${
                  selectedType === type
                    ? 'bg-blue-100 text-blue-800 border border-blue-200'
                    : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'
                }`}
              >
                {INSIGHT_ICONS[type as keyof typeof INSIGHT_ICONS]} {type} ({count})
              </button>
            ))}
          </div>
        </div>

        {/* Insights list */}
        <div className="flex-1 overflow-y-auto">
          {isLoading && (
            <div className="p-4 text-center text-gray-500">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 mx-auto mb-2"></div>
              Loading insights...
            </div>
          )}

          {error && (
            <div className="p-4 text-center text-red-600">
              <div className="text-sm">Failed to load insights</div>
              <button onClick={handleRefresh} className="text-xs underline mt-1">
                Retry
              </button>
            </div>
          )}

          {!isLoading && !error && processedInsights.length === 0 && (
            <div className="p-4 text-center text-gray-500">
              <div className="text-2xl mb-2">🔍</div>
              <div className="text-sm">No insights available</div>
              <div className="text-xs text-gray-400 mt-1">
                Insights will appear as data patterns are detected
              </div>
            </div>
          )}

          {!isLoading && !error && processedInsights.length > 0 && (
            <div className="space-y-2 p-3">
              {processedInsights.map((insight) => (
                <div
                  key={insight.id}
                  className={`p-3 rounded-lg border cursor-pointer transition-all hover:shadow-sm ${INSIGHT_COLORS[insight.type]}`}
                  onClick={() => setShowDetails(showDetails === insight.id ? null : insight.id)}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex items-start gap-2 flex-1">
                      <span className="text-lg">
                        {INSIGHT_ICONS[insight.type]}
                      </span>
                      <div className="flex-1 min-w-0">
                        <h4 className="font-medium text-sm leading-tight">
                          {insight.title}
                        </h4>
                        <p className="text-xs mt-1 leading-relaxed">
                          {insight.description}
                        </p>
                        
                        {showDetails === insight.id && (
                          <div className="mt-2 pt-2 border-t border-current border-opacity-20">
                            <div className="flex items-center justify-between text-xs">
                              <span>Confidence: {(insight.confidence * 100).toFixed(0)}%</span>
                              <span>{formatTimestamp(insight.timestamp)}</span>
                            </div>
                            {insight.metadata && (
                              <div className="mt-1 text-xs opacity-75">
                                <pre className="whitespace-pre-wrap font-mono">
                                  {typeof insight.metadata === 'string' 
                                    ? insight.metadata 
                                    : JSON.stringify(insight.metadata, null, 2)
                                  }
                                </pre>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                    
                    <div className="flex items-center gap-2 ml-2">
                      <span className="text-sm font-bold">
                        {insight.delta}
                      </span>
                      <div className="w-2 h-2 rounded-full bg-current opacity-60"></div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-gray-200 bg-gray-50">
          <div className="text-xs text-gray-500 text-center">
            {autoRefresh && (
              <div className="mb-1">
                Auto-refreshing insights every 5 minutes
              </div>
            )}
            <div>
              Last updated: {formatTimestamp(new Date().toISOString())}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}