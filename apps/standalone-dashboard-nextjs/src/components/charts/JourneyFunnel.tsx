'use client';

import { useState, useEffect } from 'react';
import { useFilterBus } from '../../lib/store';
import { competitiveAPI, type JourneyFunnelData } from '../../lib/api/competitive';

interface JourneyFunnelProps {
  height?: number;
  showPathAnalysis?: boolean;
  onStepClick?: (step: string, count: number, percentage: number) => void;
  onPathClick?: (path: string[], conversionRate: number) => void;
}

export function JourneyFunnel({ 
  height = 600, 
  showPathAnalysis = true,
  onStepClick,
  onPathClick
}: JourneyFunnelProps) {
  const { filters, updateFilters } = useFilterBus();
  const [data, setData] = useState<JourneyFunnelData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedStep, setSelectedStep] = useState<number | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      setError(null);
      try {
        const result = await competitiveAPI.getJourneyFunnel(filters);
        setData(result);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load journey data');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [filters]);

  const handleStepClick = (stepIndex: number, step: JourneyFunnelData['steps'][0]) => {
    setSelectedStep(stepIndex);
    
    // Update global filters based on the step
    // This could filter to show only customers who reached this step
    if (onStepClick) {
      onStepClick(step.name, step.count, step.percentage);
    }
  };

  const handlePathClick = (path: string[], conversionRate: number) => {
    // Update filters to show this specific journey path
    if (onPathClick) {
      onPathClick(path, conversionRate);
    }
  };

  const getFunnelStepColor = (index: number, total: number): string => {
    const colors = [
      'bg-blue-600',
      'bg-indigo-600', 
      'bg-purple-600',
      'bg-pink-600',
      'bg-red-600'
    ];
    return colors[index % colors.length];
  };

  const getFunnelStepWidth = (percentage: number): string => {
    return `${Math.max(20, percentage)}%`;
  };

  if (loading) {
    return (
      <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height }}>
        <div className="flex items-center justify-center h-full">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
          <span className="ml-2 text-gray-600">Loading journey data...</span>
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
          <span>No journey data available</span>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-6" style={{ height }}>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-lg font-semibold text-gray-900">Customer Journey Funnel</h3>
          <p className="text-sm text-gray-600">Conversion rates through customer journey stages</p>
        </div>
        <div className="flex items-center space-x-4">
          <div className="text-right">
            <div className="text-sm text-gray-500">Overall Conversion</div>
            <div className="text-2xl font-bold text-gray-900">{data.conversion}%</div>
          </div>
          <div className="text-right">
            <div className="text-sm text-gray-500">Avg Time</div>
            <div className="text-lg font-semibold text-gray-900">{data.averageTime}m</div>
          </div>
        </div>
      </div>

      <div className={`grid ${showPathAnalysis ? 'grid-cols-3' : 'grid-cols-1'} gap-6`}>
        {/* Funnel Visualization */}
        <div className={showPathAnalysis ? 'col-span-2' : 'col-span-1'}>
          <div className="space-y-4">
            {data.steps.map((step, index) => (
              <div
                key={step.name}
                className={`relative cursor-pointer transition-all duration-200 ${
                  selectedStep === index ? 'transform scale-105' : 'hover:transform hover:scale-102'
                }`}
                onClick={() => handleStepClick(index, step)}
              >
                {/* Step Container */}
                <div className="relative mx-auto" style={{ width: getFunnelStepWidth(step.percentage) }}>
                  {/* Funnel Step */}
                  <div
                    className={`
                      h-16 rounded-lg flex items-center justify-between px-4 text-white font-medium
                      ${getFunnelStepColor(index, data.steps.length)}
                      ${selectedStep === index ? 'ring-2 ring-offset-2 ring-indigo-500' : ''}
                    `}
                  >
                    <span className="text-sm">{step.name}</span>
                    <div className="text-right">
                      <div className="text-lg font-bold">{step.count.toLocaleString()}</div>
                      <div className="text-xs opacity-90">{step.percentage}%</div>
                    </div>
                  </div>

                  {/* Dropoff Indicator */}
                  {step.dropoff && step.dropoff > 0 && (
                    <div className="absolute -right-4 top-1/2 transform -translate-y-1/2">
                      <div className="bg-red-100 text-red-700 px-2 py-1 rounded text-xs font-medium">
                        -{step.dropoff.toLocaleString()}
                      </div>
                    </div>
                  )}
                </div>

                {/* Conversion Rate Arrow */}
                {index < data.steps.length - 1 && (
                  <div className="flex justify-center mt-2 mb-2">
                    <div className="flex items-center space-x-2 text-xs text-gray-500">
                      <div className="w-8 h-px bg-gray-300"></div>
                      <span>
                        {((data.steps[index + 1].count / step.count) * 100).toFixed(1)}%
                      </span>
                      <div className="w-8 h-px bg-gray-300"></div>
                      <svg className="w-3 h-3 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fillRule="evenodd" d="M10.293 15.707a1 1 0 010-1.414L14.586 10l-4.293-4.293a1 1 0 111.414-1.414l5 5a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0z" clipRule="evenodd" />
                      </svg>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Path Analysis Panel */}
        {showPathAnalysis && (
          <div className="col-span-1">
            <div className="bg-gray-50 rounded-lg p-4">
              <h4 className="text-sm font-semibold text-gray-900 mb-4">Top Journey Paths</h4>
              <div className="space-y-3">
                {data.pathAnalysis.topPaths.map((pathData, index) => (
                  <div
                    key={`path-${index}`}
                    className="bg-white rounded-lg p-3 cursor-pointer hover:shadow-md transition-shadow border border-gray-200"
                    onClick={() => handlePathClick(pathData.path, pathData.conversionRate)}
                  >
                    {/* Path Flow */}
                    <div className="flex flex-wrap items-center gap-1 mb-2">
                      {pathData.path.map((step, stepIndex) => (
                        <div key={stepIndex} className="flex items-center">
                          <span className="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded">
                            {step}
                          </span>
                          {stepIndex < pathData.path.length - 1 && (
                            <svg className="w-3 h-3 text-gray-400 mx-1" fill="currentColor" viewBox="0 0 20 20">
                              <path fillRule="evenodd" d="M10.293 15.707a1 1 0 010-1.414L14.586 10l-4.293-4.293a1 1 0 111.414-1.414l5 5a1 1 0 010 1.414l-5 5a1 1 0 01-1.414 0z" clipRule="evenodd" />
                            </svg>
                          )}
                        </div>
                      ))}
                    </div>

                    {/* Path Metrics */}
                    <div className="flex justify-between items-center text-xs text-gray-600">
                      <div className="flex space-x-3">
                        <span>
                          <span className="font-medium">{pathData.count.toLocaleString()}</span> customers
                        </span>
                        <span>
                          <span className="font-medium">{pathData.percentage}%</span> of total
                        </span>
                      </div>
                      <div className={`px-2 py-1 rounded ${
                        pathData.conversionRate >= 80 ? 'bg-green-100 text-green-700' :
                        pathData.conversionRate >= 60 ? 'bg-yellow-100 text-yellow-700' :
                        'bg-red-100 text-red-700'
                      }`}>
                        {pathData.conversionRate}% conversion
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Path Legend */}
              <div className="mt-4 pt-4 border-t border-gray-200">
                <div className="text-xs text-gray-500 mb-2">Conversion Rate:</div>
                <div className="flex items-center space-x-3 text-xs">
                  <div className="flex items-center space-x-1">
                    <div className="w-3 h-3 bg-green-100 rounded"></div>
                    <span>80%+</span>
                  </div>
                  <div className="flex items-center space-x-1">
                    <div className="w-3 h-3 bg-yellow-100 rounded"></div>
                    <span>60-79%</span>
                  </div>
                  <div className="flex items-center space-x-1">
                    <div className="w-3 h-3 bg-red-100 rounded"></div>
                    <span>&lt;60%</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Selected Step Details */}
      {selectedStep !== null && data.steps[selectedStep] && (
        <div className="mt-6 p-4 bg-indigo-50 border border-indigo-200 rounded-lg">
          <div className="flex items-center justify-between">
            <div>
              <h5 className="font-semibold text-indigo-900">{data.steps[selectedStep].name}</h5>
              <p className="text-sm text-indigo-700">
                {data.steps[selectedStep].count.toLocaleString()} customers ({data.steps[selectedStep].percentage}% of total)
              </p>
            </div>
            <button
              onClick={() => setSelectedStep(null)}
              className="text-indigo-600 hover:text-indigo-800"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}