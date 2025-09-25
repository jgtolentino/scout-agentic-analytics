import { Suspense } from 'react';
import { AnalyticsDashboard } from '@/components/AnalyticsDashboard';

export default function DashboardPage() {
  return (
    <main className="min-h-screen bg-gray-50">
      <div className="container mx-auto px-4 py-8">
        <header className="mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-2">
            Scout v7 Analytics Platform
          </h1>
          <p className="text-lg text-gray-600">
            Retail Intelligence Platform - Demographics, Brand Detection, Market Analysis
          </p>
        </header>

        <Suspense fallback={
          <div className="flex items-center justify-center h-64">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
          </div>
        }>
          <AnalyticsDashboard />
        </Suspense>
      </div>
    </main>
  );
}