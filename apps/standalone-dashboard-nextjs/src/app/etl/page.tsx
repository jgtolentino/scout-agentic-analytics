"use client";

import React, { useState } from 'react';
import PageFrame from '@/components/PageFrame';
import { Card, KPI } from '@/components/AmazonCard';
import ETLExportForm from '@/components/etl/ETLExportForm';
import ETLStatusCard from '@/components/etl/ETLStatusCard';
import ETLDashboardViewer from '@/components/etl/ETLDashboardViewer';
import ETLMirrorControls from '@/components/etl/ETLMirrorControls';
import { useETLStatus } from '@/lib/hooks/useETL';
import toast from 'react-hot-toast';

export default function ETLManagement() {
  const [activeTab, setActiveTab] = useState<'export' | 'mirror' | 'dashboard'>('export');
  const { data: statusList } = useETLStatus();

  // Calculate summary statistics
  const stats = React.useMemo(() => {
    if (!statusList || statusList.length === 0) {
      return {
        totalPipelines: 0,
        activePipelines: 0,
        completedToday: 0,
        failureRate: '0%'
      };
    }

    const today = new Date().toDateString();
    const completedToday = statusList.filter(s => 
      s.status === 'completed' && 
      s.completed_at && 
      new Date(s.completed_at).toDateString() === today
    ).length;

    const failed = statusList.filter(s => s.status === 'failed').length;
    const total = statusList.length;
    const failureRate = total > 0 ? `${Math.round((failed / total) * 100)}%` : '0%';
    const active = statusList.filter(s => s.status === 'running' || s.status === 'pending').length;

    return {
      totalPipelines: total,
      activePipelines: active,
      completedToday,
      failureRate
    };
  }, [statusList]);

  const handleExportComplete = (result: any) => {
    // Optionally refresh status or handle completion
    toast.success('Export operation completed!');
  };

  const handleMirrorComplete = (result: any) => {
    // Optionally refresh status or handle completion
    toast.success('Mirror operation completed!');
  };

  const tabs = [
    { id: 'export', label: 'Data Export', icon: '📤' },
    { id: 'mirror', label: 'S3 Mirror', icon: '☁️' },
    { id: 'dashboard', label: 'Live Dashboard', icon: '📊' },
  ] as const;

  return (
    <PageFrame title="ETL Management">
      {/* Overview KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <KPI 
          label="Total Pipelines" 
          value={stats.totalPipelines.toString()}
          hint="All pipeline runs"
        />
        <KPI 
          label="Active Jobs" 
          value={stats.activePipelines.toString()}
          hint="Running or pending"
          trend={stats.activePipelines > 0 ? 'up' : 'flat'}
        />
        <KPI 
          label="Completed Today" 
          value={stats.completedToday.toString()}
          hint="Successful runs today"
          trend={stats.completedToday > 0 ? 'up' : 'flat'}
        />
        <KPI 
          label="Failure Rate" 
          value={stats.failureRate}
          hint="Failed vs total runs"
          trend={parseInt(stats.failureRate) > 10 ? 'down' : 'flat'}
        />
      </div>

      {/* Main Content Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column - Status Monitoring */}
        <div className="lg:col-span-1">
          <ETLStatusCard />
        </div>

        {/* Right Column - Main Actions */}
        <div className="lg:col-span-2">
          <Card>
            {/* Tab Navigation */}
            <div className="border-b border-gray-200 mb-6">
              <nav className="-mb-px flex space-x-8">
                {tabs.map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`py-2 px-1 border-b-2 font-medium text-sm whitespace-nowrap flex items-center gap-2 transition-colors ${
                      activeTab === tab.id
                        ? 'border-orange-500 text-orange-600'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    }`}
                  >
                    <span>{tab.icon}</span>
                    {tab.label}
                  </button>
                ))}
              </nav>
            </div>

            {/* Tab Content */}
            <div className="min-h-96">
              {activeTab === 'export' && (
                <div>
                  <ETLExportForm onExportComplete={handleExportComplete} />
                </div>
              )}

              {activeTab === 'mirror' && (
                <div>
                  <ETLMirrorControls onMirrorComplete={handleMirrorComplete} />
                </div>
              )}

              {activeTab === 'dashboard' && (
                <div>
                  <ETLDashboardViewer />
                </div>
              )}
            </div>
          </Card>
        </div>
      </div>

      {/* Information Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* ETL Pipeline Information */}
        <Card>
          <div className="space-y-4">
            <div className="border-b border-gray-200 pb-4">
              <h3 className="text-lg font-semibold text-gray-900">ETL Pipeline Overview</h3>
              <p className="text-sm text-gray-600">Understanding the data flow and architecture</p>
            </div>
            <div className="space-y-3 text-sm">
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Data Layers</h4>
                <div className="space-y-2 pl-4">
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-amber-500 rounded-full"></div>
                    <span className="text-gray-700"><strong>Bronze:</strong> Raw transactional data</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-gray-400 rounded-full"></div>
                    <span className="text-gray-700"><strong>Silver:</strong> Cleaned and validated data</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 bg-yellow-500 rounded-full"></div>
                    <span className="text-gray-700"><strong>Gold:</strong> Business-ready analytics</span>
                  </div>
                </div>
              </div>
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Export Capabilities</h4>
                <ul className="space-y-1 pl-4 text-gray-700">
                  <li>• Export data in CSV or JSONL formats</li>
                  <li>• Custom date range filtering</li>
                  <li>• Automatic file compression</li>
                  <li>• Direct download or Storage access</li>
                </ul>
              </div>
            </div>
          </div>
        </Card>

        {/* Environment Information */}
        <Card>
          <div className="space-y-4">
            <div className="border-b border-gray-200 pb-4">
              <h3 className="text-lg font-semibold text-gray-900">Environment Status</h3>
              <p className="text-sm text-gray-600">Current configuration and environment details</p>
            </div>
            <div className="space-y-3 text-sm">
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Configuration</h4>
                <div className="space-y-1">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Environment:</span>
                    <span className="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                      {process.env.NEXT_PUBLIC_USE_MOCK === '1' ? 'Development (Mock)' : 'Production'}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Supabase URL:</span>
                    <span className="font-mono text-xs bg-gray-100 px-2 py-1 rounded truncate max-w-40">
                      {process.env.NEXT_PUBLIC_SUPABASE_URL === 'https://your-project.supabase.co' 
                        ? 'http://localhost:54321' 
                        : process.env.NEXT_PUBLIC_SUPABASE_URL}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Functions Base:</span>
                    <span className="font-mono text-xs bg-gray-100 px-2 py-1 rounded">
                      {process.env.NEXT_PUBLIC_FUNCTION_BASE || '/functions/v1'}
                    </span>
                  </div>
                </div>
              </div>
              <div>
                <h4 className="font-medium text-gray-900 mb-2">Available Functions</h4>
                <ul className="space-y-1 pl-4 text-gray-700">
                  <li>• <code className="text-xs bg-gray-100 px-1 rounded">export-to-storage</code> - Export data to Supabase Storage</li>
                  <li>• <code className="text-xs bg-gray-100 px-1 rounded">mirror-to-s3</code> - Sync Storage to AWS S3</li>
                  <li>• <code className="text-xs bg-gray-100 px-1 rounded">dashboard</code> - Real-time analytics dashboard</li>
                </ul>
              </div>
            </div>
          </div>
        </Card>
      </div>
    </PageFrame>
  );
}