'use client';

import { useState, useEffect } from 'react';
import { switchDataSource, getCurrentDataSource, getDataServiceStatus, testDataSourceConnection } from '@/lib/dataService';

type DataSourceMode = 'azure' | 'parquet' | 'mock';

interface DataSourceToggleProps {
  className?: string;
  showDetails?: boolean;
  position?: 'top-right' | 'bottom-left' | 'bottom-right';
}

export default function DataSourceToggle({
  className = '',
  showDetails = false,
  position = 'bottom-right'
}: DataSourceToggleProps) {
  const [currentSource, setCurrentSource] = useState<DataSourceMode>('azure');
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [connectionStatus, setConnectionStatus] = useState<Record<DataSourceMode, boolean | null>>({
    azure: null,
    parquet: null,
    mock: true
  });

  useEffect(() => {
    setCurrentSource(getCurrentDataSource());
  }, []);

  const handleSourceChange = async (source: DataSourceMode) => {
    if (source === currentSource) return;

    setIsLoading(true);
    try {
      switchDataSource(source);
      setCurrentSource(source);
    } catch (error) {
      console.error('Failed to switch data source:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const testConnection = async (source: DataSourceMode) => {
    setIsLoading(true);
    try {
      const result = await testDataSourceConnection(source);
      setConnectionStatus(prev => ({
        ...prev,
        [source]: result.success
      }));
    } catch (error) {
      setConnectionStatus(prev => ({
        ...prev,
        [source]: false
      }));
    } finally {
      setIsLoading(false);
    }
  };

  const getSourceIcon = (source: DataSourceMode) => {
    const icons = {
      azure: '☁️',
      parquet: '📁',
      mock: '🎭'
    };
    return icons[source];
  };

  const getSourceLabel = (source: DataSourceMode) => {
    const labels = {
      azure: 'Azure Functions',
      parquet: 'Parquet Files',
      mock: 'Mock Data'
    };
    return labels[source];
  };

  const getConnectionIcon = (source: DataSourceMode) => {
    const status = connectionStatus[source];
    if (status === null) return '⚪';
    return status ? '🟢' : '🔴';
  };

  const getPositionClasses = () => {
    const positions = {
      'top-right': 'top-4 right-4',
      'bottom-left': 'bottom-4 left-4',
      'bottom-right': 'bottom-4 right-4'
    };
    return positions[position];
  };

  const status = getDataServiceStatus();

  return (
    <div className={`fixed ${getPositionClasses()} z-50 ${className}`}>
      {/* Toggle Button */}
      <div className="relative">
        <button
          onClick={() => setIsOpen(!isOpen)}
          className="flex items-center gap-2 bg-white border border-gray-300 rounded-lg px-3 py-2 shadow-sm hover:shadow-md transition-shadow"
          title={`Current: ${getSourceLabel(currentSource)}`}
        >
          <span className="text-lg">{getSourceIcon(currentSource)}</span>
          <span className="text-sm font-medium text-gray-700">
            {getSourceLabel(currentSource)}
          </span>
          <span className="text-xs">{getConnectionIcon(currentSource)}</span>
          <svg
            className={`w-4 h-4 text-gray-500 transition-transform ${isOpen ? 'rotate-180' : ''}`}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {/* Dropdown Menu */}
        {isOpen && (
          <div className="absolute bottom-full mb-2 right-0 w-80 bg-white border border-gray-200 rounded-lg shadow-lg overflow-hidden">
            {/* Header */}
            <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
              <h3 className="text-sm font-medium text-gray-900">Data Source Settings</h3>
              <p className="text-xs text-gray-500 mt-1">
                Switch between different data sources
              </p>
            </div>

            {/* Source Options */}
            <div className="p-2">
              {(['azure', 'parquet', 'mock'] as DataSourceMode[]).map((source) => (
                <div key={source} className="mb-2 last:mb-0">
                  <button
                    onClick={() => handleSourceChange(source)}
                    disabled={isLoading}
                    className={`w-full flex items-center justify-between p-3 rounded-md transition-all ${
                      currentSource === source
                        ? 'bg-blue-50 border-2 border-blue-200 text-blue-900'
                        : 'bg-gray-50 border border-gray-200 text-gray-700 hover:bg-gray-100'
                    } ${isLoading ? 'opacity-50 cursor-not-allowed' : ''}`}
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-lg">{getSourceIcon(source)}</span>
                      <div className="text-left">
                        <div className="text-sm font-medium">{getSourceLabel(source)}</div>
                        <div className="text-xs text-gray-500">
                          {source === 'azure' && 'Live data from Azure Functions'}
                          {source === 'parquet' && 'Static data from Parquet files'}
                          {source === 'mock' && 'Local development data'}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <span title="Connection status">{getConnectionIcon(source)}</span>
                      {currentSource === source && (
                        <span className="text-blue-600">✓</span>
                      )}
                    </div>
                  </button>

                  {/* Test Connection Button */}
                  <div className="flex justify-end mt-1">
                    <button
                      onClick={() => testConnection(source)}
                      disabled={isLoading}
                      className="text-xs text-gray-500 hover:text-gray-700 underline"
                    >
                      Test Connection
                    </button>
                  </div>
                </div>
              ))}
            </div>

            {/* Status Information */}
            {showDetails && (
              <div className="px-4 py-3 bg-gray-50 border-t border-gray-200">
                <div className="text-xs text-gray-600">
                  <div className="flex justify-between mb-1">
                    <span>Version:</span>
                    <span className="font-mono">{status.version}</span>
                  </div>
                  <div className="flex justify-between mb-1">
                    <span>Provider:</span>
                    <span>{status.provider}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Status:</span>
                    <span className="uppercase font-medium">{status.status}</span>
                  </div>
                </div>
              </div>
            )}

            {/* Close Button */}
            <div className="px-4 py-2 bg-gray-50 border-t border-gray-200">
              <button
                onClick={() => setIsOpen(false)}
                className="text-xs text-gray-500 hover:text-gray-700"
              >
                Close
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Loading Overlay */}
      {isLoading && (
        <div className="absolute inset-0 bg-white bg-opacity-50 flex items-center justify-center rounded-lg">
          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
        </div>
      )}
    </div>
  );
}