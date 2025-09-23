'use client'

import React from 'react'
import { Users, UserCheck, Target, Brain } from 'lucide-react'

const ConsumerProfiling: React.FC = () => {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="border-b border-gray-200 pb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Consumer Profiling</h1>
        <p className="text-gray-600">Customer segmentation and demographic insights</p>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-orange-50 border border-orange-200 rounded-lg p-8 text-center">
        <Users className="w-16 h-16 text-orange-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-orange-900 mb-2">Coming Soon</h2>
        <p className="text-orange-700 mb-4">
          Comprehensive consumer profiling with demographic segmentation, purchasing patterns, and AI-powered customer personas.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
          <div className="bg-white p-4 rounded-lg border border-orange-200">
            <UserCheck className="w-8 h-8 text-orange-600 mb-2" />
            <h3 className="font-semibold text-orange-900">Customer Segments</h3>
            <p className="text-sm text-orange-700">Automated segmentation analysis</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-orange-200">
            <Target className="w-8 h-8 text-orange-600 mb-2" />
            <h3 className="font-semibold text-orange-900">Demographics</h3>
            <p className="text-sm text-orange-700">Age, gender, economic profiling</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-orange-200">
            <Brain className="w-8 h-8 text-orange-600 mb-2" />
            <h3 className="font-semibold text-orange-900">Behavioral Patterns</h3>
            <p className="text-sm text-orange-700">Purchase behavior analysis</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-orange-200">
            <Users className="w-8 h-8 text-orange-600 mb-2" />
            <h3 className="font-semibold text-orange-900">Persona Building</h3>
            <p className="text-sm text-orange-700">AI-generated customer personas</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default ConsumerProfiling