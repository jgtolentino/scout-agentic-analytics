import React, { useState, useEffect } from 'react';
import { BarChart, Bar, LineChart, Line, AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, ScatterChart, Scatter } from 'recharts';

interface InteractiveChartProps {
  props: {
    title?: string;
    chartType?: 'line' | 'bar' | 'area' | 'scatter' | 'combo';
    interactive?: boolean;
    animationDuration?: number;
    showControls?: boolean;
    theme?: 'light' | 'dark';
  };
  data?: Array<{
    [key: string]: number | string;
  }>;
}

export const InteractiveChart: React.FC<InteractiveChartProps> = ({ 
  props = {}, 
  data = [] 
}) => {
  const {
    title = 'Interactive Chart',
    chartType: initialChartType = 'line',
    interactive = true,
    animationDuration = 1000,
    showControls = true,
    theme = 'light'
  } = props;

  const [chartType, setChartType] = useState(initialChartType);
  const [selectedDataPoint, setSelectedDataPoint] = useState<any>(null);
  const [hoveredPoint, setHoveredPoint] = useState<any>(null);
  const [zoomLevel, setZoomLevel] = useState(1);
  const [isAnimating, setIsAnimating] = useState(false);

  // Mock data if none provided
  const mockData = [
    { month: 'Jan', revenue: 4000, profit: 2400, customers: 240 },
    { month: 'Feb', revenue: 3000, profit: 1398, customers: 210 },
    { month: 'Mar', revenue: 2000, profit: 9800, customers: 290 },
    { month: 'Apr', revenue: 2780, profit: 3908, customers: 300 },
    { month: 'May', revenue: 1890, profit: 4800, customers: 181 },
    { month: 'Jun', revenue: 2390, profit: 3800, customers: 250 },
    { month: 'Jul', revenue: 3490, profit: 4300, customers: 310 },
    { month: 'Aug', revenue: 4000, profit: 2400, customers: 280 },
    { month: 'Sep', revenue: 3200, profit: 2100, customers: 260 },
    { month: 'Oct', revenue: 3800, profit: 2800, customers: 320 },
    { month: 'Nov', revenue: 4200, profit: 3200, customers: 340 },
    { month: 'Dec', revenue: 4800, profit: 3600, customers: 380 }
  ];

  const chartData = data.length > 0 ? data : mockData;

  const chartTypes = [
    { key: 'line', label: 'Line', icon: '📈' },
    { key: 'bar', label: 'Bar', icon: '📊' },
    { key: 'area', label: 'Area', icon: '🏔️' },
    { key: 'scatter', label: 'Scatter', icon: '🎯' },
    { key: 'combo', label: 'Combo', icon: '📈📊' }
  ];

  const colors = {
    primary: theme === 'dark' ? '#60a5fa' : '#3b82f6',
    secondary: theme === 'dark' ? '#34d399' : '#10b981',
    tertiary: theme === 'dark' ? '#f59e0b' : '#f59e0b',
    background: theme === 'dark' ? '#1f2937' : '#ffffff',
    text: theme === 'dark' ? '#f3f4f6' : '#1f2937'
  };

  useEffect(() => {
    if (interactive) {
      setIsAnimating(true);
      const timer = setTimeout(() => setIsAnimating(false), animationDuration);
      return () => clearTimeout(timer);
    }
  }, [chartType, interactive, animationDuration]);

  const handleChartTypeChange = (newType: string) => {
    setChartType(newType as any);
    setSelectedDataPoint(null);
  };

  const handleDataPointClick = (data: any) => {
    if (interactive) {
      setSelectedDataPoint(data);
    }
  };

  const handleMouseEnter = (data: any) => {
    if (interactive) {
      setHoveredPoint(data);
    }
  };

  const handleMouseLeave = () => {
    if (interactive) {
      setHoveredPoint(null);
    }
  };

  const renderChart = () => {
    const commonProps = {
      data: chartData,
      onMouseEnter: handleMouseEnter,
      onMouseLeave: handleMouseLeave,
      onClick: handleDataPointClick
    };

    switch (chartType) {
      case 'line':
        return (
          <ResponsiveContainer width="100%" height={400}>
            <LineChart {...commonProps}>
              <CartesianGrid strokeDasharray="3 3" stroke={theme === 'dark' ? '#374151' : '#e5e7eb'} />
              <XAxis dataKey="month" stroke={colors.text} />
              <YAxis stroke={colors.text} />
              <Tooltip
                contentStyle={{
                  backgroundColor: colors.background,
                  borderColor: colors.primary,
                  color: colors.text
                }}
              />
              <Legend />
              <Line
                type="monotone"
                dataKey="revenue"
                stroke={colors.primary}
                strokeWidth={3}
                dot={{ r: 6, fill: colors.primary }}
                activeDot={{ r: 8, stroke: colors.primary, strokeWidth: 2 }}
                animationDuration={isAnimating ? animationDuration : 0}
              />
              <Line
                type="monotone"
                dataKey="profit"
                stroke={colors.secondary}
                strokeWidth={2}
                dot={{ r: 4, fill: colors.secondary }}
                animationDuration={isAnimating ? animationDuration : 0}
              />
            </LineChart>
          </ResponsiveContainer>
        );

      case 'bar':
        return (
          <ResponsiveContainer width="100%" height={400}>
            <BarChart {...commonProps}>
              <CartesianGrid strokeDasharray="3 3" stroke={theme === 'dark' ? '#374151' : '#e5e7eb'} />
              <XAxis dataKey="month" stroke={colors.text} />
              <YAxis stroke={colors.text} />
              <Tooltip
                contentStyle={{
                  backgroundColor: colors.background,
                  borderColor: colors.primary,
                  color: colors.text
                }}
              />
              <Legend />
              <Bar 
                dataKey="revenue" 
                fill={colors.primary} 
                animationDuration={isAnimating ? animationDuration : 0}
              />
              <Bar 
                dataKey="profit" 
                fill={colors.secondary} 
                animationDuration={isAnimating ? animationDuration : 0}
              />
            </BarChart>
          </ResponsiveContainer>
        );

      case 'area':
        return (
          <ResponsiveContainer width="100%" height={400}>
            <AreaChart {...commonProps}>
              <CartesianGrid strokeDasharray="3 3" stroke={theme === 'dark' ? '#374151' : '#e5e7eb'} />
              <XAxis dataKey="month" stroke={colors.text} />
              <YAxis stroke={colors.text} />
              <Tooltip
                contentStyle={{
                  backgroundColor: colors.background,
                  borderColor: colors.primary,
                  color: colors.text
                }}
              />
              <Legend />
              <Area
                type="monotone"
                dataKey="revenue"
                stackId="1"
                stroke={colors.primary}
                fill={colors.primary}
                fillOpacity={0.6}
                animationDuration={isAnimating ? animationDuration : 0}
              />
              <Area
                type="monotone"
                dataKey="profit"
                stackId="1"
                stroke={colors.secondary}
                fill={colors.secondary}
                fillOpacity={0.6}
                animationDuration={isAnimating ? animationDuration : 0}
              />
            </AreaChart>
          </ResponsiveContainer>
        );

      case 'scatter':
        return (
          <ResponsiveContainer width="100%" height={400}>
            <ScatterChart {...commonProps}>
              <CartesianGrid strokeDasharray="3 3" stroke={theme === 'dark' ? '#374151' : '#e5e7eb'} />
              <XAxis dataKey="revenue" type="number" stroke={colors.text} />
              <YAxis dataKey="profit" type="number" stroke={colors.text} />
              <Tooltip
                cursor={{ strokeDasharray: '3 3' }}
                contentStyle={{
                  backgroundColor: colors.background,
                  borderColor: colors.primary,
                  color: colors.text
                }}
              />
              <Scatter 
                dataKey="customers" 
                fill={colors.primary} 
                animationDuration={isAnimating ? animationDuration : 0}
              />
            </ScatterChart>
          </ResponsiveContainer>
        );

      case 'combo':
        return (
          <ResponsiveContainer width="100%" height={400}>
            <LineChart {...commonProps}>
              <CartesianGrid strokeDasharray="3 3" stroke={theme === 'dark' ? '#374151' : '#e5e7eb'} />
              <XAxis dataKey="month" stroke={colors.text} />
              <YAxis stroke={colors.text} />
              <Tooltip
                contentStyle={{
                  backgroundColor: colors.background,
                  borderColor: colors.primary,
                  color: colors.text
                }}
              />
              <Legend />
              <Bar 
                dataKey="revenue" 
                fill={colors.primary} 
                fillOpacity={0.8}
                animationDuration={isAnimating ? animationDuration : 0}
              />
              <Line
                type="monotone"
                dataKey="profit"
                stroke={colors.secondary}
                strokeWidth={3}
                dot={{ r: 6, fill: colors.secondary }}
                animationDuration={isAnimating ? animationDuration : 0}
              />
            </LineChart>
          </ResponsiveContainer>
        );

      default:
        return null;
    }
  };

  return (
    <div className={`p-4 border rounded-lg ${theme === 'dark' ? 'bg-gray-800 border-gray-700' : 'bg-white border-gray-200'}`}>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h3 className={`text-lg font-semibold ${theme === 'dark' ? 'text-white' : 'text-gray-800'}`}>
          {title}
        </h3>
        
        {showControls && (
          <div className="flex items-center space-x-2">
            {/* Chart Type Selector */}
            <div className="flex bg-gray-100 rounded-lg p-1">
              {chartTypes.map(type => (
                <button
                  key={type.key}
                  onClick={() => handleChartTypeChange(type.key)}
                  className={`px-2 py-1 text-xs font-medium rounded transition-colors flex items-center space-x-1 ${
                    chartType === type.key
                      ? 'bg-white text-blue-600 shadow-sm'
                      : 'text-gray-600 hover:text-gray-900'
                  }`}
                >
                  <span>{type.icon}</span>
                  <span>{type.label}</span>
                </button>
              ))}
            </div>
            
            {/* Animation Toggle */}
            <button
              onClick={() => setIsAnimating(!isAnimating)}
              className={`p-2 rounded text-sm ${
                isAnimating 
                  ? 'bg-blue-100 text-blue-600' 
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
              title="Toggle Animation"
            >
              ⚡
            </button>
          </div>
        )}
      </div>

      {/* Chart Container */}
      <div className="relative">
        {renderChart()}
        
        {/* Interactive Overlay */}
        {interactive && hoveredPoint && (
          <div className="absolute top-4 left-4 bg-black bg-opacity-75 text-white p-2 rounded text-sm pointer-events-none">
            <div>Month: {hoveredPoint.month}</div>
            <div>Revenue: ₱{hoveredPoint.revenue?.toLocaleString()}</div>
            <div>Profit: ₱{hoveredPoint.profit?.toLocaleString()}</div>
          </div>
        )}
      </div>

      {/* Data Point Details */}
      {selectedDataPoint && (
        <div className={`mt-4 p-4 rounded-lg border ${
          theme === 'dark' 
            ? 'bg-gray-700 border-gray-600 text-white' 
            : 'bg-blue-50 border-blue-200 text-blue-900'
        }`}>
          <h4 className="font-semibold mb-2">Selected Data Point</h4>
          <div className="grid grid-cols-3 gap-4 text-sm">
            <div>
              <div className="font-medium">Month</div>
              <div>{selectedDataPoint.month}</div>
            </div>
            <div>
              <div className="font-medium">Revenue</div>
              <div>₱{selectedDataPoint.revenue?.toLocaleString()}</div>
            </div>
            <div>
              <div className="font-medium">Profit</div>
              <div>₱{selectedDataPoint.profit?.toLocaleString()}</div>
            </div>
          </div>
          <button
            onClick={() => setSelectedDataPoint(null)}
            className="mt-2 text-xs underline opacity-75 hover:opacity-100"
          >
            Clear Selection
          </button>
        </div>
      )}

      {/* Chart Stats */}
      <div className="mt-4 grid grid-cols-3 gap-4 text-center text-sm border-t pt-4">
        <div>
          <div className={`font-medium ${theme === 'dark' ? 'text-gray-300' : 'text-gray-600'}`}>
            Total Revenue
          </div>
          <div className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-gray-900'}`}>
            ₱{chartData.reduce((sum, item) => sum + (item.revenue as number || 0), 0).toLocaleString()}
          </div>
        </div>
        <div>
          <div className={`font-medium ${theme === 'dark' ? 'text-gray-300' : 'text-gray-600'}`}>
            Total Profit
          </div>
          <div className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-gray-900'}`}>
            ₱{chartData.reduce((sum, item) => sum + (item.profit as number || 0), 0).toLocaleString()}
          </div>
        </div>
        <div>
          <div className={`font-medium ${theme === 'dark' ? 'text-gray-300' : 'text-gray-600'}`}>
            Avg Customers
          </div>
          <div className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-gray-900'}`}>
            {Math.round(chartData.reduce((sum, item) => sum + (item.customers as number || 0), 0) / chartData.length).toLocaleString()}
          </div>
        </div>
      </div>
    </div>
  );
};