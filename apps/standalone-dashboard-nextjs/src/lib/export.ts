/**
 * Export utilities for charts and data
 * Supports PNG export for charts and CSV export for data
 */

import { saveAs } from 'file-saver';

// Chart export functionality
export const exportChartAsPNG = (chartElement: Element, filename: string = 'chart') => {
  try {
    // Find the Plotly graph div
    const plotlyDiv = chartElement.querySelector('.js-plotly-plot') as any;
    
    if (!plotlyDiv || !window.Plotly) {
      throw new Error('Plotly chart not found');
    }
    
    // Use Plotly's built-in export functionality
    window.Plotly.toImage(plotlyDiv, {
      format: 'png',
      width: 1200,
      height: 800,
      scale: 2 // High DPI
    }).then((dataUrl: string) => {
      // Convert data URL to blob and download
      const link = document.createElement('a');
      link.download = `${filename}.png`;
      link.href = dataUrl;
      link.click();
    });
  } catch (error) {
    console.error('PNG export failed:', error);
    throw error;
  }
};

// CSV export functionality
export const exportDataAsCSV = (data: any[], filename: string = 'data') => {
  try {
    if (!data || data.length === 0) {
      throw new Error('No data to export');
    }

    // Convert data to CSV format
    const csvContent = convertToCSV(data);
    
    // Create blob and download
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    saveAs(blob, `${filename}.csv`);
  } catch (error) {
    console.error('CSV export failed:', error);
    throw error;
  }
};

// Helper function to convert array of objects to CSV
const convertToCSV = (data: any[]): string => {
  if (!data || data.length === 0) return '';
  
  // Get headers from the first object
  const headers = Object.keys(data[0]);
  
  // Create CSV content
  const csvRows = [
    headers.join(','), // Header row
    ...data.map(row => 
      headers.map(header => {
        const value = row[header];
        // Handle values that might contain commas or quotes
        if (typeof value === 'string' && (value.includes(',') || value.includes('"'))) {
          return `"${value.replace(/"/g, '""')}"`;
        }
        return value;
      }).join(',')
    )
  ];
  
  return csvRows.join('\n');
};

// Transform Plotly data to CSV-ready format
export const plotlyDataToCSV = (plotlyData: any[]): any[] => {
  if (!plotlyData || plotlyData.length === 0) return [];
  
  const csvData: any[] = [];
  
  plotlyData.forEach((trace, traceIndex) => {
    const traceName = trace.name || `Series ${traceIndex + 1}`;
    
    if (trace.x && trace.y) {
      // Standard x/y data
      trace.x.forEach((xVal: any, index: number) => {
        csvData.push({
          series: traceName,
          x: xVal,
          y: trace.y[index],
          ...(trace.text && { label: trace.text[index] })
        });
      });
    } else if (trace.labels && trace.values) {
      // Pie chart data
      trace.labels.forEach((label: string, index: number) => {
        csvData.push({
          series: traceName,
          label,
          value: trace.values[index]
        });
      });
    } else if (trace.parents && trace.labels && trace.values) {
      // Treemap data
      trace.labels.forEach((label: string, index: number) => {
        csvData.push({
          series: traceName,
          label,
          parent: trace.parents[index],
          value: trace.values[index]
        });
      });
    }
  });
  
  return csvData;
};

// Enhanced export with metadata
export const exportChartWithMetadata = (
  chartElement: Element, 
  plotlyData: any[], 
  title: string,
  format: 'png' | 'csv' | 'both' = 'both'
) => {
  const timestamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
  const baseFilename = `${title.toLowerCase().replace(/\s+/g, '-')}_${timestamp}`;
  
  try {
    if (format === 'png' || format === 'both') {
      exportChartAsPNG(chartElement, baseFilename);
    }
    
    if (format === 'csv' || format === 'both') {
      const csvData = plotlyDataToCSV(plotlyData);
      if (csvData.length > 0) {
        exportDataAsCSV(csvData, baseFilename);
      }
    }
  } catch (error) {
    console.error('Export failed:', error);
    throw error;
  }
};

// Global window type declaration for Plotly
declare global {
  interface Window {
    Plotly: any;
  }
}