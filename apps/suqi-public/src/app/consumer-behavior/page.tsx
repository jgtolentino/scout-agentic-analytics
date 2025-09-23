'use client'

import React from 'react'
import Navigation from '../../components/ui/Navigation'
import ConsumerBehaviorAnalytics from '../../components/dashboards/ConsumerBehavior'

export default function ConsumerBehaviorPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />

      {/* Main content */}
      <div className="lg:pl-64">
        <main className="p-6">
          <ConsumerBehaviorAnalytics />
        </main>
      </div>
    </div>
  )
}