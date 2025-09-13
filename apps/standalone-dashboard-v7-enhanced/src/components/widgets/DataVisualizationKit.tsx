import React, { useState } from 'react';
import { ComposedChart, Line, Bar, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar } from 'recharts';

interface DataVisualizationKitProps {
  props: {
    title?: string;
    kitType?: 'dashboard' | 'analytics' | 'financial' | 'operational';
    components?: string[];
    layout?: 'grid' | 'masonry' | 'flow';
    responsive?: boolean;
  };
  data?: {
    timeSeries?: any[];
    categories?: any[];
    metrics?: any[];
    geographic?: any[];
  };
}

export const DataVisualizationKit: React.FC<DataVisualizationKitProps> = ({
  props = {},
  data = {}
}) => {
  const {
    title = 'Data Visualization Kit',
    kitType = 'dashboard',
    components = ['timeseries', 'pie', 'metrics', 'radar'],
    layout = 'grid',
    responsive = true
  } = props;

  const [activeComponent, setActiveComponent] = useState<string | null>(null);

  // Mock data generators
  const mockTimeSeriesData = [
    { month: 'Jan', sales: 4000, profit: 2400, expenses: 2400 },
    { month: 'Feb', sales: 3000, profit: 1398, expenses: 2210 },
    { month: 'Mar', sales: 2000, profit: 9800, expenses: 2290 },
    { month: 'Apr', sales: 2780, profit: 3908, expenses: 2000 },
    { month: 'May', sales: 1890, profit: 4800, expenses: 2181 },
    { month: 'Jun', sales: 2390, profit: 3800, expenses: 2500 }
  ];

  const mockCategoryData = [
    { name: 'Electronics', value: 400, color: '#0088FE' },
    { name: 'Clothing', value: 300, color: '#00C49F' },
    { name: 'Food', value: 300, color: '#FFBB28' },
    { name: 'Books', value: 200, color: '#FF8042' },
    { name: 'Sports', value: 150, color: '#8884D8' }
  ];

  const mockRadarData = [
    { subject: 'Sales', A: 120, B: 110, fullMark: 150 },
    { subject: 'Marketing', A: 98, B: 130, fullMark: 150 },
    { subject: 'Development', A: 86, B: 130, fullMark: 150 },
    { subject: 'Support', A: 99, B: 100, fullMark: 150 },
    { subject: 'Quality', A: 85, B: 90, fullMark: 150 },
    { subject: 'Operations', A: 65, B: 85, fullMark: 150 }
  ];

  const mockMetrics = [
    { label: 'Revenue', value: '₱2.8M', change: '+12.5%', trend: 'up' },
    { label: 'Orders', value: '15,847', change: '+8.3%', trend: 'up' },
    { label: 'Customers', value: '8,432', change: '-2.1%', trend: 'down' },
    { label: 'Conversion', value: '3.42%', change: '+0.8%', trend: 'up' }
  ];

  // Use provided data or fallback to mock data
  const timeSeriesData = data.timeSeries || mockTimeSeriesData;
  const categoryData = data.categories || mockCategoryData;
  const radarData = data.metrics || mockRadarData;
  const metricsData = data.geographic || mockMetrics;

  const renderTimeSeriesChart = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">📈 Time Series Analysis</h4>
      <ResponsiveContainer width="100%" height={250}>
        <ComposedChart data={timeSeriesData}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="month" />
          <YAxis />
          <Tooltip />
          <Legend />
          <Bar dataKey="expenses" fill="#ff7c7c" />
          <Area type="monotone" dataKey="profit" fill="#8dd1e1" />
          <Line type="monotone" dataKey="sales" stroke="#82ca9d" strokeWidth={3} />
        </ComposedChart>
      </ResponsiveContainer>
    </div>
  );

  const renderPieChart = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">🥧 Category Distribution</h4>
      <ResponsiveContainer width="100%" height={250}>
        <PieChart>
          <Pie
            data={categoryData}
            cx="50%"
            cy="50%"
            innerRadius={60}
            outerRadius={80}
            paddingAngle={5}
            dataKey="value"
          >
            {categoryData.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} />
            ))}
          </Pie>
          <Tooltip />
          <Legend />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );

  const renderRadarChart = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">🎯 Performance Radar</h4>
      <ResponsiveContainer width="100%" height={250}>
        <RadarChart data={radarData}>
          <PolarGrid />
          <PolarAngleAxis dataKey="subject" />
          <PolarRadiusAxis angle={90} domain={[0, 150]} />
          <Radar
            name="Current"
            dataKey="A"
            stroke="#8884d8"
            fill="#8884d8"
            fillOpacity={0.6}
          />
          <Radar
            name="Target"
            dataKey="B"
            stroke="#82ca9d"
            fill="#82ca9d"
            fillOpacity={0.6}
          />
          <Legend />
          <Tooltip />
        </RadarChart>
      </ResponsiveContainer>
    </div>
  );

  const renderMetricsGrid = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">📊 Key Metrics</h4>
      <div className="grid grid-cols-2 gap-4">
        {metricsData.map((metric: any, index) => (
          <div key={index} className="text-center p-3 bg-gray-50 rounded">
            <div className="text-sm text-gray-600">{metric.label}</div>
            <div className="text-xl font-bold text-gray-900">{metric.value}</div>
            <div className={`text-xs font-medium ${
              metric.trend === 'up' ? 'text-green-600' : 'text-red-600'
            }`}>
              {metric.trend === 'up' ? '📈' : '📉'} {metric.change}
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  const renderHeatmap = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">🔥 Activity Heatmap</h4>
      <div className="grid grid-cols-7 gap-2">
        {[...Array(35)].map((_, i) => {
          const intensity = Math.random();
          return (
            <div
              key={i}
              className="aspect-square rounded"
              style={{
                backgroundColor: `rgba(59, 130, 246, ${intensity})`,
                minHeight: '20px'
              }}
              title={`Day ${i + 1}: ${(intensity * 100).toFixed(0)}% activity`}
            />
          );
        })}
      </div>
      <div className="flex justify-between text-xs text-gray-500 mt-2">
        <span>Less</span>
        <span>More</span>
      </div>
    </div>
  );

  const renderTreemap = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">🗺️ Hierarchical Data</h4>
      <div className="grid grid-cols-8 grid-rows-4 gap-1 h-48">
        {categoryData.map((item, index) => (
          <div
            key={index}
            className="rounded flex items-center justify-center text-white text-xs font-medium"
            style={{
              backgroundColor: item.color,
              gridColumn: `span ${Math.max(1, Math.ceil(item.value / 100))}`,
              gridRow: `span ${Math.max(1, Math.ceil(item.value / 200))}`
            }}
          >
            {item.name}
          </div>
        ))}
      </div>
    </div>
  );

  const renderSankeyPlaceholder = () => (
    <div className="bg-white rounded-lg border p-4">
      <h4 className="font-semibold text-gray-800 mb-4">🌊 Flow Analysis</h4>
      <div className="h-48 bg-gradient-to-r from-blue-100 via-green-100 to-purple-100 rounded flex items-center justify-center">
        <div className="text-center text-gray-600">
          <div className="text-4xl mb-2">🌊</div>
          <div>Sankey Diagram</div>
          <div className="text-sm">Flow visualization ready</div>
        </div>
      </div>
    </div>
  );

  const renderComponent = (componentType: string) => {
    switch (componentType) {
      case 'timeseries':
        return renderTimeSeriesChart();
      case 'pie':
        return renderPieChart();
      case 'radar':
        return renderRadarChart();
      case 'metrics':
        return renderMetricsGrid();
      case 'heatmap':
        return renderHeatmap();
      case 'treemap':
        return renderTreemap();
      case 'sankey':
        return renderSankeyPlaceholder();
      default:
        return null;
    }
  };

  const getGridClasses = () => {
    switch (layout) {
      case 'masonry':
        return 'columns-1 md:columns-2 lg:columns-3 gap-4 space-y-4';
      case 'flow':
        return 'flex flex-wrap gap-4';
      default:
        return 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4';
    }
  };

  const availableComponents = [
    { id: 'timeseries', label: 'Time Series', icon: '📈' },
    { id: 'pie', label: 'Pie Chart', icon: '🥧' },
    { id: 'radar', label: 'Radar Chart', icon: '🎯' },
    { id: 'metrics', label: 'Metrics Grid', icon: '📊' },
    { id: 'heatmap', label: 'Heatmap', icon: '🔥' },
    { id: 'treemap', label: 'Treemap', icon: '🗺️' },
    { id: 'sankey', label: 'Sankey', icon: '🌊' }
  ];

  return (
    <div className="p-4 border rounded-lg bg-gray-50">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-lg font-semibold text-gray-800">{title}</h3>
          <div className="text-sm text-gray-600">
            {kitType.charAt(0).toUpperCase() + kitType.slice(1)} Kit • {components.length} components
          </div>
        </div>
        
        {/* Component Toggle */}
        <div className="flex flex-wrap gap-2">
          {availableComponents.map(comp => (
            <button
              key={comp.id}
              onClick={() => setActiveComponent(
                activeComponent === comp.id ? null : comp.id
              )}
              className={`px-2 py-1 text-xs font-medium rounded transition-colors flex items-center space-x-1 ${
                components.includes(comp.id)
                  ? activeComponent === comp.id
                    ? 'bg-blue-600 text-white'
                    : 'bg-blue-100 text-blue-600'
                  : 'bg-gray-200 text-gray-500'
              }`}
            >
              <span>{comp.icon}</span>
              <span>{comp.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Components Grid */}
      <div className={getGridClasses()}>
        {components.map(componentType => renderComponent(componentType))}
      </div>

      {/* Kit Info */}
      <div className="mt-6 bg-white border rounded-lg p-4">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-center text-sm">
          <div>
            <div className="font-medium text-gray-600">Kit Type</div>
            <div className="text-gray-900">{kitType}</div>
          </div>
          <div>
            <div className="font-medium text-gray-600">Components</div>
            <div className="text-gray-900">{components.length}</div>
          </div>
          <div>
            <div className="font-medium text-gray-600">Layout</div>
            <div className="text-gray-900">{layout}</div>
          </div>
          <div>
            <div className="font-medium text-gray-600">Responsive</div>
            <div className="text-gray-900">{responsive ? '✅' : '❌'}</div>
          </div>
        </div>
      </div>
    </div>
  );
};