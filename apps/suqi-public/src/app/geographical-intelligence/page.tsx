'use client'

import React from 'react'
import { MapPin, Globe, Navigation, Zap } from 'lucide-react'

const GeographicalIntelligence: React.FC = () => {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="border-b border-gray-200 pb-6">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Geographical Intelligence</h1>
        <p className="text-gray-600">Location-based analytics and regional insights</p>
      </div>

      {/* Coming Soon Message */}
      <div className="bg-green-50 border border-green-200 rounded-lg p-8 text-center">
        <MapPin className="w-16 h-16 text-green-600 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-green-900 mb-2">Coming Soon</h2>
        <p className="text-green-700 mb-4">
          Advanced geographical analytics with regional performance mapping, location-based customer insights, and territorial expansion planning.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
          <div className="bg-white p-4 rounded-lg border border-green-200">
            <Globe className="w-8 h-8 text-green-600 mb-2" />
            <h3 className="font-semibold text-green-900">Regional Mapping</h3>
            <p className="text-sm text-green-700">Interactive performance heatmaps</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-green-200">
            <Navigation className="w-8 h-8 text-green-600 mb-2" />
            <h3 className="font-semibold text-green-900">Location Analytics</h3>
            <p className="text-sm text-green-700">Store performance by location</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-green-200">
            <Zap className="w-8 h-8 text-green-600 mb-2" />
            <h3 className="font-semibold text-green-900">Territory Insights</h3>
            <p className="text-sm text-green-700">Expansion opportunity analysis</p>
          </div>
          <div className="bg-white p-4 rounded-lg border border-green-200">
            <MapPin className="w-8 h-8 text-green-600 mb-2" />
            <h3 className="font-semibold text-green-900">Demographics</h3>
            <p className="text-sm text-green-700">Regional customer profiling</p>
          </div>
        </div>
      </div>
    </div>
  )
}

export default GeographicalIntelligence