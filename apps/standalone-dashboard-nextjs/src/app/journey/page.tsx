'use client';

import { useState } from 'react';
import { CohortRetention, BrandSankey, JourneyFunnel } from '../../components/charts';

export default function JourneyAnalyticsPage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'cohorts' | 'switching' | 'funnel'>('overview');

  const tabs = [
    { id: 'overview', name: 'Overview', description: 'Complete journey analysis' },
    { id: 'cohorts', name: 'Cohort Retention', description: 'Brand adoption & retention' },
    { id: 'switching', name: 'Brand Switching', description: 'Migration patterns' },
    { id: 'funnel', name: 'Journey Funnel', description: 'Conversion analysis' }
  ];

  const handleCohortClick = (cohort: string, period: string, retention: number) => {
    console.log('Cohort clicked:', { cohort, period, retention });
    // Could navigate to detailed cohort analysis
  };

  const handleSwitchingClick = (source: string, target: string, value: number) => {
    console.log('Switching flow clicked:', { source, target, value });
    // Could filter to show specific brand switching
  };

  const handleJourneyStepClick = (step: string, count: number, percentage: number) => {
    console.log('Journey step clicked:', { step, count, percentage });
    // Could drill down to step-specific analysis
  };

  const handleJourneyPathClick = (path: string[], conversionRate: number) => {
    console.log('Journey path clicked:', { path, conversionRate });
    // Could analyze specific customer paths
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Journey Analytics</h1>
              <p className="mt-2 text-gray-600">
                Competitive customer journey intelligence for retail optimization
              </p>
            </div>
            
            {/* Quick Actions */}
            <div className="flex space-x-3">
              <button className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Export Report
              </button>
              <button className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z" />
                </svg>
                Share Analysis
              </button>
            </div>
          </div>
        </div>

        {/* Global Filter Bar */}
        <div className="mb-8">
        </div>

        {/* Tab Navigation */}
        <div className="mb-8">
          <nav className="flex space-x-8" aria-label="Journey Analytics Tabs">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === tab.id
                    ? 'border-indigo-500 text-indigo-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-200'
                }`}
              >
                <span>{tab.name}</span>
                <span className={`ml-2 py-0.5 px-2.5 rounded-full text-xs font-medium ${
                  activeTab === tab.id
                    ? 'bg-indigo-100 text-indigo-600'
                    : 'bg-gray-100 text-gray-400 group-hover:text-gray-600'
                }`}>
                  {tab.description}
                </span>
              </button>
            ))}
          </nav>
        </div>

        {/* Content Area */}
        <div className="space-y-8">
          {/* Overview Tab */}
          {activeTab === 'overview' && (
            <div className="space-y-8">
              {/* Key Metrics Row */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white overflow-hidden shadow rounded-lg">
                  <div className="p-5">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <div className="w-8 h-8 bg-indigo-600 rounded-md flex items-center justify-center">
                          <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                          </svg>
                        </div>
                      </div>
                      <div className="ml-5 w-0 flex-1">
                        <dl>
                          <dt className="text-sm font-medium text-gray-500 truncate">Overall Conversion Rate</dt>
                          <dd className="text-lg font-medium text-gray-900">62.4%</dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="bg-white overflow-hidden shadow rounded-lg">
                  <div className="p-5">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <div className="w-8 h-8 bg-green-600 rounded-md flex items-center justify-center">
                          <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clipRule="evenodd" />
                          </svg>
                        </div>
                      </div>
                      <div className="ml-5 w-0 flex-1">
                        <dl>
                          <dt className="text-sm font-medium text-gray-500 truncate">Brand Retention Rate</dt>
                          <dd className="text-lg font-medium text-gray-900">78.5%</dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="bg-white overflow-hidden shadow rounded-lg">
                  <div className="p-5">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <div className="w-8 h-8 bg-purple-600 rounded-md flex items-center justify-center">
                          <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M2 10a8 8 0 018-8v8h8a8 8 0 11-16 0z" />
                            <path d="M12 2.252A8.014 8.014 0 0117.748 8H12V2.252z" />
                          </svg>
                        </div>
                      </div>
                      <div className="ml-5 w-0 flex-1">
                        <dl>
                          <dt className="text-sm font-medium text-gray-500 truncate">Average Journey Time</dt>
                          <dd className="text-lg font-medium text-gray-900">12.5 min</dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Main Analytics Grid */}
              <div className="grid grid-cols-1 xl:grid-cols-2 gap-8">
                <CohortRetention 
                  height={400}
                  onCellClick={handleCohortClick}
                />
                <BrandSankey 
                  height={400}
                  width={600}
                  onNodeClick={(brandId, value) => console.log('Node:', brandId, value)}
                  onLinkClick={handleSwitchingClick}
                />
              </div>

              {/* Journey Funnel - Full Width */}
              <div>
                <JourneyFunnel
                  height={600}
                  onStepClick={handleJourneyStepClick}
                  onPathClick={handleJourneyPathClick}
                />
              </div>
            </div>
          )}

          {/* Cohort Retention Tab */}
          {activeTab === 'cohorts' && (
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-6">
                <div className="mb-4">
                  <h2 className="text-xl font-semibold text-gray-900">Brand Cohort Analysis</h2>
                  <p className="text-gray-600">Track customer retention by brand acquisition cohort over time</p>
                </div>
                <CohortRetention 
                  height={500}
                  showMetadata={true}
                  onCellClick={handleCohortClick}
                />
              </div>
            </div>
          )}

          {/* Brand Switching Tab */}
          {activeTab === 'switching' && (
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-6">
                <div className="mb-4">
                  <h2 className="text-xl font-semibold text-gray-900">Brand Switching Analysis</h2>
                  <p className="text-gray-600">Customer migration patterns and brand loyalty insights</p>
                </div>
                <BrandSankey 
                  height={600}
                  width={900}
                  showMetadata={true}
                  onNodeClick={(brandId, value) => console.log('Brand focus:', brandId, value)}
                  onLinkClick={handleSwitchingClick}
                />
              </div>
            </div>
          )}

          {/* Journey Funnel Tab */}
          {activeTab === 'funnel' && (
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-6">
                <div className="mb-4">
                  <h2 className="text-xl font-semibold text-gray-900">Customer Journey Funnel</h2>
                  <p className="text-gray-600">Analyze conversion rates and drop-off points across the customer journey</p>
                </div>
                <JourneyFunnel
                  height={700}
                  showPathAnalysis={true}
                  onStepClick={handleJourneyStepClick}
                  onPathClick={handleJourneyPathClick}
                />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}