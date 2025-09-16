'use client';

import React, { useMemo } from 'react';
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  ComposedChart,
} from 'recharts';
import { 
  TrendingUp, 
  DollarSign, 
  ShoppingCart, 
  Package, 
  ArrowUp, 
  ArrowDown,
  Download 
} from 'lucide-react';
import { MetricCard } from '@scout/ui-components';

interface GlobalFilters {
  dateRange: string;
  region: string;
  category: string;
  brand: string;
  timeOfDay: string;
  dayType: string;
}

interface DashboardOverviewProps {
  filters: GlobalFilters;
}

export default function DashboardOverview({ filters }: DashboardOverviewProps) {
  // Generate executive KPI data
  const kpiData = useMemo(() => {
    // Mock data for now - will be replaced with actual API calls
    return {
      gmv: { value: 2500000, change: 12.5, trend: 'up' as const },
      transactions: { value: 15423, change: 8.3, trend: 'up' as const },
      avgBasket: { value: 162, change: 3.8, trend: 'up' as const },
      avgUnitsPerTx: { value: 2.8, change: -1.2, trend: 'down' as const }
    };
  }, [filters]);

  // Generate 30-day trend data
  const trendData = useMemo(() => {
    return Array.from({ length: 30 }, (_, i) => {
      const date = new Date();
      date.setDate(date.getDate() - (29 - i));
      return {
        date: date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
        transactions: Math.floor(Math.random() * 800) + 500 + i * 10,
        gmv: Math.floor(Math.random() * 120000) + 80000 + i * 2000,
      };
    });
  }, [filters]);

  // Generate category performance data
  const categoryData = useMemo(() => {
    const categories = ['Beverages', 'Snacks', 'Personal Care', 'Household', 'Tobacco'];
    return categories.map(category => ({
      category,
      value: Math.floor(Math.random() * 500000) + 100000,
      transactions: Math.floor(Math.random() * 5000) + 2000,
    })).sort((a, b) => b.value - a.value);
  }, [filters]);

  // Generate brand market share data (donut chart data)
  const brandData = useMemo(() => {
    const brands = [
      'Coca-Cola', 'Pepsi', 'Nestle', 'Unilever', 'P&G', 
      'Oishi', 'Jack n Jill', 'Lucky Me'
    ];
    
    const data = brands.map((brand, index) => ({
      name: brand,
      value: Math.floor(Math.random() * 300000) + 50000 * (8 - index),
    }));

    // Add "Others" category
    data.push({
      name: 'Others',
      value: Math.floor(Math.random() * 200000) + 100000,
    });

    return data;
  }, [filters]);

  // Generate hourly heatmap data (simplified for bar chart)
  const hourlyData = useMemo(() => {
    return Array.from({ length: 24 }, (_, hour) => ({
      hour: `${hour}:00`,
      value: Math.floor(Math.random() * 100) + 20 + 
             (hour >= 6 && hour <= 10 ? 30 : 0) + // Morning boost
             (hour >= 17 && hour <= 21 ? 40 : 0), // Evening boost
    }));
  }, [filters]);

  const handleExport = (chartType: string, format: 'png' | 'csv') => {
    console.log(`Exporting ${chartType} as ${format}`);
    // Export functionality will be implemented separately
  };

  const colors = ['#0ea5e9', '#f59e0b', '#10b981', '#ef4444', '#8b5cf6', '#ec4899', '#06b6d4', '#84cc16', '#6b7280'];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-gray-900">Executive Overview</h2>
        <p className="text-gray-600 mt-1">
          Key performance indicators and business metrics overview
        </p>
      </div>

      {/* KPI Strip using shared MetricCard */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <MetricCard
          title="Gross Merchandise Value"
          value={`${(kpiData.gmv.value / 1000).toFixed(1)}K`}
          prefix="₱"
          change={`${kpiData.gmv.change}%`}
          trend={kpiData.gmv.trend}
          icon={<DollarSign size={20} />}
          variant="default"
        />

        <MetricCard
          title="Total Transactions"
          value={kpiData.transactions.value.toLocaleString()}
          change={`${kpiData.transactions.change}%`}
          trend={kpiData.transactions.trend}
          icon={<ShoppingCart size={20} />}
          variant="default"
        />

        <MetricCard
          title="Average Basket Size"
          value={kpiData.avgBasket.value.toFixed(0)}
          prefix="₱"
          change={`${kpiData.avgBasket.change}%`}
          trend={kpiData.avgBasket.trend}
          icon={<TrendingUp size={20} />}
          variant="default"
        />

        <MetricCard
          title="Items per Transaction"
          value={kpiData.avgUnitsPerTx.value.toFixed(1)}
          change={`${Math.abs(kpiData.avgUnitsPerTx.change)}%`}
          trend={kpiData.avgUnitsPerTx.trend}
          icon={<Package size={20} />}
          variant="default"
        />
      </div>

      {/* Main Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Transaction & GMV Trends */}
        <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Transaction & GMV Trends (30 Days)</h3>
            <button
              onClick={() => handleExport('trends', 'png')}
              className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors text-sm"
            >
              <Download size={16} />
              Export
            </button>
          </div>
          <ResponsiveContainer width="100%" height={300}>
            <ComposedChart data={trendData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis 
                dataKey="date" 
                stroke="#6b7280" 
                fontSize={12}
                interval={2}
              />
              <YAxis yAxisId="left" stroke="#6b7280" fontSize={12} />
              <YAxis yAxisId="right" orientation="right" stroke="#6b7280" fontSize={12} />
              <Tooltip 
                contentStyle={{
                  backgroundColor: 'rgba(255, 255, 255, 0.95)',
                  border: '1px solid #e5e7eb',
                  borderRadius: '6px',
                }}
                formatter={(value: any, name: string) => {
                  if (name === 'gmv') return [`₱${(value / 1000).toFixed(0)}K`, 'GMV'];
                  return [value.toLocaleString(), 'Transactions'];
                }}
              />
              <Bar 
                yAxisId="left"
                dataKey="transactions" 
                fill="#0ea5e9" 
                opacity={0.7}
              />
              <Line
                yAxisId="right"
                type="monotone"
                dataKey="gmv"
                stroke="#10b981"
                strokeWidth={3}
                dot={{ fill: '#10b981', r: 4 }}
                activeDot={{ r: 6 }}
              />
            </ComposedChart>
          </ResponsiveContainer>
        </div>

        {/* Category Performance */}
        <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Category Performance</h3>
            <button
              onClick={() => handleExport('category', 'png')}
              className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors text-sm"
            >
              <Download size={16} />
              Export
            </button>
          </div>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart 
              data={categoryData} 
              layout="horizontal"
              margin={{ top: 20, right: 60, bottom: 20, left: 80 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis 
                type="number" 
                stroke="#6b7280" 
                fontSize={11}
                tickFormatter={(value) => `₱${(value / 1000).toFixed(0)}K`}
              />
              <YAxis 
                type="category" 
                dataKey="category" 
                stroke="#6b7280" 
                fontSize={11}
                width={70}
              />
              <Tooltip 
                contentStyle={{
                  backgroundColor: 'rgba(255, 255, 255, 0.95)',
                  border: '1px solid #e5e7eb',
                  borderRadius: '6px',
                }}
                formatter={(value: any) => [`₱${(value / 1000).toFixed(0)}K`, 'Revenue']}
              />
              <Bar 
                dataKey="value" 
                fill="#f59e0b" 
                radius={[0, 4, 4, 0]}
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Bottom Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Brand Market Share */}
        <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Brand Market Share</h3>
            <button
              onClick={() => handleExport('brand-share', 'png')}
              className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors text-sm"
            >
              <Download size={16} />
              Export
            </button>
          </div>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={brandData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={120}
                paddingAngle={2}
                dataKey="value"
                label={(entry) => entry.name}
                labelLine={false}
              >
                {brandData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
                ))}
              </Pie>
              <Tooltip 
                contentStyle={{
                  backgroundColor: 'rgba(255, 255, 255, 0.95)',
                  border: '1px solid #e5e7eb',
                  borderRadius: '6px',
                }}
                formatter={(value: any) => [`₱${(value / 1000).toFixed(0)}K`, 'Revenue']}
              />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Hourly Transaction Pattern */}
        <div className="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold">Hourly Transaction Pattern</h3>
            <button
              onClick={() => handleExport('hourly', 'png')}
              className="flex items-center gap-2 px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors text-sm"
            >
              <Download size={16} />
              Export
            </button>
          </div>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={hourlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis 
                dataKey="hour" 
                stroke="#6b7280" 
                fontSize={10}
                interval={2}
              />
              <YAxis stroke="#6b7280" fontSize={12} />
              <Tooltip 
                contentStyle={{
                  backgroundColor: 'rgba(255, 255, 255, 0.95)',
                  border: '1px solid #e5e7eb',
                  borderRadius: '6px',
                }}
                formatter={(value: any) => [value, 'Transactions']}
              />
              <Bar 
                dataKey="value" 
                fill="#0ea5e9"
                radius={[4, 4, 0, 0]}
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}