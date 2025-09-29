'use client'

import React from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TransactionDashboard } from './scout/TransactionDashboard'
import { BrandAnalytics } from './scout/BrandAnalytics'

// Create a client instance
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: 1,
    },
  },
})

export const AnalyticsDashboard: React.FC = () => {
  return (
    <QueryClientProvider client={queryClient}>
      <div className="space-y-8">
        {/* Main Transaction Dashboard */}
        <section>
          <TransactionDashboard />
        </section>

        {/* Brand Analytics Section */}
        <section>
          <BrandAnalytics />
        </section>
      </div>
    </QueryClientProvider>
  )
}