import React, { useState, useEffect, useRef } from 'react';
import { LineChart, Line, BarChart, Bar, AreaChart, Area, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

interface ResponsiveChartProps {
  props: {
    title?: string;
    chartType?: 'line' | 'bar' | 'area' | 'pie';
    breakpoints?: {
      mobile: number;
      tablet: number;
      desktop: number;
    };
    adaptiveLayout?: boolean;
    showLabels?: boolean;
    colorScheme?: 'blue' | 'green' | 'purple' | 'orange' | 'custom';
  };
  data?: Array<{
    [key: string]: number | string;
  }>;
}

export const ResponsiveChart: React.FC<ResponsiveChartProps> = ({ 
  props = {}, 
  data = [] 
}) => {
  const {
    title = 'Responsive Chart',
    chartType = 'line',
    breakpoints = { mobile: 480, tablet: 768, desktop: 1024 },
    adaptiveLayout = true,
    showLabels = true,
    colorScheme = 'blue'
  } = props;

  const [screenSize, setScreenSize] = useState<'mobile' | 'tablet' | 'desktop'>('desktop');
  const [chartHeight, setChartHeight] = useState(400);
  const [orientation, setOrientation] = useState<'portrait' | 'landscape'>('landscape');
  const containerRef = useRef<HTMLDivElement>(null);

  // Mock responsive data
  const mockData = [
    { name: 'Jan', value: 4000, value2: 2400, mobile: 2000, tablet: 3000 },
    { name: 'Feb', value: 3000, value2: 1398, mobile: 1500, tablet: 2200 },
    { name: 'Mar', value: 2000, value2: 9800, mobile: 1800, tablet: 2800 },
    { name: 'Apr', value: 2780, value2: 3908, mobile: 2100, tablet: 3200 },
    { name: 'May', value: 1890, value2: 4800, mobile: 1600, tablet: 2500 },
    { name: 'Jun', value: 2390, value2: 3800, mobile: 1900, tablet: 2900 }
  ];

  const chartData = data.length > 0 ? data : mockData;

  const colorSchemes = {
    blue: ['#3B82F6', '#1D4ED8', '#1E40AF', '#1E3A8A'],
    green: ['#10B981', '#059669', '#047857', '#065F46'],
    purple: ['#8B5CF6', '#7C3AED', '#6D28D9', '#5B21B6'],
    orange: ['#F59E0B', '#D97706', '#B45309', '#92400E'],
    custom: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4']
  };

  const colors = colorSchemes[colorScheme];

  // Screen size detection
  useEffect(() => {
    const handleResize = () => {
      const width = window.innerWidth;
      const height = window.innerHeight;
      
      if (width < breakpoints.mobile) {
        setScreenSize('mobile');
        setChartHeight(250);
      } else if (width < breakpoints.tablet) {
        setScreenSize('tablet');
        setChartHeight(300);
      } else {
        setScreenSize('desktop');
        setChartHeight(400);
      }
      
      setOrientation(width > height ? 'landscape' : 'portrait');
    };

    handleResize(); // Initial check
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [breakpoints]);

  // Responsive configuration
  const getResponsiveConfig = () => {
    const config = {
      margin: { top: 5, right: 30, left: 20, bottom: 5 },
      fontSize: 12,
      strokeWidth: 2,
      dotSize: 4,
      showGrid: true,
      showLegend: true,
      showTooltip: true
    };

    switch (screenSize) {
      case 'mobile':
        return {
          ...config,
          margin: { top: 5, right: 10, left: 10, bottom: 20 },
          fontSize: 10,
          strokeWidth: 1.5,
          dotSize: 3,
          showGrid: false,
          showLegend: orientation === 'landscape',
        };
      case 'tablet':
        return {
          ...config,
          margin: { top: 5, right: 20, left: 15, bottom: 5 },
          fontSize: 11,
          strokeWidth: 1.5,
          dotSize: 3.5,
          showGrid: true,
        };
      default:
        return config;
    }
  };

  const config = getResponsiveConfig();

  // Responsive data key selection
  const getDataKey = (baseKey: string) => {
    if (adaptiveLayout) {
      switch (screenSize) {
        case 'mobile':
          return chartData[0]?.mobile !== undefined ? 'mobile' : baseKey;
        case 'tablet':
          return chartData[0]?.tablet !== undefined ? 'tablet' : baseKey;
        default:
          return baseKey;
      }
    }
    return baseKey;
  };

  const renderChart = () => {
    const commonProps = {
      data: chartData,
      margin: config.margin
    };

    switch (chartType) {
      case 'line':
        return (
          <ResponsiveContainer width="100%" height={chartHeight}>
            <LineChart {...commonProps}>
              {config.showGrid && <CartesianGrid strokeDasharray="3 3" />}
              <XAxis 
                dataKey="name" 
                fontSize={config.fontSize}
                hide={screenSize === 'mobile' && orientation === 'portrait'}
              />
              <YAxis 
                fontSize={config.fontSize}
                hide={screenSize === 'mobile' && orientation === 'portrait'}
              />
              {config.showTooltip && <Tooltip />}
              {config.showLegend && <Legend />}
              <Line
                type="monotone"
                dataKey={getDataKey('value')}
                stroke={colors[0]}
                strokeWidth={config.strokeWidth}
                dot={{ r: config.dotSize }}
                activeDot={{ r: config.dotSize + 2 }}
              />
              {screenSize !== 'mobile' && (
                <Line
                  type="monotone"
                  dataKey={getDataKey('value2')}
                  stroke={colors[1]}
                  strokeWidth={config.strokeWidth}
                  dot={{ r: config.dotSize }}
                />
              )}
            </LineChart>
          </ResponsiveContainer>
        );

      case 'bar':
        return (
          <ResponsiveContainer width="100%" height={chartHeight}>
            <BarChart {...commonProps}>
              {config.showGrid && <CartesianGrid strokeDasharray="3 3" />}
              <XAxis 
                dataKey="name" 
                fontSize={config.fontSize}
                angle={screenSize === 'mobile' ? -45 : 0}
                textAnchor={screenSize === 'mobile' ? 'end' : 'middle'}
              />
              <YAxis fontSize={config.fontSize} />
              {config.showTooltip && <Tooltip />}
              {config.showLegend && <Legend />}
              <Bar dataKey={getDataKey('value')} fill={colors[0]} />
              {screenSize !== 'mobile' && (
                <Bar dataKey={getDataKey('value2')} fill={colors[1]} />
              )}
            </BarChart>
          </ResponsiveContainer>
        );

      case 'area':
        return (
          <ResponsiveContainer width="100%" height={chartHeight}>
            <AreaChart {...commonProps}>
              {config.showGrid && <CartesianGrid strokeDasharray="3 3" />}
              <XAxis 
                dataKey="name" 
                fontSize={config.fontSize}
                hide={screenSize === 'mobile' && orientation === 'portrait'}
              />
              <YAxis 
                fontSize={config.fontSize}
                hide={screenSize === 'mobile' && orientation === 'portrait'}
              />
              {config.showTooltip && <Tooltip />}
              {config.showLegend && <Legend />}
              <Area
                type="monotone"
                dataKey={getDataKey('value')}
                stackId="1"
                stroke={colors[0]}
                fill={colors[0]}
                fillOpacity={0.6}
              />
              {screenSize !== 'mobile' && (
                <Area
                  type="monotone"
                  dataKey={getDataKey('value2')}
                  stackId="1"
                  stroke={colors[1]}
                  fill={colors[1]}
                  fillOpacity={0.6}
                />
              )}
            </AreaChart>
          </ResponsiveContainer>
        );

      case 'pie':
        const pieData = chartData.map((item, index) => ({
          name: item.name,
          value: item[getDataKey('value')] as number,
          color: colors[index % colors.length]
        }));

        return (
          <ResponsiveContainer width="100%" height={chartHeight}>
            <PieChart>
              <Pie
                data={pieData}
                cx="50%"
                cy="50%"
                outerRadius={screenSize === 'mobile' ? 60 : 80}
                fill="#8884d8"
                dataKey="value"
                label={screenSize !== 'mobile' && showLabels}
              >
                {pieData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              {config.showTooltip && <Tooltip />}
              {config.showLegend && screenSize !== 'mobile' && <Legend />}
            </PieChart>
          </ResponsiveContainer>
        );

      default:
        return null;
    }
  };

  return (
    <div ref={containerRef} className="p-4 border rounded-lg bg-white">
      {/* Header */}
      <div className={`flex ${screenSize === 'mobile' ? 'flex-col space-y-2' : 'items-center justify-between'} mb-4`}>
        <h3 className="text-lg font-semibold text-gray-800">{title}</h3>
        
        {/* Responsive indicators */}
        <div className="flex items-center space-x-2">
          <div className={`px-2 py-1 text-xs rounded ${
            screenSize === 'mobile' ? 'bg-red-100 text-red-700' :
            screenSize === 'tablet' ? 'bg-yellow-100 text-yellow-700' :
            'bg-green-100 text-green-700'
          }`}>
            {screenSize.charAt(0).toUpperCase() + screenSize.slice(1)}
          </div>
          <div className="text-xs text-gray-500">
            {orientation === 'portrait' ? '📱' : '🖥️'}
          </div>
        </div>
      </div>

      {/* Chart Container */}
      <div className="relative">
        {renderChart()}
        
        {/* Responsive overlay info */}
        {adaptiveLayout && (
          <div className="absolute top-2 left-2 bg-black bg-opacity-75 text-white px-2 py-1 rounded text-xs">
            {screenSize} view • {orientation}
          </div>
        )}
      </div>

      {/* Responsive stats */}
      <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-2 text-center text-xs">
        <div className="p-2 bg-gray-50 rounded">
          <div className="font-medium text-gray-600">Screen</div>
          <div className="text-gray-900">{screenSize}</div>
        </div>
        <div className="p-2 bg-gray-50 rounded">
          <div className="font-medium text-gray-600">Height</div>
          <div className="text-gray-900">{chartHeight}px</div>
        </div>
        <div className="p-2 bg-gray-50 rounded">
          <div className="font-medium text-gray-600">Orientation</div>
          <div className="text-gray-900">{orientation}</div>
        </div>
        <div className="p-2 bg-gray-50 rounded">
          <div className="font-medium text-gray-600">Theme</div>
          <div className="text-gray-900">{colorScheme}</div>
        </div>
      </div>

      {/* Breakpoint info (development helper) */}
      {process.env.NODE_ENV === 'development' && (
        <div className="mt-2 text-xs text-gray-400 border-t pt-2">
          <div>Breakpoints: Mobile &lt; {breakpoints.mobile}px, Tablet &lt; {breakpoints.tablet}px, Desktop ≥ {breakpoints.desktop}px</div>
          <div>Current: {window?.innerWidth}px × {window?.innerHeight}px</div>
        </div>
      )}
    </div>
  );
};