'use client'

import React, { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  ScatterChart,
  Scatter,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar
} from 'recharts'
import { TrendingUp, Award, Target, DollarSign, Users, Zap } from 'lucide-react'
import type { BrandPerformance, ScoutFilters } from '../../types/scout'

// Brand Analytics Component
export const BrandAnalytics: React.FC = () => {
  const [filters, setFilters] = useState<ScoutFilters>({
    categories: undefined // Show all categories by default
  })

  const [selectedBrand, setSelectedBrand] = useState<string | null>(null)
  const [viewMode, setViewMode] = useState<'performance' | 'competitive' | 'pricing'>('performance')

  // Fetch brand analytics data
  const { data: brandData, isLoading, error } = useQuery({
    queryKey: ['scout-brand-analytics', filters],
    queryFn: async () => {
      const params = new URLSearchParams({ type: 'brands' })

      if (filters.categories?.length) {
        params.append('categories', filters.categories.join(','))
      }

      const { fetchJSON } = await import('../../lib/api');
      return await fetchJSON(`/scout/analytics?${params}`)
    },
    refetchInterval: 600000, // Refresh every 10 minutes
    staleTime: 480000 // Consider data stale after 8 minutes
  })

  // Process data for different visualizations
  const processedData = React.useMemo(() => {
    if (!brandData) return null

    const brands: BrandPerformance[] = Array.isArray(brandData) ? brandData : (brandData as any)?.data || []

    // Brand tier distribution
    const tierDistribution = brands.reduce((acc, brand) => {
      const tier = brand.brand_tier || 'Unknown'
      if (!acc[tier]) {
        acc[tier] = { tier, count: 0, total_crp: 0, avg_market_share: 0 }
      }
      acc[tier].count++
      acc[tier].total_crp += brand.consumer_reach_points || 0
      acc[tier].avg_market_share += brand.market_share_percent || 0
      return acc
    }, {} as Record<string, any>)

    const tierData = Object.values(tierDistribution).map((tier: any) => ({
      ...tier,
      avg_market_share: tier.avg_market_share / tier.count
    }))

    // Market positioning matrix (Price vs Market Share)
    const positioningData = brands.map(brand => ({
      brand_name: brand.brand_name,
      market_share: brand.market_share_percent || 0,
      price_index: (brand.vs_category_avg || 1) * 100, // Convert to percentage
      consumer_reach_points: brand.consumer_reach_points || 0,
      brand_tier: brand.brand_tier,
      growth_status: brand.growth_status
    }))

    // Competitive analysis
    const competitiveData = brands
      .filter(brand => brand.market_share_percent && brand.market_share_percent > 1) // Only significant brands
      .map(brand => ({
        brand_name: brand.brand_name,
        market_share: brand.market_share_percent || 0,
        consumer_reach_points: brand.consumer_reach_points || 0,
        avg_price: brand.avg_price_php || 0,
        price_positioning: brand.value_proposition,
        growth_rate: brand.brand_growth_yoy || 0,
        competitive_status: brand.position_type || 'unknown'
      }))

    // Radar chart data for brand health
    const radarData = selectedBrand
      ? (() => {
          const selectedBrandData = brands.find(brand => brand.brand_name === selectedBrand)
          return selectedBrandData ? [
            {
              metric: 'Market Share',
              value: Math.min((selectedBrandData.market_share_percent || 0) * 4, 100), // Scale to 0-100
              fullMark: 100
            },
            {
              metric: 'CRP',
              value: Math.min((selectedBrandData.consumer_reach_points || 0) / 10, 100),
              fullMark: 100
            },
            {
              metric: 'Price Competitiveness',
              value: Math.max(0, 100 - Math.abs(((selectedBrandData.vs_category_avg || 1) - 1) * 100)),
              fullMark: 100
            },
            {
              metric: 'Growth',
              value: Math.min(Math.max((selectedBrandData.brand_growth_yoy || 0) * 10 + 50, 0), 100),
              fullMark: 100
            },
            {
              metric: 'Channel Presence',
              value: Math.min((selectedBrandData.channels_available || 0) * 12.5, 100),
              fullMark: 100
            }
          ] : []
        })()
      : []

    return {
      tiers: tierData,
      positioning: positioningData,
      competitive: competitiveData,
      radar: radarData,
      brands
    }
  }, [brandData, selectedBrand])

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-96">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-scout-primary"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-4">
        <h3 className="text-red-800 font-medium">Error Loading Brand Analytics</h3>
        <p className="text-red-600 text-sm mt-1">
          {error instanceof Error ? error.message : 'Unknown error occurred'}
        </p>
      </div>
    )
  }

  const topPerformers = processedData?.brands
    ?.sort((a, b) => (b.consumer_reach_points || 0) - (a.consumer_reach_points || 0))
    ?.slice(0, 5) || []

  const fastestGrowing = processedData?.brands
    ?.filter(b => b.brand_growth_yoy !== undefined)
    ?.sort((a, b) => (b.brand_growth_yoy || 0) - (a.brand_growth_yoy || 0))
    ?.slice(0, 5) || []

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Brand Analytics</h1>
            <p className="text-gray-600 mt-1">
              Market positioning, competitive intelligence, and brand performance insights
            </p>
          </div>

          <div className="flex items-center space-x-4 mt-4 sm:mt-0">
            <select
              value={filters.categories?.[0] || ''}
              onChange={(e) => setFilters({
                ...filters,
                categories: e.target.value ? [e.target.value] : undefined
              })}
              className="px-3 py-2 border border-gray-300 rounded-md text-sm"
            >
              <option value="">All Categories</option>
              <option value="Beverages">Beverages</option>
              <option value="Snacks">Snacks</option>
              <option value="Personal Care">Personal Care</option>
              <option value="Household">Household</option>
            </select>
          </div>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <MetricCard
          title="Total Brands"
          value={processedData?.brands?.length?.toString() || '0'}
          subtitle="Active brands tracked"
          icon={<Award className="w-5 h-5" />}
          color="bg-blue-50 text-blue-600"
        />

        <MetricCard
          title="Market Leaders"
          value={processedData?.brands?.filter(b => b.position_type === 'leader')?.length?.toString() || '0'}
          subtitle="Leading market position"
          icon={<Target className="w-5 h-5" />}
          color="bg-green-50 text-green-600"
        />

        <MetricCard
          title="Avg. Market Share"
          value={`${Math.round(
            (processedData?.brands?.reduce((sum, b) => sum + (b.market_share_percent || 0), 0) || 0) /
            Math.max(processedData?.brands?.length || 1, 1)
          )}%`}
          subtitle="Average across all brands"
          icon={<DollarSign className="w-5 h-5" />}
          color="bg-yellow-50 text-yellow-600"
        />

        <MetricCard
          title="High Growth"
          value={processedData?.brands?.filter(b => b.growth_status === 'High Growth')?.length?.toString() || '0'}
          subtitle="Fast-growing brands"
          icon={<TrendingUp className="w-5 h-5" />}
          color="bg-purple-50 text-purple-600"
        />
      </div>

      {/* View Mode Selector */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="flex space-x-4">
          {[
            { key: 'performance', label: 'Performance Overview' },
            { key: 'competitive', label: 'Competitive Analysis' },
            { key: 'pricing', label: 'Pricing Intelligence' }
          ].map(view => (
            <button
              key={view.key}
              onClick={() => setViewMode(view.key as any)}
              className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                viewMode === view.key
                  ? 'bg-scout-primary text-white'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              {view.label}
            </button>
          ))}
        </div>
      </div>

      {/* Charts based on view mode */}
      {processedData && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {viewMode === 'performance' && (
            <>
              {/* Brand Tier Distribution */}
              <ChartCard title="Brand Tier Distribution" subtitle="Brands by performance tier">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={processedData.tiers}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis
                      dataKey="tier"
                      angle={-45}
                      textAnchor="end"
                      height={100}
                      interval={0}
                      fontSize={12}
                    />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="count" fill="#0066CC" name="Brand Count" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>

              {/* Top Performers */}
              <ChartCard title="Top Brand Performance" subtitle="By Consumer Reach Points (CRP)">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={topPerformers}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis
                      dataKey="brand_name"
                      angle={-45}
                      textAnchor="end"
                      height={100}
                      interval={0}
                      fontSize={12}
                    />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="consumer_reach_points" fill="#4ECDC4" name="CRP" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>
            </>
          )}

          {viewMode === 'competitive' && (
            <>
              {/* Market Positioning Matrix */}
              <ChartCard title="Market Positioning Matrix" subtitle="Price vs Market Share">
                <ResponsiveContainer width="100%" height={300}>
                  <ScatterChart data={processedData.positioning}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis
                      dataKey="market_share"
                      name="Market Share (%)"
                      domain={['dataMin', 'dataMax']}
                    />
                    <YAxis
                      dataKey="price_index"
                      name="Price Index (%)"
                      domain={['dataMin', 'dataMax']}
                    />
                    <Tooltip
                      formatter={(value, name) => [
                        `${Number(value).toFixed(1)}${name === 'Price Index (%)' ? '%' : '%'}`,
                        name
                      ]}
                      labelFormatter={(label) => `Brand: ${label}`}
                    />
                    <Scatter
                      dataKey="price_index"
                      fill="#FF6B35"
                      name="Brands"
                    />
                  </ScatterChart>
                </ResponsiveContainer>
              </ChartCard>

              {/* Growth Analysis */}
              <ChartCard title="Fastest Growing Brands" subtitle="Year-over-year growth rate">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={fastestGrowing}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis
                      dataKey="brand_name"
                      angle={-45}
                      textAnchor="end"
                      height={100}
                      interval={0}
                      fontSize={12}
                    />
                    <YAxis />
                    <Tooltip formatter={(value) => [`${Number(value).toFixed(1)}%`, 'Growth Rate']} />
                    <Bar dataKey="brand_growth_yoy" fill="#96CEB4" name="YoY Growth %" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>
            </>
          )}

          {viewMode === 'pricing' && (
            <>
              {/* Price vs Market Share */}
              <ChartCard title="Price vs Market Share" subtitle="Pricing strategy analysis">
                <ResponsiveContainer width="100%" height={300}>
                  <ScatterChart data={processedData.competitive}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis
                      dataKey="market_share"
                      name="Market Share (%)"
                    />
                    <YAxis
                      dataKey="avg_price"
                      name="Avg Price (₱)"
                    />
                    <Tooltip
                      formatter={(value, name) => [
                        name === 'Avg Price (₱)' ? `₱${Number(value).toFixed(2)}` : `${Number(value).toFixed(1)}%`,
                        name
                      ]}
                    />
                    <Scatter dataKey="avg_price" fill="#45B7D1" />
                  </ScatterChart>
                </ResponsiveContainer>
              </ChartCard>

              {/* Value Proposition Distribution */}
              <ChartCard title="Value Proposition Distribution" subtitle="Brands by pricing strategy">
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart
                    data={[
                      {
                        proposition: 'Premium',
                        count: processedData.brands.filter(b => b.value_proposition === 'Premium').length
                      },
                      {
                        proposition: 'Mainstream',
                        count: processedData.brands.filter(b => b.value_proposition === 'Mainstream').length
                      },
                      {
                        proposition: 'Value',
                        count: processedData.brands.filter(b => b.value_proposition === 'Value').length
                      }
                    ]}
                  >
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="proposition" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="count" fill="#FFEAA7" name="Brand Count" />
                  </BarChart>
                </ResponsiveContainer>
              </ChartCard>
            </>
          )}
        </div>
      )}

      {/* Brand Selector for Detailed Analysis */}
      {processedData && (
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Brand Deep Dive</h3>

          <div className="mb-4">
            <select
              value={selectedBrand || ''}
              onChange={(e) => setSelectedBrand(e.target.value || null)}
              className="px-3 py-2 border border-gray-300 rounded-md text-sm"
            >
              <option value="">Select a brand for detailed analysis</option>
              {processedData.brands.map(brand => (
                <option key={brand.brand_name} value={brand.brand_name}>
                  {brand.brand_name}
                </option>
              ))}
            </select>
          </div>

          {selectedBrand && processedData.radar.length > 0 && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Brand Health Radar */}
              <div>
                <h4 className="text-md font-medium text-gray-900 mb-4">Brand Health Score</h4>
                <ResponsiveContainer width="100%" height={300}>
                  <RadarChart data={processedData.radar}>
                    <PolarGrid />
                    <PolarAngleAxis dataKey="metric" fontSize={12} />
                    <PolarRadiusAxis
                      angle={90}
                      domain={[0, 100]}
                      fontSize={10}
                    />
                    <Radar
                      name={selectedBrand}
                      dataKey="value"
                      stroke="#0066CC"
                      fill="#0066CC"
                      fillOpacity={0.2}
                      strokeWidth={2}
                    />
                    <Tooltip />
                  </RadarChart>
                </ResponsiveContainer>
              </div>

              {/* Brand Details */}
              <div>
                <h4 className="text-md font-medium text-gray-900 mb-4">Brand Details</h4>
                {(() => {
                  const brand = processedData.brands.find(b => b.brand_name === selectedBrand)
                  if (!brand) return null

                  return (
                    <div className="space-y-3">
                      <DetailRow label="Market Share" value={`${brand.market_share_percent?.toFixed(1) || 0}%`} />
                      <DetailRow label="Consumer Reach Points" value={brand.consumer_reach_points?.toLocaleString() || '0'} />
                      <DetailRow label="Average Price" value={`₱${brand.avg_price_php?.toFixed(2) || '0'}`} />
                      <DetailRow label="Brand Tier" value={brand.brand_tier || 'Unknown'} />
                      <DetailRow label="Value Proposition" value={brand.value_proposition || 'Unknown'} />
                      <DetailRow label="Growth Status" value={brand.growth_status || 'Unknown'} />
                      <DetailRow label="Competitive Status" value={brand.position_type || 'Unknown'} />
                      <DetailRow label="Channels Available" value={brand.channels_available?.toString() || '0'} />
                    </div>
                  )
                })()}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// Metric Card Component
interface MetricCardProps {
  title: string
  value: string
  subtitle: string
  icon: React.ReactNode
  color: string
}

const MetricCard: React.FC<MetricCardProps> = ({ title, value, subtitle, icon, color }) => (
  <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm font-medium text-gray-600">{title}</p>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
        <p className="text-xs text-gray-500 mt-1">{subtitle}</p>
      </div>

      <div className={`p-3 rounded-lg ${color}`}>
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

// Detail Row Component
interface DetailRowProps {
  label: string
  value: string
}

const DetailRow: React.FC<DetailRowProps> = ({ label, value }) => (
  <div className="flex justify-between items-center py-2 border-b border-gray-100 last:border-b-0">
    <span className="text-sm text-gray-600">{label}</span>
    <span className="text-sm font-medium text-gray-900">{value}</span>
  </div>
)

export default BrandAnalytics