'use client'

import React, { useState, useEffect } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell
} from 'recharts'
import { Calendar, TrendingUp, Users, ShoppingCart, MapPin, Filter } from 'lucide-react'
import type { ScoutTransaction, ScoutFilters } from '../../types/scout'

// Transaction Dashboard Component
export const TransactionDashboard: React.FC = () => {
  const [filters, setFilters] = useState<ScoutFilters>({
    date_range: {
      start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      end: new Date().toISOString().split('T')[0]
    },
    store_ids: ['102', '103', '104', '109', '110', '112']
  })

  const [selectedView, setSelectedView] = useState<'overview' | 'brands' | 'stores' | 'customers'>('overview')

  // Fetch transaction data
  const { data: transactionData, isLoading: transactionsLoading, error: transactionsError } = useQuery({
    queryKey: ['scout-transactions', filters],
    queryFn: async () => {
      const params = new URLSearchParams()

      if (filters.store_ids?.length) {
        params.append('store_ids', filters.store_ids.join(','))
      }
      if (filters.brands?.length) {
        params.append('brands', filters.brands.join(','))
      }
      if (filters.categories?.length) {
        params.append('categories', filters.categories.join(','))
      }
      if (filters.date_range) {
        params.append('date_start', filters.date_range.start)
        params.append('date_end', filters.date_range.end)
      }
      params.append('limit', '5000')

      const response = await fetch(`/api/scout/transactions?${params}`, {
        cache: 'no-store',
        headers: {
          'Cache-Control': 'no-cache'
        }
      })
      if (!response.ok) {
        throw new Error('Failed to fetch transactions')
      }
      return response.json()
    },
    refetchInterval: 300000, // Refresh every 5 minutes
    staleTime: 240000 // Consider data stale after 4 minutes
  })

  // Fetch KPIs
  const { data: kpiData, isLoading: kpiLoading } = useQuery({
    queryKey: ['scout-kpis', filters],
    queryFn: async () => {
      const params = new URLSearchParams()

      if (filters.store_ids?.length) {
        params.append('store_ids', filters.store_ids.join(','))
      }
      if (filters.categories?.length) {
        params.append('categories', filters.categories.join(','))
      }
      if (filters.date_range) {
        params.append('date_start', filters.date_range.start)
        params.append('date_end', filters.date_range.end)
      }

      const response = await fetch(`/api/transactions/kpis?${params}`, {
        cache: 'no-store',
        headers: {
          'Cache-Control': 'no-cache'
        }
      })
      if (!response.ok) {
        throw new Error('Failed to fetch KPIs')
      }
      return response.json()
    },
    refetchInterval: 300000
  })

  // Process data for charts
  const processedData = React.useMemo(() => {
    if (!transactionData?.data) return null

    const transactions: ScoutTransaction[] = transactionData.data

    // Time series data (daily aggregation)
    const dailyData = transactions.reduce((acc, txn) => {
      const date = txn.date_ph
      if (!acc[date]) {
        acc[date] = {
          date,
          sales: 0,
          transactions: 0,
          customers: new Set()
        }
      }
      acc[date].sales += txn.total_price || 0
      acc[date].transactions++
      if (txn.facial_id) {
        acc[date].customers.add(txn.facial_id)
      }
      return acc
    }, {} as Record<string, any>)

    const timeSeriesData = Object.values(dailyData).map((day: any) => ({
      ...day,
      customers: day.customers.size
    })).sort((a: any, b: any) => a.date.localeCompare(b.date))

    // Brand distribution
    const brandData = transactions.reduce((acc, txn) => {
      const brand = txn.brand || 'Unknown'
      if (!acc[brand]) {
        acc[brand] = { brand, sales: 0, transactions: 0 }
      }
      acc[brand].sales += txn.total_price || 0
      acc[brand].transactions++
      return acc
    }, {} as Record<string, any>)

    const topBrands = Object.values(brandData)
      .sort((a: any, b: any) => b.sales - a.sales)
      .slice(0, 10)

    // Store performance
    const storeData = transactions.reduce((acc, txn) => {
      const store = txn.store_id || 'Unknown'
      const storeName = txn.store_name || `Store ${store}`
      if (!acc[store]) {
        acc[store] = {
          store_id: store,
          store_name: storeName,
          sales: 0,
          transactions: 0,
          customers: new Set()
        }
      }
      acc[store].sales += txn.total_price || 0
      acc[store].transactions++
      if (txn.facial_id) {
        acc[store].customers.add(txn.facial_id)
      }
      return acc
    }, {} as Record<string, any>)

    const storePerformance = Object.values(storeData).map((store: any) => ({
      ...store,
      customers: store.customers.size,
      avg_transaction: store.sales / store.transactions
    })).sort((a: any, b: any) => b.sales - a.sales)

    // Time of day analysis
    const timeOfDayData = transactions.reduce((acc, txn) => {
      const timeSegment = txn.time_of_day || 'Unknown'
      if (!acc[timeSegment]) {
        acc[timeSegment] = { time_of_day: timeSegment, sales: 0, transactions: 0 }
      }
      acc[timeSegment].sales += txn.total_price || 0
      acc[timeSegment].transactions++
      return acc
    }, {} as Record<string, any>)

    const timeOfDayChart = Object.values(timeOfDayData)

    return {
      timeSeries: timeSeriesData,
      brands: topBrands,
      stores: storePerformance,
      timeOfDay: timeOfDayChart
    }
  }, [transactionData])

  // Color palette for charts
  const colors = ['#0066CC', '#FF6B35', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#2C3E50']

  if (transactionsLoading || kpiLoading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-scout-primary"></div>
      </div>
    )
  }

  if (transactionsError) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-4">
        <h3 className="text-red-800 font-medium">Error Loading Data</h3>
        <p className="text-red-600 text-sm mt-1">
          {transactionsError instanceof Error ? transactionsError.message : 'Unknown error occurred'}
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-6" data-testid="transaction-dashboard">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Scout v7 Analytics</h1>
            <p className="text-gray-600 mt-1">
              Real-time transaction analytics and customer insights
            </p>
          </div>

          <div className="flex items-center space-x-4 mt-4 sm:mt-0">
            <div className="flex items-center text-sm text-gray-500">
              <Calendar className="w-4 h-4 mr-1" />
              {filters.date_range?.start} to {filters.date_range?.end}
            </div>

            <button className="flex items-center px-3 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50">
              <Filter className="w-4 h-4 mr-1" />
              Filters
            </button>
          </div>
        </div>
      </div>

      {/* KPI Cards */}
      {kpiData?.data && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <KPICard
            title="Total Sales"
            value={`₱${kpiData.data.total_sales?.value?.toLocaleString() || '0'}`}
            change={kpiData.data.total_sales?.change_percent}
            trend={kpiData.data.total_sales?.trend}
            icon={<TrendingUp className="w-5 h-5" />}
            color="text-green-600"
          />

          <KPICard
            title="Transactions"
            value={kpiData.data.transaction_count?.value?.toLocaleString() || '0'}
            change={kpiData.data.transaction_count?.change_percent}
            trend={kpiData.data.transaction_count?.trend}
            icon={<ShoppingCart className="w-5 h-5" />}
            color="text-blue-600"
          />

          <KPICard
            title="Unique Customers"
            value={kpiData.data.unique_customers?.value?.toLocaleString() || '0'}
            change={kpiData.data.unique_customers?.change_percent}
            trend={kpiData.data.unique_customers?.trend}
            icon={<Users className="w-5 h-5" />}
            color="text-purple-600"
          />

          <KPICard
            title="Avg. Basket"
            value={`₱${Math.round(kpiData.data.average_basket_size?.value || 0)}`}
            change={kpiData.data.average_basket_size?.change_percent}
            trend={kpiData.data.average_basket_size?.trend}
            icon={<ShoppingCart className="w-5 h-5" />}
            color="text-orange-600"
          />
        </div>
      )}

      {/* View Selector */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="flex space-x-4">
          {[
            { key: 'overview', label: 'Overview' },
            { key: 'brands', label: 'Brand Performance' },
            { key: 'stores', label: 'Store Analysis' },
            { key: 'customers', label: 'Customer Insights' }
          ].map(view => (
            <button
              key={view.key}
              onClick={() => setSelectedView(view.key as any)}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                selectedView === view.key
                  ? 'bg-scout-primary text-white'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              {view.label}
            </button>
          ))}
        </div>
      </div>

      {/* Charts based on selected view */}
      {processedData && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {selectedView === 'overview' && (
            <>
              {/* Sales Trend */}
              <ChartCard title="Sales Trend" subtitle="Daily sales over time">
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={processedData.timeSeries}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <Tooltip formatter={(value, name) => [
                      name === 'sales' ? `₱${Number(value).toLocaleString()}` : value,
                      name === 'sales' ? 'Sales' : name === 'transactions' ? 'Transactions' : 'Customers'
                    ]} />
                    <Legend />
                    <Line
                      type="monotone"
                      dataKey="sales"
                      stroke="#0066CC"
                      strokeWidth={2}
                      name="Sales (₱)"
                    />
                  </LineChart>
                </ResponsiveContainer>
              </ChartCard>

              {/* Time of Day Analysis */}
              <ChartCard title="Time of Day Performance" subtitle="Sales by time segment">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={processedData.timeOfDay}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="time_of_day" />
                    <YAxis />
                    <Tooltip formatter={(value) => [`₱${Number(value).toLocaleString()}`, 'Sales']} />
                    <Bar dataKey="sales" fill="#FF6B35" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>
            </>
          )}

          {selectedView === 'brands' && (
            <>
              {/* Top Brands */}
              <ChartCard title="Top Performing Brands" subtitle="Sales by brand">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={processedData.brands}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="brand" angle={-45} textAnchor="end" height={80} />
                    <YAxis />
                    <Tooltip formatter={(value) => [`₱${Number(value).toLocaleString()}`, 'Sales']} />
                    <Bar dataKey="sales" fill="#4ECDC4" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>

              {/* Brand Distribution Pie */}
              <ChartCard title="Brand Share" subtitle="Market share by sales">
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={processedData.brands.slice(0, 8)}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="sales"
                      nameKey="brand"
                    >
                      {processedData.brands.slice(0, 8).map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
                      ))}
                    </Pie>
                    <Tooltip formatter={(value) => [`₱${Number(value).toLocaleString()}`, 'Sales']} />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </ChartCard>
            </>
          )}

          {selectedView === 'stores' && (
            <>
              {/* Store Performance */}
              <ChartCard title="Store Performance" subtitle="Sales by store location">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={processedData.stores}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="store_name" angle={-45} textAnchor="end" height={80} />
                    <YAxis />
                    <Tooltip formatter={(value) => [`₱${Number(value).toLocaleString()}`, 'Sales']} />
                    <Bar dataKey="sales" fill="#45B7D1" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>

              {/* Store Customers */}
              <ChartCard title="Customer Count by Store" subtitle="Unique customers per store">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={processedData.stores}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="store_name" angle={-45} textAnchor="end" height={80} />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="customers" fill="#96CEB4" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>
            </>
          )}
        </div>
      )}

      {/* Data Quality Indicator */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 bg-green-500 rounded-full"></div>
            <span className="text-sm text-gray-600">
              Data Quality: {transactionData?.performance?.row_count || 0} records processed
            </span>
          </div>

          <div className="text-sm text-gray-500">
            Query time: {transactionData?.performance?.query_time_ms || 0}ms
            {transactionData?.cache?.hit && ' (cached)'}
          </div>
        </div>
      </div>
    </div>
  )
}

// KPI Card Component
interface KPICardProps {
  title: string
  value: string
  change?: number | null
  trend?: 'up' | 'down' | 'stable'
  icon: React.ReactNode
  color: string
}

const KPICard: React.FC<KPICardProps> = ({ title, value, change, trend, icon, color }) => (
  <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm font-medium text-gray-600">{title}</p>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
        {change !== null && change !== undefined && (
          <div className={`flex items-center mt-1 text-sm ${
            change > 0 ? 'text-green-600' : change < 0 ? 'text-red-600' : 'text-gray-600'
          }`}>
            <span>{change > 0 ? '+' : ''}{change}%</span>
          </div>
        )}
      </div>

      <div className={`${color}`}>
        {icon}
      </div>
    </div>
  </div>
)

// Chart Card Component
interface ChartCardProps {
  title: string
  subtitle?: string
  children: React.ReactNode
}

const ChartCard: React.FC<ChartCardProps> = ({ title, subtitle, children }) => (
  <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
    <div className="mb-4">
      <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
      {subtitle && <p className="text-sm text-gray-600 mt-1">{subtitle}</p>}
    </div>
    {children}
  </div>
)

export default TransactionDashboard