'use client';

import React, { useState, useRef } from 'react';

interface ScoutExportButtonProps {
  exportType?: 'crosstab_14d' | 'brands_summary' | 'flat_latest' | 'flat_today_no_transcripts' | 'flat_today_full' | 'pbi_transactions_summary';
  customSql?: string;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  variant?: 'primary' | 'secondary' | 'outline';
}

export default function ScoutExportButton({
  exportType = 'crosstab_14d',
  customSql,
  className = '',
  size = 'md',
  variant = 'outline'
}: ScoutExportButtonProps) {
  const [isExporting, setIsExporting] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [showCommand, setShowCommand] = useState(false);
  const [lastCommand, setLastCommand] = useState('');
  const buttonRef = useRef<HTMLButtonElement>(null);

  const sizes = {
    sm: 'px-2 py-1 text-xs',
    md: 'px-3 py-1.5 text-sm',
    lg: 'px-4 py-2 text-base'
  };

  const variants = {
    primary: 'bg-orange-500 text-white hover:bg-orange-600 border-orange-500',
    secondary: 'bg-gray-500 text-white hover:bg-gray-600 border-gray-500',
    outline: 'bg-white text-gray-700 hover:bg-gray-50 border-gray-300'
  };

  const handleExport = async (type: string, options: { privacy?: 'safe' | 'full'; customSql?: string } = {}) => {
    setIsExporting(true);
    setShowDropdown(false);

    try {
      let apiUrl = '';
      let requestBody = {};

      if (options.customSql) {
        // Custom SQL export
        apiUrl = '/api/export/custom';
        requestBody = {
          sql: options.customSql,
          filename: `custom_export_${new Date().toISOString().slice(0, 10)}.csv`,
          description: 'Custom dashboard export'
        };
      } else {
        // Predefined export type
        const finalType = options.privacy === 'safe' ? 'flat_today_no_transcripts' : type;
        apiUrl = `/api/export/${finalType}`;
        requestBody = {};
      }

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody)
      });

      const result = await response.json();

      if (!result.ok) {
        throw new Error(result.error || 'Export API error');
      }

      if (result.mode === 'resolve') {
        // Show Bruno command for copy-paste execution
        setLastCommand(result.runner_command);
        setShowCommand(true);

        // Optional: Copy to clipboard
        if (navigator.clipboard) {
          await navigator.clipboard.writeText(result.runner_command);
        }

      } else if (result.mode === 'delegate') {
        // Webhook delegation - show status
        if (result.delegated && result.bruno?.ok) {
          alert(`Export dispatched successfully! File: ${result.filename}`);
        } else {
          throw new Error(result.bruno?.error || 'Webhook delegation failed');
        }
      }

    } catch (error: any) {
      console.error('Export failed:', error);
      alert(`Export failed: ${error.message}`);
    } finally {
      setIsExporting(false);
    }
  };

  const exportOptions = [
    {
      key: 'crosstab_14d',
      label: 'Crosstab 14-Day',
      icon: '📊',
      description: 'Time period analysis'
    },
    {
      key: 'brands_summary',
      label: 'Brand Performance',
      icon: '🏷️',
      description: 'Revenue & metrics by brand'
    },
    {
      key: 'flat_latest',
      label: 'Latest Transactions',
      icon: '📝',
      description: 'Recent 1000 transactions'
    },
    {
      key: 'pbi_transactions_summary',
      label: 'Power BI Export',
      icon: '📈',
      description: '30-day optimized dataset'
    }
  ];

  return (
    <>
      <div className={`relative inline-block ${className}`}>
        <button
          ref={buttonRef}
          onClick={() => setShowDropdown(!showDropdown)}
          disabled={isExporting}
          className={`flex items-center gap-2 border rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${sizes[size]} ${variants[variant]}`}
          title="Export Scout data"
        >
          {isExporting ? (
            <div className="w-4 h-4 border-2 border-gray-300 border-t-orange-500 rounded-full animate-spin" />
          ) : (
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          )}
          <span>{isExporting ? 'Exporting...' : 'Export'}</span>
          <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        {showDropdown && !isExporting && (
          <>
            {/* Backdrop */}
            <div
              className="fixed inset-0 z-10"
              onClick={() => setShowDropdown(false)}
            />

            {/* Dropdown Menu */}
            <div className="absolute right-0 top-full mt-1 w-72 bg-white border border-gray-200 rounded-md shadow-lg z-20">
              <div className="py-2">
                <div className="px-3 py-1 text-xs font-medium text-gray-500 uppercase tracking-wide">
                  Predefined Exports
                </div>

                {exportOptions.map((option) => (
                  <div key={option.key}>
                    <button
                      onClick={() => handleExport(option.key)}
                      className="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 flex items-start gap-3"
                    >
                      <span className="text-lg">{option.icon}</span>
                      <div>
                        <div className="font-medium">{option.label}</div>
                        <div className="text-xs text-gray-500">{option.description}</div>
                      </div>
                    </button>
                  </div>
                ))}

                <div className="border-t border-gray-100 my-2" />

                <div className="px-3 py-1 text-xs font-medium text-gray-500 uppercase tracking-wide">
                  Privacy Options
                </div>

                <button
                  onClick={() => handleExport('flat_today_no_transcripts', { privacy: 'safe' })}
                  className="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 flex items-start gap-3"
                >
                  <span className="text-lg">🔒</span>
                  <div>
                    <div className="font-medium">Privacy-Safe Export</div>
                    <div className="text-xs text-gray-500">Today's data without transcripts</div>
                  </div>
                </button>

                <button
                  onClick={() => handleExport('flat_today_full', { privacy: 'full' })}
                  className="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 flex items-start gap-3"
                >
                  <span className="text-lg">🎙️</span>
                  <div>
                    <div className="font-medium">Full Data Export</div>
                    <div className="text-xs text-gray-500">Complete data with transcripts</div>
                  </div>
                </button>

                {customSql && (
                  <>
                    <div className="border-t border-gray-100 my-2" />
                    <button
                      onClick={() => handleExport('custom', { customSql })}
                      className="w-full text-left px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 flex items-start gap-3"
                    >
                      <span className="text-lg">⚡</span>
                      <div>
                        <div className="font-medium">Custom Query</div>
                        <div className="text-xs text-gray-500">Current view data</div>
                      </div>
                    </button>
                  </>
                )}
              </div>
            </div>
          </>
        )}
      </div>

      {/* Bruno Command Modal */}
      {showCommand && lastCommand && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-2xl w-full mx-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold text-gray-900">
                Export Command Ready
              </h3>
              <button
                onClick={() => setShowCommand(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div className="mb-4">
              <p className="text-sm text-gray-600 mb-2">
                Run this command in Bruno to execute the export with vault-managed credentials:
              </p>
              <div className="bg-gray-900 text-green-400 p-4 rounded-md font-mono text-sm break-all">
                {lastCommand}
              </div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={async () => {
                  if (navigator.clipboard) {
                    await navigator.clipboard.writeText(lastCommand);
                    alert('Command copied to clipboard!');
                  }
                }}
                className="px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 text-sm"
              >
                Copy Command
              </button>
              <button
                onClick={() => setShowCommand(false)}
                className="px-4 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300 text-sm"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}