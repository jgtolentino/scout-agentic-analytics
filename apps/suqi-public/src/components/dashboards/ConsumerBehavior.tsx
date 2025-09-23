'use client'

import React, { useState, useEffect } from 'react'
// import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import { TrendingUp, TrendingDown, Users, MessageCircle, HandHeart, Eye, ChevronUp, ChevronDown } from 'lucide-react'

// Define types for the data structures
interface KPI {
  value: number
  change: number
  trend: 'up' | 'down' | 'stable'
}

interface PurchaseFunnelStage {
  name: string
  count: number
  percentage: number
  drop_rate: number
}

interface RequestMethod {
  method: string
  count: number
  percentage: number
}

interface BehaviorData {
  purchase_funnel: {
    stages: PurchaseFunnelStage[]
    conversion_points: {
      browse_to_request: number
      request_to_suggestion: number
      suggestion_to_purchase: number
      overall_conversion: number
    }
  }
  request_methods: RequestMethod[]
  insights: {
    key_insights: string[]
    ai_recommendations: string[]
  }
}

interface KPIData {
  conversion_rate: KPI
  suggestion_accept_rate: KPI
  brand_loyalty_rate: KPI
  discovery_rate: KPI
}

const ConsumerBehaviorAnalytics: React.FC = () => {
  const [behaviorData, setBehaviorData] = useState<BehaviorData | null>(null)
  const [kpiData, setKpiData] = useState<KPIData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Colors for charts matching TBWA brand
  const COLORS = ['#FF6B35', '#F7931E', '#FFD700', '#32CD32', '#1E90FF', '#9370DB']

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)

        // Fetch behavior data and KPIs in parallel
        const [behaviorResponse, kpiResponse] = await Promise.all([
          fetch('/api/scout/behavior'),
          fetch('/api/scout/kpis')
        ])

        if (!behaviorResponse.ok || !kpiResponse.ok) {
          throw new Error('Failed to fetch data')
        }

        const behaviorResult = await behaviorResponse.json()
        const kpiResult = await kpiResponse.json()

        if (behaviorResult.success) {
          setBehaviorData(behaviorResult.data)
        }

        if (kpiResult.success) {
          setKpiData(kpiResult.data.kpis)
        }

      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error')
        console.error('Error fetching consumer behavior data:', err)
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [])

  // KPI Card Component
  const KPICard: React.FC<{ title: string; data: KPI; icon: React.ReactNode; format?: string }> = ({
    title,
    data,
    icon,
    format = 'percentage'
  }) => (
    <div className="bg-white p-6 rounded-lg shadow-lg border border-gray-200 hover:shadow-xl transition-shadow">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center space-x-3">
          <div className="p-2 bg-blue-100 rounded-lg">{icon}</div>
          <h3 className="text-sm font-medium text-gray-600">{title}</h3>
        </div>
        <div className={`flex items-center text-sm ${
          data.trend === 'up' ? 'text-green-600' :
          data.trend === 'down' ? 'text-red-600' : 'text-gray-600'
        }`}>
          {data.trend === 'up' ? <ChevronUp className="w-4 h-4" /> :
           data.trend === 'down' ? <ChevronDown className="w-4 h-4" /> : null}
          <span>{Math.abs(data.change)}%</span>
        </div>
      </div>
      <div className="text-3xl font-bold text-gray-900 mb-1">
        {format === 'percentage' ? `${data.value.toFixed(1)}%` : data.value.toLocaleString()}
      </div>
    </div>
  )

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-6">
        <h3 className="text-red-800 font-semibold">Error Loading Data</h3>
        <p className="text-red-600 mt-2">{error}</p>
      </div>
    )
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="border-b border-gray-200 pb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Consumer Behavior Analytics</h1>
        <p className="text-gray-600">Purchase decisions, patterns & customer journey analysis</p>
      </div>

      {/* KPI Cards */}
      {kpiData && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <KPICard
            title="Conversion Rate"
            data={kpiData.conversion_rate}
            icon={<TrendingUp className="w-5 h-5 text-blue-600" />}
          />
          <KPICard
            title="Suggestion Accept"
            data={kpiData.suggestion_accept_rate}
            icon={<HandHeart className="w-5 h-5 text-green-600" />}
          />
          <KPICard
            title="Brand Loyalty"
            data={kpiData.brand_loyalty_rate}
            icon={<Users className="w-5 h-5 text-purple-600" />}
          />
          <KPICard
            title="Discovery Rate"
            data={kpiData.discovery_rate}
            icon={<Eye className="w-5 h-5 text-orange-600" />}
          />
        </div>
      )}

      {/* Main Analytics Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">

        {/* Purchase Funnel */}
        {behaviorData?.purchase_funnel && (
          <div className="bg-white p-6 rounded-lg shadow-lg border border-gray-200">
            <h2 className="text-xl font-bold text-gray-900 mb-6">Customer Purchase Journey</h2>

            <div className="space-y-4">
              {behaviorData.purchase_funnel.stages.map((stage, index) => (
                <div key={stage.name} className="relative">
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium text-gray-700">{stage.name}</span>
                    <span className="text-sm text-gray-500">{stage.count.toLocaleString()}</span>
                  </div>

                  <div className="relative">
                    <div className="w-full bg-gray-200 rounded-full h-8">
                      <div
                        className="bg-gradient-to-r from-blue-500 to-blue-600 h-8 rounded-full flex items-center justify-end pr-4"
                        style={{ width: `${stage.percentage}%` }}
                      >
                        <span className="text-white text-sm font-medium">
                          {stage.percentage}%
                        </span>
                      </div>
                    </div>

                    {index < behaviorData.purchase_funnel.stages.length - 1 && (
                      <div className="absolute -bottom-3 left-0 text-xs text-red-500">
                        {stage.drop_rate}% drop
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>

            {/* Conversion Points */}
            <div className="mt-6 p-4 bg-gray-50 rounded-lg">
              <h3 className="font-semibold text-gray-700 mb-3">Key Conversion Points</h3>
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-600">Browse → Request:</span>
                  <span className="ml-2 font-medium">{behaviorData.purchase_funnel.conversion_points.browse_to_request}%</span>
                </div>
                <div>
                  <span className="text-gray-600">Request → Suggestion:</span>
                  <span className="ml-2 font-medium">{behaviorData.purchase_funnel.conversion_points.request_to_suggestion}%</span>
                </div>
                <div>
                  <span className="text-gray-600">Suggestion → Purchase:</span>
                  <span className="ml-2 font-medium">{behaviorData.purchase_funnel.conversion_points.suggestion_to_purchase}%</span>
                </div>
                <div>
                  <span className="text-gray-600">Overall Conversion:</span>
                  <span className="ml-2 font-medium text-blue-600">{behaviorData.purchase_funnel.conversion_points.overall_conversion}%</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Request Methods */}
        {behaviorData?.request_methods && (
          <div className="bg-white p-6 rounded-lg shadow-lg border border-gray-200">
            <h2 className="text-xl font-bold text-gray-900 mb-6">Request Methods</h2>

            <div className="h-64 flex items-end space-x-4 p-4 bg-gray-50 rounded-lg">
              {behaviorData.request_methods.map((method, index) => (
                <div key={method.method} className="flex-1 flex flex-col items-center">
                  <div className="text-sm font-medium mb-2">{method.count?.toLocaleString() || 0}</div>
                  <div
                    className="bg-blue-500 w-full rounded-t"
                    style={{
                      height: `${Math.max((method.percentage || 0) * 2, 20)}px`,
                      minHeight: '20px'
                    }}
                  ></div>
                  <div className="text-xs text-gray-600 mt-2 text-center">
                    <div className="font-medium">{method.method}</div>
                    <div>{method.percentage?.toFixed(1) || 0}%</div>
                  </div>
                </div>
              ))}
            </div>

            {/* Method Breakdown */}
            <div className="mt-4 space-y-2">
              {behaviorData.request_methods.map((method, index) => (
                <div key={method.method} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                  <div className="flex items-center space-x-2">
                    <div
                      className="w-3 h-3 rounded-full bg-blue-500"
                    ></div>
                    <span className="font-medium">{method.method}</span>
                  </div>
                  <div className="text-right">
                    <div className="font-semibold">{method.count?.toLocaleString() || 0}</div>
                    <div className="text-sm text-gray-500">{method.percentage?.toFixed(1) || 0}%</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Behavioral Insights */}
      {behaviorData?.insights && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">

          {/* Key Insights */}
          <div className="bg-white p-6 rounded-lg shadow-lg border border-gray-200">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Key Insights</h2>
            <div className="space-y-3">
              {behaviorData.insights.key_insights.map((insight, index) => (
                <div key={index} className="flex items-start space-x-3 p-3 bg-blue-50 rounded-lg">
                  <div className="text-blue-600 text-lg">{insight.charAt(0)}</div>
                  <p className="text-gray-700 flex-1">{insight.slice(2)}</p>
                </div>
              ))}
            </div>
          </div>

          {/* AI Recommendations */}
          <div className="bg-white p-6 rounded-lg shadow-lg border border-gray-200">
            <h2 className="text-xl font-bold text-gray-900 mb-4">AI Recommendations</h2>
            <div className="space-y-3">
              {behaviorData.insights.ai_recommendations.map((recommendation, index) => (
                <div key={index} className="flex items-start space-x-3 p-3 bg-green-50 rounded-lg">
                  <div className="text-green-600 font-bold">→</div>
                  <p className="text-gray-700 flex-1">{recommendation}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Ask Suqi Section */}
      <div className="bg-gradient-to-r from-blue-500 to-purple-600 p-6 rounded-lg text-white">
        <div className="flex items-center space-x-3 mb-4">
          <MessageCircle className="w-6 h-6" />
          <h2 className="text-xl font-bold">Ask Suqi about this data...</h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <button className="bg-white/20 hover:bg-white/30 p-3 rounded-lg text-left transition-colors">
            <div className="font-medium">What are the peak hours?</div>
          </button>
          <button className="bg-white/20 hover:bg-white/30 p-3 rounded-lg text-left transition-colors">
            <div className="font-medium">Which products sell best?</div>
          </button>
          <button className="bg-white/20 hover:bg-white/30 p-3 rounded-lg text-left transition-colors">
            <div className="font-medium">Customer behavior insights</div>
          </button>
          <button className="bg-white/20 hover:bg-white/30 p-3 rounded-lg text-left transition-colors">
            <div className="font-medium">Revenue optimization tips</div>
          </button>
        </div>
      </div>
    </div>
  )
}

export default ConsumerBehaviorAnalytics