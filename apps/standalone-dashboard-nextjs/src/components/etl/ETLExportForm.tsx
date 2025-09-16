"use client";

import React, { useState } from 'react';
import { Card } from '@/components/AmazonCard';
import { useExportToStorage, DATASETS, ExportRequest } from '@/lib/hooks/useETL';
import toast from 'react-hot-toast';

interface ETLExportFormProps {
  onExportComplete?: (result: any) => void;
}

export default function ETLExportForm({ onExportComplete }: ETLExportFormProps) {
  const [dataset, setDataset] = useState('');
  const [format, setFormat] = useState<'CSV' | 'JSONL'>('CSV');
  const [dateRange, setDateRange] = useState({
    start: '',
    end: ''
  });
  const [useCustomDateRange, setUseCustomDateRange] = useState(false);

  const { exportData, isExporting, error, data, isSuccess, reset } = useExportToStorage();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!dataset) {
      toast.error('Please select a dataset');
      return;
    }

    const exportRequest: ExportRequest = {
      dataset,
      format,
    };

    // Add date range if specified
    if (useCustomDateRange && (dateRange.start || dateRange.end)) {
      exportRequest.dateRange = {
        start: dateRange.start || undefined,
        end: dateRange.end || undefined,
      };
    }

    try {
      await exportData(exportRequest);
      toast.success('Export started successfully!');
      onExportComplete?.(data);
    } catch (err) {
      toast.error('Export failed: ' + (err as Error).message);
    }
  };

  const handleReset = () => {
    setDataset('');
    setFormat('CSV');
    setDateRange({ start: '', end: '' });
    setUseCustomDateRange(false);
    reset();
  };

  return (
    <Card>
      <div className="space-y-4">
        <div className="border-b border-gray-200 pb-4">
          <h3 className="text-lg font-semibold text-gray-900">Export Data</h3>
          <p className="text-sm text-gray-600">Export data from the lakehouse to Supabase Storage</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Dataset Selection */}
          <div>
            <label htmlFor="dataset" className="block text-sm font-medium text-gray-700 mb-2">
              Dataset
            </label>
            <select
              id="dataset"
              value={dataset}
              onChange={(e) => setDataset(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
              disabled={isExporting}
            >
              <option value="">Select a dataset...</option>
              {DATASETS.map((ds) => (
                <option key={ds.value} value={ds.value}>
                  {ds.label}
                </option>
              ))}
            </select>
          </div>

          {/* Format Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Export Format
            </label>
            <div className="flex gap-4">
              <label className="flex items-center">
                <input
                  type="radio"
                  name="format"
                  value="CSV"
                  checked={format === 'CSV'}
                  onChange={(e) => setFormat(e.target.value as 'CSV' | 'JSONL')}
                  disabled={isExporting}
                  className="mr-2 text-orange-600 focus:ring-orange-500"
                />
                CSV
              </label>
              <label className="flex items-center">
                <input
                  type="radio"
                  name="format"
                  value="JSONL"
                  checked={format === 'JSONL'}
                  onChange={(e) => setFormat(e.target.value as 'CSV' | 'JSONL')}
                  disabled={isExporting}
                  className="mr-2 text-orange-600 focus:ring-orange-500"
                />
                JSONL
              </label>
            </div>
          </div>

          {/* Date Range Toggle */}
          <div>
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={useCustomDateRange}
                onChange={(e) => setUseCustomDateRange(e.target.checked)}
                disabled={isExporting}
                className="mr-2 text-orange-600 focus:ring-orange-500"
              />
              <span className="text-sm font-medium text-gray-700">Use custom date range</span>
            </label>
          </div>

          {/* Date Range Inputs */}
          {useCustomDateRange && (
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label htmlFor="startDate" className="block text-sm font-medium text-gray-700 mb-2">
                  Start Date
                </label>
                <input
                  type="date"
                  id="startDate"
                  value={dateRange.start}
                  onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })}
                  disabled={isExporting}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                />
              </div>
              <div>
                <label htmlFor="endDate" className="block text-sm font-medium text-gray-700 mb-2">
                  End Date
                </label>
                <input
                  type="date"
                  id="endDate"
                  value={dateRange.end}
                  onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })}
                  disabled={isExporting}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                />
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3 pt-4">
            <button
              type="submit"
              disabled={isExporting || !dataset}
              className="flex-1 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
            >
              {isExporting ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                  Exporting...
                </>
              ) : (
                <>
                  <span>📤</span>
                  Export Data
                </>
              )}
            </button>
            <button
              type="button"
              onClick={handleReset}
              disabled={isExporting}
              className="px-4 py-2 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300 disabled:bg-gray-100 disabled:cursor-not-allowed transition-colors"
            >
              Reset
            </button>
          </div>
        </form>

        {/* Success Message */}
        {isSuccess && data && (
          <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
            <div className="flex">
              <div className="text-green-400">
                <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h4 className="text-sm font-medium text-green-800">Export Completed!</h4>
                <div className="mt-2 text-sm text-green-700">
                  {data.file_path && (
                    <p>File saved to: <span className="font-mono text-xs">{data.file_path}</span></p>
                  )}
                  {data.metadata && (
                    <div className="mt-2 space-y-1">
                      <p>Rows exported: {data.metadata.rows_exported?.toLocaleString()}</p>
                      <p>File size: {data.metadata.file_size ? `${(data.metadata.file_size / 1024 / 1024).toFixed(2)} MB` : 'Unknown'}</p>
                      <p>Export time: {data.metadata.export_timestamp}</p>
                    </div>
                  )}
                  {data.download_url && (
                    <div className="mt-3">
                      <a
                        href={data.download_url}
                        download
                        className="inline-flex items-center px-3 py-1 bg-green-600 text-white text-xs rounded-md hover:bg-green-700 transition-colors"
                      >
                        <span>📥</span>
                        <span className="ml-1">Download File</span>
                      </a>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Error Message */}
        {error && (
          <div className="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <div className="flex">
              <div className="text-red-400">
                <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h4 className="text-sm font-medium text-red-800">Export Failed</h4>
                <div className="mt-2 text-sm text-red-700">
                  <p>{error.message}</p>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </Card>
  );
}