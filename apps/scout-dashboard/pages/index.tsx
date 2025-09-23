import React from 'react'
import Head from 'next/head'
import { TransactionDashboard } from '../components/scout/TransactionDashboard'
import AuthGuard from '../components/auth/AuthGuard'

// Scout v7 Dashboard Home Page
const HomePage: React.FC = () => {
  return (
    <AuthGuard requiredPermissions={['scout_read']}>
      <Head>
        <title>Scout v7 Analytics Dashboard</title>
        <meta name="description" content="Real-time analytics and insights for Scout v7 platform" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <div className="min-h-screen bg-gray-50">
        {/* Navigation Header */}
        <header className="bg-white shadow-sm border-b border-gray-200">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center h-16">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <h1 className="text-xl font-bold text-scout-primary">Scout v7</h1>
                </div>
                <nav className="hidden md:ml-8 md:flex md:space-x-8">
                  <a
                    href="/"
                    className="text-gray-900 hover:text-scout-primary px-3 py-2 rounded-md text-sm font-medium"
                  >
                    Overview
                  </a>
                  <a
                    href="/brands"
                    className="text-gray-500 hover:text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                  >
                    Brand Analytics
                  </a>
                  <a
                    href="/stores"
                    className="text-gray-500 hover:text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                  >
                    Store Performance
                  </a>
                  <a
                    href="/insights"
                    className="text-gray-500 hover:text-gray-700 px-3 py-2 rounded-md text-sm font-medium"
                  >
                    AI Insights
                  </a>
                </nav>
              </div>

              <div className="flex items-center space-x-4">
                <div className="text-sm text-gray-500">
                  {new Date().toLocaleDateString('en-PH', {
                    weekday: 'short',
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                  })}
                </div>

                <div className="flex items-center space-x-2">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <span className="text-xs text-gray-600">Live</span>
                </div>
              </div>
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <TransactionDashboard />
        </main>

        {/* Footer */}
        <footer className="bg-white border-t border-gray-200 mt-16">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
            <div className="flex flex-col md:flex-row justify-between items-center">
              <div className="flex items-center space-x-4">
                <div className="text-sm text-gray-500">
                  © 2025 TBWA Data Intelligence Team
                </div>
                <div className="text-sm text-gray-400">|</div>
                <div className="text-sm text-gray-500">
                  Scout v7 Analytics Platform
                </div>
              </div>

              <div className="flex items-center space-x-6 mt-4 md:mt-0">
                <a
                  href="/api/scout/transactions"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-sm text-gray-500 hover:text-gray-700"
                >
                  API Documentation
                </a>
                <a
                  href="https://github.com/tbwa/scout-v7"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-sm text-gray-500 hover:text-gray-700"
                >
                  GitHub
                </a>
                <div className="text-sm text-gray-400">
                  v1.0.0
                </div>
              </div>
            </div>
          </div>
        </footer>
      </div>
    </AuthGuard>
  )
}

export default HomePage