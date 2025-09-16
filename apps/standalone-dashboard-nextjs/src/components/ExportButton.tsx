'use client';

import React, { useState, useRef } from 'react';
import { exportChart, exportToCSV, prepareChartDataForCSV } from '@/lib/utils/exportUtils';

interface ExportButtonProps {
  chartData: any[];
  chartTitle: string;
  className?: string;
  formats?: ('png' | 'csv' | 'pdf' | 'json')[];
}

export default function ExportButton({ 
  chartData, 
  chartTitle, 
  className = '',
  formats = ['png', 'csv', 'pdf']
}: ExportButtonProps) {
  const [isExporting, setIsExporting] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);

  const handleExport = async (format: 'png' | 'csv' | 'pdf' | 'json' | 'both') => {
    setIsExporting(true);
    setShowDropdown(false);
    
    try {
      // Find the parent chart element
      const chartElement = buttonRef.current?.closest('.amazon-card, [data-chart]') as HTMLElement;
      if (!chartElement) {
        throw new Error('Chart container not found');
      }

      const timestamp = new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-');
      const baseFilename = `${chartTitle.toLowerCase().replace(/\s+/g, '_')}_${timestamp}`;
      
      if (format === 'png') {
        await exportChart(chartElement, 'png', chartTitle);
      } else if (format === 'csv') {
        const csvData = prepareChartDataForCSV(chartData);
        await exportToCSV(csvData, {
          filename: `${baseFilename}.csv`,
          includeMetadata: true
        });
      } else if (format === 'pdf') {
        await exportChart(chartElement, 'pdf', chartTitle);
      } else if (format === 'json') {
        const jsonData = {
          title: chartTitle,
          exportDate: new Date().toISOString(),
          chartData: chartData
        };
        await exportToCSV([jsonData], {
          filename: `${baseFilename}.json`
        });
      } else if (format === 'both') {
        // Export PNG
        await exportChart(chartElement, 'png', chartTitle);
        
        // Export CSV
        const csvData = prepareChartDataForCSV(chartData);
        await exportToCSV(csvData, {
          filename: `${baseFilename}.csv`,
          includeMetadata: true
        });
      }
      
    } catch (error) {
      console.error('Export failed:', error);
      alert('Export failed. Please try again.');
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className={`relative inline-block ${className}`}>
      <button
        ref={buttonRef}
        onClick={() => setShowDropdown(!showDropdown)}
        disabled={isExporting}
        className="flex items-center gap-2 px-3 py-1.5 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        title="Export chart"
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
          <div className="absolute right-0 top-full mt-1 w-52 bg-white border border-gray-200 rounded-md shadow-lg z-20">
            <div className="py-1">
              {formats.includes('png') && (
                <button
                  onClick={() => handleExport('png')}
                  className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  Export as PNG
                  <span className="text-xs text-gray-400 ml-auto">Image</span>
                </button>
              )}
              
              {formats.includes('csv') && (
                <button
                  onClick={() => handleExport('csv')}
                  className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  Export as CSV
                  <span className="text-xs text-gray-400 ml-auto">Data</span>
                </button>
              )}

              {formats.includes('pdf') && (
                <button
                  onClick={() => handleExport('pdf')}
                  className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  Export as PDF
                  <span className="text-xs text-gray-400 ml-auto">Report</span>
                </button>
              )}

              {formats.includes('json') && (
                <button
                  onClick={() => handleExport('json')}
                  className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center gap-2"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
                  </svg>
                  Export as JSON
                  <span className="text-xs text-gray-400 ml-auto">Raw</span>
                </button>
              )}
              
              {formats.length > 1 && (
                <>
                  <div className="border-t border-gray-100 my-1" />
                  
                  <button
                    onClick={() => handleExport('both')}
                    className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center gap-2"
                  >
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10" />
                    </svg>
                    Export All (PNG + CSV)
                    <span className="text-xs text-gray-400 ml-auto">Bulk</span>
                  </button>
                </>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}