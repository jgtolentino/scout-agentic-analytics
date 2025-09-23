'use client'

import React from 'react'
import { TrendingUp, Users, BarChart3, Target } from 'lucide-react'

const CompetitiveAnalysis: React.FC = () => {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="border-b border-gray-200 pb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Competitive Analysis</h1>
        <p className="text-gray-600">Market positioning and competitive intelligence</p>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-8 text-center">
        <BarChart3 className="w-16 h-16 text-blue-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-blue-900 mb-2">Coming Soon</h2>
        <p className="text-blue-700 mb-4">
          Advanced competitive analysis dashboard with market share insights, competitor performance tracking, and strategic positioning analytics.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
          <div className="bg-white p-4 rounded-lg border border-blue-200">
            <Target className="w-8 h-8 text-blue-600 mb-2" />
            <h3 className="font-semibold text-blue-900">Market Share</h3>
            <p className="text-sm text-blue-700">Track competitor market positions</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-blue-200">
            <TrendingUp className="w-8 h-8 text-blue-600 mb-2" />
            <h3 className="font-semibold text-blue-900">Performance Metrics</h3>
            <p className="text-sm text-blue-700">Compare key performance indicators</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-blue-200">
            <Users className="w-8 h-8 text-blue-600 mb-2" />
            <h3 className="font-semibold text-blue-900">Customer Overlap</h3>
            <p className="text-sm text-blue-700">Analyze shared customer segments</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-blue-200">
            <BarChart3 className="w-8 h-8 text-blue-600 mb-2" />
            <h3 className="font-semibold text-blue-900">Strategic Insights</h3>
            <p className="text-sm text-blue-700">AI-powered competitive intelligence</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default CompetitiveAnalysis