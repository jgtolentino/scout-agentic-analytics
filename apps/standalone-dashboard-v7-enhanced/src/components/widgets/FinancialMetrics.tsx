import React from 'react';

interface FinancialMetricsProps {
  props: {
    title?: string;
    layout?: 'grid' | 'cards' | 'compact';
    showTrends?: boolean;
    precision?: number;
  };
  data?: {
    revenue: number;
    profit: number;
    margin: number;
    growth: number;
    volume: number;
    averageOrderValue: number;
    conversionRate: number;
    customerLifetimeValue: number;
    trends?: {
      revenue: number;
      profit: number;
      margin: number;
      growth: number;
    };
  };
}

export const FinancialMetrics: React.FC<FinancialMetricsProps> = ({ 
  props = {}, 
  data 
}) => {
  const {
    title = 'Financial Metrics',
    layout = 'grid',
    showTrends = true,
    precision = 2
  } = props;

  // Mock data if none provided
  const mockData = {
    revenue: 2850000,
    profit: 485000,
    margin: 17.02,
    growth: 12.5,
    volume: 15847,
    averageOrderValue: 179.85,
    conversionRate: 3.42,
    customerLifetimeValue: 1250.75,
    trends: {
      revenue: 8.3,
      profit: 15.2,
      margin: -2.1,
      growth: 5.7
    }
  };

  const metricsData = data || mockData;

  const formatCurrency = (value: number, compact = false) => {
    if (compact && value >= 1000000) {
      return `₱${(value / 1000000).toFixed(1)}M`;
    } else if (compact && value >= 1000) {
      return `₱${(value / 1000).toFixed(1)}K`;
    }
    return `₱${value.toLocaleString('en-US', { minimumFractionDigits: precision })}`;
  };

  const formatPercentage = (value: number) => {
    return `${value > 0 ? '+' : ''}${value.toFixed(1)}%`;
  };

  const getTrendIcon = (value: number) => {
    if (value > 0) return '📈';
    if (value < 0) return '📉';
    return '➡️';
  };

  const getTrendColor = (value: number) => {
    if (value > 0) return 'text-green-600';
    if (value < 0) return 'text-red-600';
    return 'text-gray-600';
  };

  const metrics = [
    {
      key: 'revenue',
      label: 'Revenue',
      value: metricsData.revenue,
      format: 'currency',
      icon: '💰',
      trend: metricsData.trends?.revenue,
      description: 'Total revenue generated'
    },
    {
      key: 'profit',
      label: 'Profit',
      value: metricsData.profit,
      format: 'currency',
      icon: '💎',
      trend: metricsData.trends?.profit,
      description: 'Net profit after expenses'
    },
    {
      key: 'margin',
      label: 'Margin',
      value: metricsData.margin,
      format: 'percentage',
      icon: '📊',
      trend: metricsData.trends?.margin,
      description: 'Profit margin percentage'
    },
    {
      key: 'growth',
      label: 'Growth Rate',
      value: metricsData.growth,
      format: 'percentage',
      icon: '🚀',
      trend: metricsData.trends?.growth,
      description: 'Year-over-year growth'
    },
    {
      key: 'volume',
      label: 'Transaction Volume',
      value: metricsData.volume,
      format: 'number',
      icon: '📦',
      description: 'Total number of transactions'
    },
    {
      key: 'aov',
      label: 'Avg Order Value',
      value: metricsData.averageOrderValue,
      format: 'currency',
      icon: '🛒',
      description: 'Average value per transaction'
    },
    {
      key: 'conversion',
      label: 'Conversion Rate',
      value: metricsData.conversionRate,
      format: 'percentage',
      icon: '🎯',
      description: 'Percentage of visitors who convert'
    },
    {
      key: 'clv',
      label: 'Customer LTV',
      value: metricsData.customerLifetimeValue,
      format: 'currency',
      icon: '👥',
      description: 'Customer lifetime value'
    }
  ];

  const renderMetric = (metric: any, index: number) => {
    let formattedValue: string;
    
    switch (metric.format) {
      case 'currency':
        formattedValue = formatCurrency(metric.value, layout === 'compact');
        break;
      case 'percentage':
        formattedValue = `${metric.value.toFixed(precision)}%`;
        break;
      case 'number':
        formattedValue = metric.value.toLocaleString();
        break;
      default:
        formattedValue = metric.value.toString();
    }

    if (layout === 'compact') {
      return (
        <div key={metric.key} className="flex items-center justify-between py-2 border-b border-gray-100 last:border-b-0">
          <div className="flex items-center space-x-2">
            <span className="text-lg">{metric.icon}</span>
            <span className="text-sm font-medium text-gray-700">{metric.label}</span>
          </div>
          <div className="text-right">
            <div className="font-semibold text-gray-900">{formattedValue}</div>
            {showTrends && metric.trend !== undefined && (
              <div className={`text-xs ${getTrendColor(metric.trend)}`}>
                {getTrendIcon(metric.trend)} {formatPercentage(metric.trend)}
              </div>
            )}
          </div>
        </div>
      );
    }

    return (
      <div key={metric.key} className="bg-white rounded-lg border shadow-sm p-4 hover:shadow-md transition-shadow">
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center space-x-2">
            <span className="text-2xl">{metric.icon}</span>
            <h4 className="font-semibold text-gray-800">{metric.label}</h4>
          </div>
          {showTrends && metric.trend !== undefined && (
            <div className={`text-sm font-medium ${getTrendColor(metric.trend)}`}>
              {getTrendIcon(metric.trend)} {formatPercentage(metric.trend)}
            </div>
          )}
        </div>
        
        <div className="mb-1">
          <span className="text-2xl font-bold text-gray-900">{formattedValue}</span>
        </div>
        
        {metric.description && (
          <p className="text-xs text-gray-500">{metric.description}</p>
        )}
        
        {/* Mini trend chart placeholder */}
        {showTrends && metric.trend !== undefined && (
          <div className="mt-3">
            <div className="h-8 bg-gray-50 rounded flex items-end justify-center space-x-1">
              {[...Array(12)].map((_, i) => (
                <div
                  key={i}
                  className={`w-1 rounded-t ${
                    metric.trend > 0 ? 'bg-green-400' : 'bg-red-400'
                  }`}
                  style={{ 
                    height: `${20 + Math.random() * 60}%`,
                    opacity: 0.3 + (i / 12) * 0.7 
                  }}
                />
              ))}
            </div>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="p-4 border rounded-lg bg-gray-50">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-lg font-semibold text-gray-800">{title}</h3>
        <div className="flex items-center space-x-2 text-xs text-gray-500">
          <span>📊</span>
          <span>Updated {new Date().toLocaleTimeString()}</span>
        </div>
      </div>

      {/* Metrics Grid */}
      <div className={
        layout === 'compact' 
          ? 'space-y-1' 
          : layout === 'cards'
          ? 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4'
          : 'grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4'
      }>
        {metrics.map(renderMetric)}
      </div>

      {/* Summary Row */}
      <div className="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
          <div>
            <div className="text-xs text-blue-600 font-medium">Total Revenue</div>
            <div className="text-lg font-bold text-blue-900">{formatCurrency(metricsData.revenue, true)}</div>
          </div>
          <div>
            <div className="text-xs text-blue-600 font-medium">Profit Margin</div>
            <div className="text-lg font-bold text-blue-900">{metricsData.margin.toFixed(1)}%</div>
          </div>
          <div>
            <div className="text-xs text-blue-600 font-medium">Growth Rate</div>
            <div className={`text-lg font-bold ${getTrendColor(metricsData.growth)}`}>
              {formatPercentage(metricsData.growth)}
            </div>
          </div>
          <div>
            <div className="text-xs text-blue-600 font-medium">Transactions</div>
            <div className="text-lg font-bold text-blue-900">{metricsData.volume.toLocaleString()}</div>
          </div>
        </div>
      </div>
    </div>
  );
};