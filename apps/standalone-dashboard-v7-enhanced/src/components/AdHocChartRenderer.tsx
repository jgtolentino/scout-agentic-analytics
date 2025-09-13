import React from 'react';
import { AdHocPanel } from '@/hooks/useAdHocChart';
import { BarChart, Bar, LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

interface AdHocChartRendererProps {
  panel: AdHocPanel;
  loading: boolean;
  onPin: () => void;
  onRemove: () => void;
  onRefresh: () => void;
}

const COLORS = [
  '#8884d8', '#82ca9d', '#ffc658', '#ff7300', '#00ff00',
  '#ff0000', '#0000ff', '#ffff00', '#ff00ff', '#00ffff'
];

export default function AdHocChartRenderer({
  panel,
  loading,
  onPin,
  onRemove,
  onRefresh
}: AdHocChartRendererProps) {
  
  const renderChart = () => {
    if (loading) {
      return (
        <div className="h-64 flex items-center justify-center">
          <div className="flex items-center space-x-2 text-gray-500">
            <div className="animate-spin w-5 h-5 border-2 border-blue-500 border-t-transparent rounded-full"></div>
            <span>Loading chart data...</span>
          </div>
        </div>
      );
    }
    
    if (!panel.data || panel.data.length === 0) {
      return (
        <div className="h-64 flex items-center justify-center text-gray-500">
          <div className="text-center">
            <div className="text-4xl mb-2">📊</div>
            <div>No data available</div>
            <button 
              onClick={onRefresh}
              className="mt-2 px-3 py-1 text-sm bg-gray-100 rounded hover:bg-gray-200"
            >
              Retry
            </button>
          </div>
        </div>
      );
    }
    
    const { spec, data } = panel;
    
    switch (spec.chart) {
      case 'bar':
      case 'stacked_bar':
        return (
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey={spec.x} />
              <YAxis />
              <Tooltip />
              <Legend />
              {spec.series ? (
                // Multiple series
                [...new Set(data.map(d => d[spec.series!]))].map((series, i) => (
                  <Bar 
                    key={series} 
                    dataKey={spec.y} 
                    fill={COLORS[i % COLORS.length]}
                    name={String(series)}
                  />
                ))
              ) : (
                // Single series
                <Bar dataKey={spec.y} fill={COLORS[0]} />
              )}
            </BarChart>
          </ResponsiveContainer>
        );
        
      case 'line':
        return (
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={data} margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey={spec.x} />
              <YAxis />
              <Tooltip />
              <Legend />
              {spec.series ? (
                // Multiple series
                [...new Set(data.map(d => d[spec.series!]))].map((series, i) => (
                  <Line 
                    key={series}
                    type="monotone" 
                    dataKey={spec.y} 
                    stroke={COLORS[i % COLORS.length]}
                    name={String(series)}
                  />
                ))
              ) : (
                // Single series
                <Line type="monotone" dataKey={spec.y} stroke={COLORS[0]} />
              )}
            </LineChart>
          </ResponsiveContainer>
        );
        
      case 'pie':
        return (
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={data}
                cx="50%"
                cy="50%"
                outerRadius={80}
                fill="#8884d8"
                dataKey={spec.y}
                nameKey={spec.x}
              >
                {data.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        );
        
      case 'table':
        return (
          <div className="max-h-64 overflow-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 sticky top-0">
                <tr>
                  {Object.keys(data[0] || {}).map(key => (
                    <th key={key} className="px-3 py-2 text-left font-semibold border-b">
                      {key}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.slice(0, 50).map((row, i) => (
                  <tr key={i} className="hover:bg-gray-50">
                    {Object.values(row).map((value, j) => (
                      <td key={j} className="px-3 py-2 border-b">
                        {typeof value === 'number' ? value.toLocaleString() : String(value)}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
            {data.length > 50 && (
              <div className="p-2 text-center text-gray-500 text-xs">
                Showing first 50 of {data.length} rows
              </div>
            )}
          </div>
        );
        
      default:
        return (
          <div className="h-64 flex items-center justify-center text-gray-500">
            <div className="text-center">
              <div className="text-4xl mb-2">🚧</div>
              <div>Chart type "{spec.chart}" not implemented</div>
              <div className="text-xs mt-1">Available: bar, line, pie, table</div>
            </div>
          </div>
        );
    }
  };
  
  const formatTimestamp = (timestamp: number) => {
    const now = Date.now();
    const diff = now - timestamp;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
    return new Date(timestamp).toLocaleString();
  };
  
  return (
    <div className="bg-white rounded-lg shadow-lg border p-4 mb-4">
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex-1">
          <div className="flex items-center space-x-2 mb-1">
            <span className="text-lg">🤖</span>
            <h3 className="font-semibold text-gray-800">
              {panel.spec.chart.charAt(0).toUpperCase() + panel.spec.chart.slice(1)} Chart
            </h3>
            <span className="text-xs text-gray-500">
              {formatTimestamp(panel.timestamp)}
            </span>
          </div>
          
          <p className="text-sm text-gray-600 mb-2">
            {panel.explain}
          </p>
          
          {/* Chart metadata */}
          <div className="flex flex-wrap gap-2 text-xs">
            {panel.spec.x && (
              <span className="px-2 py-1 bg-blue-100 text-blue-700 rounded">
                X: {panel.spec.x}
              </span>
            )}
            {panel.spec.y && (
              <span className="px-2 py-1 bg-green-100 text-green-700 rounded">
                Y: {panel.spec.y}
              </span>
            )}
            {panel.spec.agg && (
              <span className="px-2 py-1 bg-purple-100 text-purple-700 rounded">
                {panel.spec.agg}
              </span>
            )}
            {panel.spec.topK && (
              <span className="px-2 py-1 bg-orange-100 text-orange-700 rounded">
                Top {panel.spec.topK}
              </span>
            )}
          </div>
        </div>
        
        {/* Actions */}
        <div className="flex items-center space-x-2 ml-4">
          <button
            onClick={onPin}
            className={`p-1.5 rounded text-sm ${
              panel.pinned 
                ? 'bg-yellow-100 text-yellow-700 hover:bg-yellow-200' 
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
            title={panel.pinned ? 'Unpin' : 'Pin (prevents auto-cleanup)'}
          >
            📌
          </button>
          
          <button
            onClick={onRefresh}
            disabled={loading}
            className="p-1.5 bg-gray-100 text-gray-600 rounded hover:bg-gray-200 disabled:opacity-50 text-sm"
            title="Refresh data"
          >
            🔄
          </button>
          
          <button
            onClick={onRemove}
            className="p-1.5 bg-red-100 text-red-600 rounded hover:bg-red-200 text-sm"
            title="Remove chart"
          >
            ✕
          </button>
        </div>
      </div>
      
      {/* Chart */}
      <div className="border rounded-lg bg-gray-50">
        {renderChart()}
      </div>
      
      {/* SQL Query (collapsible) */}
      <details className="mt-3">
        <summary className="cursor-pointer text-xs text-gray-500 hover:text-gray-700">
          View SQL Query ({panel.data?.length || 0} rows)
        </summary>
        <pre className="mt-2 p-2 bg-gray-100 rounded text-xs overflow-x-auto">
          {panel.sql}
        </pre>
      </details>
    </div>
  );
}