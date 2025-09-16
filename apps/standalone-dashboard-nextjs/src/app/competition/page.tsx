'use client';

import { useState } from 'react';
import { CohortRetention, BrandSankey, JourneyFunnel } from '../../components/charts';
import { competitiveAPI } from '../../lib/api/competitive';

export default function CompetitionPage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'cohorts' | 'switching' | 'benchmarks'>('overview');

  const tabs = [
    { id: 'overview', name: 'Overview', description: 'Comprehensive competitive intelligence' },
    { id: 'cohorts', name: 'Brand Cohorts', description: 'Customer acquisition & retention' },
    { id: 'switching', name: 'Brand Migration', description: 'Customer switching patterns' },
    { id: 'benchmarks', name: 'Benchmarks', description: 'Performance comparisons' }
  ];

  const handleCohortClick = (cohort: string, period: string, retention: number) => {
    console.log('Cohort clicked:', { cohort, period, retention });
  };

  const handleSwitchingClick = (source: string, target: string, value: number) => {
    console.log('Switching flow clicked:', { source, target, value });
  };

  const handleBenchmarkDrilldown = async (metric: string, brands: string[]) => {
    console.log('Benchmark drilldown:', { metric, brands });
    // Could load detailed comparison data
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Competitive Intelligence</h1>
              <p className="mt-2 text-gray-600">
                Brand performance analysis and competitive benchmarking for retail optimization
              </p>
            </div>
            
            {/* Quick Actions */}
            <div className="flex space-x-3">
              <button className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Export Analysis
              </button>
              <button className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z" />
                </svg>
                Share Report
              </button>
            </div>
          </div>
        </div>


        {/* Tab Navigation */}
        <div className="mb-8">
          <nav className="flex space-x-8" aria-label="Competitive Analysis Tabs">
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
              <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
                <div className="bg-white overflow-hidden shadow rounded-lg">
                  <div className="p-5">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <div className="w-8 h-8 bg-blue-600 rounded-md flex items-center justify-center">
                          <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M3 3a1 1 0 000 2v8a2 2 0 002 2h2.586l-1.293 1.293a1 1 0 101.414 1.414L10 15.414l2.293 2.293a1 1 0 001.414-1.414L12.414 15H15a2 2 0 002-2V5a1 1 0 100-2H3zm11.707 4.707a1 1 0 00-1.414-1.414L10 9.586 8.707 8.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                          </svg>
                        </div>
                      </div>
                      <div className="ml-5 w-0 flex-1">
                        <dl>
                          <dt className="text-sm font-medium text-gray-500 truncate">Market Share</dt>
                          <dd className="text-lg font-medium text-gray-900">22.9%</dd>
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
                          <dt className="text-sm font-medium text-gray-500 truncate">Brand Retention</dt>
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
                            <path fillRule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clipRule="evenodd" />
                          </svg>
                        </div>
                      </div>
                      <div className="ml-5 w-0 flex-1">
                        <dl>
                          <dt className="text-sm font-medium text-gray-500 truncate">Switching Rate</dt>
                          <dd className="text-lg font-medium text-gray-900">12.3%</dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="bg-white overflow-hidden shadow rounded-lg">
                  <div className="p-5">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        <div className="w-8 h-8 bg-orange-600 rounded-md flex items-center justify-center">
                          <svg className="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M2 10a8 8 0 018-8v8h8a8 8 0 11-16 0z" />
                            <path d="M12 2.252A8.014 8.014 0 0117.748 8H12V2.252z" />
                          </svg>
                        </div>
                      </div>
                      <div className="ml-5 w-0 flex-1">
                        <dl>
                          <dt className="text-sm font-medium text-gray-500 truncate">Competitive Score</dt>
                          <dd className="text-lg font-medium text-gray-900">8.7/10</dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Main Competitive Analytics Grid */}
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

              {/* Competitive Benchmarks Table */}
              <div className="bg-white shadow rounded-lg">
                <div className="px-6 py-4 border-b border-gray-200">
                  <h3 className="text-lg font-semibold text-gray-900">Competitive Benchmarks</h3>
                  <p className="text-sm text-gray-600">Performance comparison across key metrics</p>
                </div>
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Metric
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Your Brand
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Coca-Cola
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Pepsi
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Sprite
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Industry Avg
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      <tr className="hover:bg-gray-50 cursor-pointer" onClick={() => handleBenchmarkDrilldown('market_share', ['You', 'Coca-Cola', 'Pepsi', 'Sprite'])}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Market Share (%)</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">22.9</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">19.7</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">15.2</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">12.8</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">17.7</td>
                      </tr>
                      <tr className="hover:bg-gray-50 cursor-pointer" onClick={() => handleBenchmarkDrilldown('basket_value', ['You', 'Coca-Cola', 'Pepsi', 'Sprite'])}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Avg Basket Value (₱)</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">250</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">235</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">220</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">195</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">225</td>
                      </tr>
                      <tr className="hover:bg-gray-50 cursor-pointer" onClick={() => handleBenchmarkDrilldown('retention', ['You', 'Coca-Cola', 'Pepsi', 'Sprite'])}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Customer Retention (%)</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">78.5</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">73.2</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">71.8</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">68.4</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">73.0</td>
                      </tr>
                      <tr className="hover:bg-gray-50 cursor-pointer" onClick={() => handleBenchmarkDrilldown('frequency', ['You', 'Coca-Cola', 'Pepsi', 'Sprite'])}>
                        <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Purchase Frequency (/month)</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">3.2</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">2.8</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">2.6</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">2.4</td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">2.8</td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* Brand Cohorts Tab */}
          {activeTab === 'cohorts' && (
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-6">
                <div className="mb-4">
                  <h2 className="text-xl font-semibold text-gray-900">Brand Cohort Analysis</h2>
                  <p className="text-gray-600">Track brand adoption and customer retention by acquisition cohort over time</p>
                </div>
                <CohortRetention 
                  height={500}
                  showMetadata={true}
                  onCellClick={handleCohortClick}
                />
              </div>
            </div>
          )}

          {/* Brand Migration Tab */}
          {activeTab === 'switching' && (
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-6">
                <div className="mb-4">
                  <h2 className="text-xl font-semibold text-gray-900">Brand Migration Analysis</h2>
                  <p className="text-gray-600">Customer switching patterns and brand loyalty insights</p>
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

          {/* Benchmarks Tab */}
          {activeTab === 'benchmarks' && (
            <div className="space-y-6">
              <div className="bg-white rounded-lg shadow p-6">
                <div className="mb-6">
                  <h2 className="text-xl font-semibold text-gray-900">Competitive Benchmarking</h2>
                  <p className="text-gray-600">Performance comparisons and competitive positioning analysis</p>
                </div>

                {/* Benchmark Charts Grid */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
                  {/* Market Share Comparison */}
                  <div className="bg-gray-50 rounded-lg p-4">
                    <h3 className="text-lg font-medium text-gray-900 mb-4">Market Share Evolution</h3>
                    <div className="h-64">
                      <div className="w-full h-full bg-white rounded border">
                        <div style={{ height: 240, padding: '12px' }}>
                          <svg viewBox="0 0 400 220" className="w-full h-full">
                            <line x1="40" y1="200" x2="360" y2="200" stroke="#e5e7eb" strokeWidth="1"/>
                            <line x1="40" y1="200" x2="40" y2="20" stroke="#e5e7eb" strokeWidth="1"/>
                            
                            {/* Coca-Cola Line */}
                            <polyline
                              fill="none"
                              stroke="#f59e0b"
                              strokeWidth="3"
                              points="40,80 100,75 160,70 220,68 280,65 340,62"
                            />
                            <circle cx="340" cy="62" r="4" fill="#f59e0b"/>
                            
                            {/* Pepsi Line */}
                            <polyline
                              fill="none"
                              stroke="#3b82f6"
                              strokeWidth="3"
                              points="40,120 100,115 160,118 220,122 280,125 340,128"
                            />
                            <circle cx="340" cy="128" r="4" fill="#3b82f6"/>
                            
                            {/* Others Line */}
                            <polyline
                              fill="none"
                              stroke="#6b7280"
                              strokeWidth="2"
                              points="40,140 100,142 160,145 220,148 280,152 340,155"
                            />
                            <circle cx="340" cy="155" r="3" fill="#6b7280"/>
                            
                            {/* Labels */}
                            <text x="350" y="67" fontSize="12" fill="#f59e0b">Coca-Cola (42%)</text>
                            <text x="350" y="133" fontSize="12" fill="#3b82f6">Pepsi (28%)</text>
                            <text x="350" y="160" fontSize="12" fill="#6b7280">Others (30%)</text>
                            
                            {/* Axis Labels */}
                            <text x="40" y="215" fontSize="10" fill="#6b7280">Q1</text>
                            <text x="160" y="215" fontSize="10" fill="#6b7280">Q2</text>
                            <text x="280" y="215" fontSize="10" fill="#6b7280">Q3</text>
                            <text x="25" y="200" fontSize="10" fill="#6b7280">0%</text>
                            <text x="20" y="100" fontSize="10" fill="#6b7280">50%</text>
                          </svg>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Performance Radar */}
                  <div className="bg-gray-50 rounded-lg p-4">
                    <h3 className="text-lg font-medium text-gray-900 mb-4">Performance Radar</h3>
                    <div className="h-64">
                      <div className="w-full h-full bg-white rounded border">
                        <div style={{ height: 240, padding: '12px' }}>
                          <svg viewBox="0 0 400 220" className="w-full h-full">
                            {/* Radar Grid */}
                            <circle cx="200" cy="110" r="80" fill="none" stroke="#e5e7eb" strokeWidth="1"/>
                            <circle cx="200" cy="110" r="60" fill="none" stroke="#e5e7eb" strokeWidth="1"/>
                            <circle cx="200" cy="110" r="40" fill="none" stroke="#e5e7eb" strokeWidth="1"/>
                            <circle cx="200" cy="110" r="20" fill="none" stroke="#e5e7eb" strokeWidth="1"/>
                            
                            {/* Radar Lines */}
                            <line x1="200" y1="30" x2="200" y2="190" stroke="#e5e7eb" strokeWidth="1"/>
                            <line x1="120" y1="110" x2="280" y2="110" stroke="#e5e7eb" strokeWidth="1"/>
                            <line x1="144" y1="54" x2="256" y2="166" stroke="#e5e7eb" strokeWidth="1"/>
                            <line x1="256" y1="54" x2="144" y2="166" stroke="#e5e7eb" strokeWidth="1"/>
                            
                            {/* Data Polygon - Coca-Cola */}
                            <polygon
                              points="200,50 240,90 220,150 160,150 140,90"
                              fill="#f59e0b"
                              fillOpacity="0.3"
                              stroke="#f59e0b"
                              strokeWidth="2"
                            />
                            
                            {/* Data Points */}
                            <circle cx="200" cy="50" r="3" fill="#f59e0b"/>
                            <circle cx="240" cy="90" r="3" fill="#f59e0b"/>
                            <circle cx="220" cy="150" r="3" fill="#f59e0b"/>
                            <circle cx="160" cy="150" r="3" fill="#f59e0b"/>
                            <circle cx="140" cy="90" r="3" fill="#f59e0b"/>
                            
                            {/* Labels */}
                            <text x="195" y="25" fontSize="11" fill="#6b7280" textAnchor="middle">Quality</text>
                            <text x="250" y="90" fontSize="11" fill="#6b7280">Price</text>
                            <text x="225" y="175" fontSize="11" fill="#6b7280" textAnchor="middle">Availability</text>
                            <text x="120" y="175" fontSize="11" fill="#6b7280" textAnchor="middle">Marketing</text>
                            <text x="110" y="90" fontSize="11" fill="#6b7280">Innovation</text>
                          </svg>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Detailed Benchmarks */}
                <div className="bg-gray-50 rounded-lg p-6">
                  <h3 className="text-lg font-medium text-gray-900 mb-4">Detailed Performance Metrics</h3>
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-white">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Brand</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Market Share</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Basket Value</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Retention</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Frequency</th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Competitive Score</th>
                        </tr>
                      </thead>
                      <tbody className="bg-white divide-y divide-gray-200">
                        <tr className="bg-blue-50">
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Your Brand</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">22.9%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">₱250</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">78.5%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">3.2</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              8.7/10
                            </span>
                          </td>
                        </tr>
                        <tr>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Coca-Cola</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">19.7%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">₱235</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">73.2%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">2.8</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                              7.9/10
                            </span>
                          </td>
                        </tr>
                        <tr>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Pepsi</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">15.2%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">₱220</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">71.8%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">2.6</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                              7.3/10
                            </span>
                          </td>
                        </tr>
                        <tr>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">Sprite</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">12.8%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">₱195</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">68.4%</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">2.4</td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                              6.8/10
                            </span>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}