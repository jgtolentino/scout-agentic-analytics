'use client';

import React from 'react';
import { Card } from './AmazonCard';
import PlotlyAmazon from './charts/PlotlyAmazon';

interface ForecastCardProps {
  title: string;
  metric: string;
  currentValue: number;
  forecastValue: number;
  confidence: number;
  trend: 'up' | 'down' | 'flat';
  period: string;
  data?: {
    x: string[];
    historical: number[];
    forecast: number[];
  };
}

export default function ForecastCard({
  title,
  metric,
  currentValue,
  forecastValue,
  confidence,
  trend,
  period,
  data
}: ForecastCardProps) {
  const trendColor = trend === 'up' ? 'text-green-600' : trend === 'down' ? 'text-red-600' : 'text-gray-500';
  const trendIcon = trend === 'up' ? '↗' : trend === 'down' ? '↘' : '→';
  const change = ((forecastValue - currentValue) / currentValue * 100).toFixed(1);

  const chartData = data ? [
    {
      type: 'scatter',
      mode: 'lines',
      x: data.x.slice(0, data.historical.length),
      y: data.historical,
      name: 'Historical',
      line: { color: '#146eb4' }
    },
    {
      type: 'scatter',
      mode: 'lines',
      x: data.x.slice(data.historical.length - 1), // Include one overlap point
      y: [data.historical[data.historical.length - 1], ...data.forecast],
      name: 'Forecast',
      line: { color: '#f79500', dash: 'dash' }
    }
  ] : [];

  return (
    <Card>
      <div className="space-y-4">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
            <p className="text-sm text-gray-500">{period} forecast</p>
          </div>
          <div className="flex items-center gap-1 px-2 py-1 bg-blue-50 text-blue-700 rounded-full text-xs font-medium">
            <span>🤖</span>
            <span>MindsDB</span>
          </div>
        </div>

        {/* Metrics */}
        <div className="grid grid-cols-2 gap-4">
          <div>
            <div className="text-sm text-gray-600">Current {metric}</div>
            <div className="text-2xl font-bold text-gray-900">
              {currentValue.toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-sm text-gray-600">Predicted {metric}</div>
            <div className="text-2xl font-bold text-gray-900">
              {forecastValue.toLocaleString()}
            </div>
            <div className={`text-sm flex items-center gap-1 ${trendColor}`}>
              <span>{trendIcon}</span>
              <span>{change}%</span>
            </div>
          </div>
        </div>

        {/* Confidence */}
        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-gray-600">Confidence</span>
            <span className="font-medium">{confidence}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div 
              className={`h-2 rounded-full transition-all duration-300 ${
                confidence >= 80 ? 'bg-green-500' :
                confidence >= 60 ? 'bg-yellow-500' : 'bg-red-500'
              }`}
              style={{ width: `${confidence}%` }}
            />
          </div>
        </div>

        {/* Chart */}
        {data && (
          <div style={{ height: 200 }}>
            <PlotlyAmazon
              data={chartData}
              layout={{
                title: `${metric} Trend & Forecast`,
                xaxis: { title: 'Time Period' },
                yaxis: { title: metric },
                showlegend: true,
                legend: { orientation: 'h', y: -0.2 }
              }}
            />
          </div>
        )}

        {/* Footer */}
        <div className="text-xs text-gray-500 border-t border-gray-100 pt-3">
          <div className="flex justify-between">
            <span>Model: Time Series Forecasting</span>
            <span>Updated: {new Date().toLocaleDateString()}</span>
          </div>
        </div>
      </div>
    </Card>
  );
}