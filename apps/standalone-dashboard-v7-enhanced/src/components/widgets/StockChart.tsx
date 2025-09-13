import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

interface StockChartProps {
  props: {
    title?: string;
    symbol?: string;
    timeframe?: '1D' | '1W' | '1M' | '3M' | '1Y';
    showVolume?: boolean;
    indicators?: string[];
  };
  data?: Array<{
    timestamp: string;
    open: number;
    high: number;
    low: number;
    close: number;
    volume: number;
  }>;
}

export const StockChart: React.FC<StockChartProps> = ({ props = {}, data = [] }) => {
  const [selectedTimeframe, setSelectedTimeframe] = useState(props.timeframe || '1M');
  const [chartData, setChartData] = useState(data);

  // Mock data generator (replace with actual data source)
  const generateMockData = () => {
    const mockData = [];
    const basePrice = 1500;
    let currentPrice = basePrice;
    
    for (let i = 0; i < 30; i++) {
      const change = (Math.random() - 0.5) * 50;
      currentPrice += change;
      
      mockData.push({
        timestamp: new Date(Date.now() - (29 - i) * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        open: currentPrice - Math.random() * 20,
        high: currentPrice + Math.random() * 30,
        low: currentPrice - Math.random() * 25,
        close: currentPrice,
        volume: Math.floor(Math.random() * 1000000) + 100000
      });
    }
    
    return mockData;
  };

  useEffect(() => {
    if (!data || data.length === 0) {
      setChartData(generateMockData());
    } else {
      setChartData(data);
    }
  }, [data]);

  const timeframes = [
    { key: '1D', label: '1 Day' },
    { key: '1W', label: '1 Week' },
    { key: '1M', label: '1 Month' },
    { key: '3M', label: '3 Months' },
    { key: '1Y', label: '1 Year' }
  ];

  const currentPrice = chartData.length > 0 ? chartData[chartData.length - 1].close : 0;
  const previousPrice = chartData.length > 1 ? chartData[chartData.length - 2].close : currentPrice;
  const priceChange = currentPrice - previousPrice;
  const priceChangePercent = ((priceChange / previousPrice) * 100).toFixed(2);
  const isPositive = priceChange >= 0;

  return (
    <div className="p-4 border rounded-lg bg-white">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-800">
            {props.title || `${props.symbol || 'STOCK'} Price Chart`}
          </h3>
          <div className="flex items-center space-x-2 mt-1">
            <span className="text-2xl font-bold text-gray-900">
              ₱{currentPrice.toLocaleString('en-US', { minimumFractionDigits: 2 })}
            </span>
            <span className={`text-sm font-medium ${isPositive ? 'text-green-600' : 'text-red-600'}`}>
              {isPositive ? '+' : ''}{priceChange.toFixed(2)} ({isPositive ? '+' : ''}{priceChangePercent}%)
            </span>
          </div>
        </div>
        
        {/* Timeframe selector */}
        <div className="flex bg-gray-100 rounded-lg p-1">
          {timeframes.map(timeframe => (
            <button
              key={timeframe.key}
              onClick={() => setSelectedTimeframe(timeframe.key as any)}
              className={`px-3 py-1 text-xs font-medium rounded transition-colors ${
                selectedTimeframe === timeframe.key
                  ? 'bg-white text-blue-600 shadow-sm'
                  : 'text-gray-600 hover:text-gray-900'
              }`}
            >
              {timeframe.label}
            </button>
          ))}
        </div>
      </div>

      {/* Chart */}
      <div className="h-80">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis 
              dataKey="timestamp" 
              tick={{ fontSize: 12 }}
              tickFormatter={(value) => new Date(value).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
            />
            <YAxis 
              tick={{ fontSize: 12 }}
              domain={['dataMin - 50', 'dataMax + 50']}
              tickFormatter={(value) => `₱${value.toFixed(0)}`}
            />
            <Tooltip
              labelFormatter={(value) => new Date(value).toLocaleDateString()}
              formatter={(value: number, name: string) => [
                `₱${value.toFixed(2)}`,
                name === 'close' ? 'Close Price' : name
              ]}
              contentStyle={{
                backgroundColor: 'white',
                border: '1px solid #e5e7eb',
                borderRadius: '8px',
                fontSize: '14px'
              }}
            />
            <Legend />
            
            {/* Price line */}
            <Line
              type="monotone"
              dataKey="close"
              stroke="#2563eb"
              strokeWidth={2}
              dot={false}
              name="Close Price"
              activeDot={{ r: 4, stroke: '#2563eb', strokeWidth: 2, fill: 'white' }}
            />
            
            {/* High/Low if enabled */}
            {props.indicators?.includes('highlow') && (
              <>
                <Line
                  type="monotone"
                  dataKey="high"
                  stroke="#16a34a"
                  strokeWidth={1}
                  strokeDasharray="5 5"
                  dot={false}
                  name="High"
                />
                <Line
                  type="monotone"
                  dataKey="low"
                  stroke="#dc2626"
                  strokeWidth={1}
                  strokeDasharray="5 5"
                  dot={false}
                  name="Low"
                />
              </>
            )}
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Volume chart (if enabled) */}
      {props.showVolume && (
        <div className="mt-4 h-24">
          <div className="text-sm font-medium text-gray-600 mb-2">Volume</div>
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={chartData}>
              <XAxis dataKey="timestamp" hide />
              <YAxis 
                tick={{ fontSize: 10 }}
                tickFormatter={(value) => `${(value / 1000000).toFixed(1)}M`}
              />
              <Tooltip
                labelFormatter={(value) => new Date(value).toLocaleDateString()}
                formatter={(value: number) => [value.toLocaleString(), 'Volume']}
              />
              <Line
                type="monotone"
                dataKey="volume"
                stroke="#6b7280"
                strokeWidth={1}
                dot={false}
                name="Volume"
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Additional metrics */}
      <div className="mt-4 grid grid-cols-4 gap-4 text-center border-t pt-3">
        <div>
          <div className="text-xs text-gray-500">Open</div>
          <div className="font-semibold">₱{chartData.length > 0 ? chartData[chartData.length - 1].open.toFixed(2) : '0.00'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">High</div>
          <div className="font-semibold text-green-600">₱{chartData.length > 0 ? chartData[chartData.length - 1].high.toFixed(2) : '0.00'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Low</div>
          <div className="font-semibold text-red-600">₱{chartData.length > 0 ? chartData[chartData.length - 1].low.toFixed(2) : '0.00'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Volume</div>
          <div className="font-semibold">{chartData.length > 0 ? (chartData[chartData.length - 1].volume / 1000000).toFixed(2) : '0'}M</div>
        </div>
      </div>
    </div>
  );
};