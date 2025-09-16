"use client";

import React, { useState } from 'react';
import { Card } from '@/components/AmazonCard';
import { useDashboardLink, DATASETS } from '@/lib/hooks/useETL';
import toast from 'react-hot-toast';

interface ETLDashboardViewerProps {
  className?: string;
}

export default function ETLDashboardViewer({ className }: ETLDashboardViewerProps) {
  const [selectedDataset, setSelectedDataset] = useState('');
  const [filters, setFilters] = useState('{}');
  const [isFiltersValid, setIsFiltersValid] = useState(true);
  
  const { generateLink, openDashboard } = useDashboardLink();

  // Validate JSON filters
  const validateFilters = (filtersStr: string) => {
    try {
      if (filtersStr.trim() === '') {
        setIsFiltersValid(true);
        return true;
      }
      JSON.parse(filtersStr);
      setIsFiltersValid(true);
      return true;
    } catch {
      setIsFiltersValid(false);
      return false;
    }
  };

  const handleFiltersChange = (value: string) => {
    setFilters(value);
    validateFilters(value);
  };

  const handleOpenDashboard = () => {
    if (!validateFilters(filters)) {
      toast.error('Invalid JSON filters');
      return;
    }

    try {
      const parsedFilters = filters.trim() ? JSON.parse(filters) : undefined;
      openDashboard(selectedDataset || undefined, parsedFilters);
      toast.success('Opening dashboard in new window');
    } catch (err) {
      toast.error('Failed to open dashboard: ' + (err as Error).message);
    }
  };

  const handleCopyLink = () => {
    if (!validateFilters(filters)) {
      toast.error('Invalid JSON filters');
      return;
    }

    try {
      const parsedFilters = filters.trim() ? JSON.parse(filters) : undefined;
      const link = generateLink(selectedDataset || undefined, parsedFilters);
      navigator.clipboard.writeText(link);
      toast.success('Dashboard link copied to clipboard');
    } catch (err) {
      toast.error('Failed to copy link: ' + (err as Error).message);
    }
  };

  const presetFilters = [
    {
      label: 'Last 30 Days',
      value: JSON.stringify({
        date_range: {
          start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          end: new Date().toISOString().split('T')[0]
        }
      }, null, 2)
    },
    {
      label: 'This Month',
      value: JSON.stringify({
        date_range: {
          start: new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0],
          end: new Date().toISOString().split('T')[0]
        }
      }, null, 2)
    },
    {
      label: 'Top Categories',
      value: JSON.stringify({
        filters: {
          category: ['Beverages', 'Personal Care', 'Household'],
          limit: 100
        }
      }, null, 2)
    }
  ];

  return (
    <Card className={className}>
      <div className="space-y-4">
        <div className="border-b border-gray-200 pb-4">
          <h3 className="text-lg font-semibold text-gray-900">Real-Time Dashboard</h3>
          <p className="text-sm text-gray-600">Access live analytics dashboards powered by ETL data</p>
        </div>

        <div className="space-y-4">
          {/* Dataset Selection */}
          <div>
            <label htmlFor="dashboard-dataset" className="block text-sm font-medium text-gray-700 mb-2">
              Dataset (Optional)
            </label>
            <select
              id="dashboard-dataset"
              value={selectedDataset}
              onChange={(e) => setSelectedDataset(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
            >
              <option value="">All datasets</option>
              {DATASETS.map((ds) => (
                <option key={ds.value} value={ds.value}>
                  {ds.label}
                </option>
              ))}
            </select>
          </div>

          {/* Filter Presets */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filter Presets
            </label>
            <div className="flex flex-wrap gap-2">
              {presetFilters.map((preset) => (
                <button
                  key={preset.label}
                  onClick={() => handleFiltersChange(preset.value)}
                  className="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200 transition-colors"
                >
                  {preset.label}
                </button>
              ))}
              <button
                onClick={() => handleFiltersChange('{}')}
                className="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200 transition-colors"
              >
                Clear
              </button>
            </div>
          </div>

          {/* Custom Filters */}
          <div>
            <label htmlFor="dashboard-filters" className="block text-sm font-medium text-gray-700 mb-2">
              Custom Filters (JSON)
            </label>
            <textarea
              id="dashboard-filters"
              value={filters}
              onChange={(e) => handleFiltersChange(e.target.value)}
              placeholder="Enter JSON filters (optional)"
              rows={8}
              className={`w-full px-3 py-2 border rounded-md font-mono text-sm focus:outline-none focus:ring-2 focus:border-orange-500 ${
                isFiltersValid 
                  ? 'border-gray-300 focus:ring-orange-500' 
                  : 'border-red-300 focus:ring-red-500 bg-red-50'
              }`}
            />
            {!isFiltersValid && (
              <p className="mt-1 text-sm text-red-600">Invalid JSON format</p>
            )}
            <p className="mt-1 text-xs text-gray-500">
              Example: {"{"}"date_range": {"{"}"start": "2024-01-01", "end": "2024-12-31"{"}"}{"}"} 
            </p>
          </div>

          {/* Dashboard Actions */}
          <div className="flex gap-3">
            <button
              onClick={handleOpenDashboard}
              disabled={!isFiltersValid}
              className="flex-1 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
            >
              <span>🚀</span>
              Open Dashboard
            </button>
            <button
              onClick={handleCopyLink}
              disabled={!isFiltersValid}
              className="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 disabled:bg-gray-100 disabled:cursor-not-allowed transition-colors flex items-center gap-2"
            >
              <span>📋</span>
              Copy Link
            </button>
          </div>

          {/* Preview URL */}
          <div className="mt-4 p-3 bg-gray-50 border border-gray-200 rounded-lg">
            <div className="flex items-center justify-between mb-2">
              <label className="text-sm font-medium text-gray-700">Dashboard URL Preview</label>
              <span className="text-xs text-gray-500">Live preview</span>
            </div>
            <div className="font-mono text-xs text-gray-600 break-all bg-white p-2 rounded border">
              {(() => {
                try {
                  const parsedFilters = filters.trim() && isFiltersValid ? JSON.parse(filters) : undefined;
                  return generateLink(selectedDataset || undefined, parsedFilters);
                } catch {
                  return 'Invalid filters - unable to generate URL';
                }
              })()}
            </div>
          </div>

          {/* Dashboard Info */}
          <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex">
              <div className="text-blue-400">
                <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h4 className="text-sm font-medium text-blue-800">Dashboard Features</h4>
                <div className="mt-2 text-sm text-blue-700 space-y-1">
                  <p>• Real-time data visualization powered by your ETL pipeline</p>
                  <p>• Interactive charts and filters for deep analysis</p>
                  <p>• Automatic refresh with latest data exports</p>
                  <p>• Support for custom date ranges and category filters</p>
                  <p>• Export capabilities for charts and data tables</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Card>
  );
}