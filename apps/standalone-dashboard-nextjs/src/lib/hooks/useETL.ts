import { useState } from 'react';
import { useMutation, useQuery, UseQueryOptions } from '@tanstack/react-query';

export interface ExportRequest {
  dataset: string;
  format: 'CSV' | 'JSONL';
  dateRange?: {
    start?: string;
    end?: string;
  };
}

export interface MirrorRequest {
  source_path: string;
  destination_bucket?: string;
  destination_prefix?: string;
}

export interface ETLStatus {
  pipeline_id: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  started_at?: string;
  completed_at?: string;
  error_message?: string;
  progress_percentage?: number;
  metadata?: Record<string, any>;
}

export interface ExportResponse {
  success: boolean;
  file_path?: string;
  download_url?: string;
  error?: string;
  metadata?: {
    rows_exported: number;
    file_size: number;
    export_timestamp: string;
  };
}

export interface MirrorResponse {
  success: boolean;
  s3_path?: string;
  error?: string;
  metadata?: {
    files_synced: number;
    total_size: number;
    sync_timestamp: string;
  };
}

// Dataset options for the UI
export const DATASETS = [
  { value: 'gold_brand_performance', label: 'Gold: Brand Performance' },
  { value: 'gold_category_trends', label: 'Gold: Category Trends' },
  { value: 'gold_customer_segments', label: 'Gold: Customer Segments' },
  { value: 'gold_product_analytics', label: 'Gold: Product Analytics' },
  { value: 'silver_transactions', label: 'Silver: Transactions' },
  { value: 'silver_customer_data', label: 'Silver: Customer Data' },
  { value: 'silver_product_catalog', label: 'Silver: Product Catalog' },
  { value: 'bronze_raw_transactions', label: 'Bronze: Raw Transactions' },
];

// Hook for exporting data to Storage
export function useExportToStorage() {
  const [isExporting, setIsExporting] = useState(false);
  
  const exportMutation = useMutation({
    mutationFn: async (request: ExportRequest): Promise<ExportResponse> => {
      setIsExporting(true);
      
      const azureBase = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE || 'https://fn-scout-readonly.azurewebsites.net/api';

      const response = await fetch(`${azureBase}/export-to-storage`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-functions-key': process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY || '',
        },
        body: JSON.stringify(request),
      });
      
      if (!response.ok) {
        throw new Error(`Export failed: ${response.statusText}`);
      }
      
      return response.json();
    },
    onSettled: () => {
      setIsExporting(false);
    },
  });

  return {
    exportData: exportMutation.mutate,
    exportAsync: exportMutation.mutateAsync,
    isExporting: isExporting || exportMutation.isPending,
    error: exportMutation.error,
    data: exportMutation.data,
    isSuccess: exportMutation.isSuccess,
    reset: exportMutation.reset,
  };
}

// Hook for mirroring data to S3
export function useMirrorToS3() {
  const [isMirroring, setIsMirroring] = useState(false);
  
  const mirrorMutation = useMutation({
    mutationFn: async (request: MirrorRequest): Promise<MirrorResponse> => {
      setIsMirroring(true);
      
      const azureBase = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE || 'https://fn-scout-readonly.azurewebsites.net/api';

      const response = await fetch(`${azureBase}/mirror-to-s3`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-functions-key': process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY || '',
        },
        body: JSON.stringify(request),
      });
      
      if (!response.ok) {
        throw new Error(`Mirror failed: ${response.statusText}`);
      }
      
      return response.json();
    },
    onSettled: () => {
      setIsMirroring(false);
    },
  });

  return {
    mirrorData: mirrorMutation.mutate,
    mirrorAsync: mirrorMutation.mutateAsync,
    isMirroring: isMirroring || mirrorMutation.isPending,
    error: mirrorMutation.error,
    data: mirrorMutation.data,
    isSuccess: mirrorMutation.isSuccess,
    reset: mirrorMutation.reset,
  };
}

// Hook for monitoring ETL status
export function useETLStatus(pipelineId?: string, options?: UseQueryOptions<ETLStatus[]>) {
  return useQuery({
    queryKey: ['etl-status', pipelineId],
    queryFn: async (): Promise<ETLStatus[]> => {
      // For development, return mock data
      if (process.env.NEXT_PUBLIC_USE_MOCK === '1') {
        return [
          {
            pipeline_id: 'export-001',
            status: 'completed',
            started_at: new Date(Date.now() - 300000).toISOString(),
            completed_at: new Date().toISOString(),
            progress_percentage: 100,
            metadata: { dataset: 'gold_brand_performance', format: 'CSV' }
          },
          {
            pipeline_id: 'mirror-002',
            status: 'running',
            started_at: new Date(Date.now() - 120000).toISOString(),
            progress_percentage: 65,
            metadata: { destination: 's3://scout-data/mirror/' }
          },
          {
            pipeline_id: 'export-003',
            status: 'failed',
            started_at: new Date(Date.now() - 600000).toISOString(),
            completed_at: new Date(Date.now() - 550000).toISOString(),
            error_message: 'Dataset not found',
            metadata: { dataset: 'invalid_dataset' }
          }
        ];
      }
      
      // In production, call actual status endpoint
      const azureBase = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE || 'https://fn-scout-readonly.azurewebsites.net/api';
      const response = await fetch(`${azureBase}/etl-status${pipelineId ? `?pipeline_id=${pipelineId}` : ''}`, {
        headers: {
          'x-functions-key': process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY || '',
        },
      });
      
      if (!response.ok) {
        throw new Error(`Status fetch failed: ${response.statusText}`);
      }
      
      return response.json();
    },
    refetchInterval: 5000, // Refresh every 5 seconds
    enabled: true,
    ...options,
  });
}

// Hook for generating dashboard links
export function useDashboardLink() {
  const generateLink = (dataset?: string, filters?: Record<string, any>) => {
    const azureBase = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE || 'https://fn-scout-readonly.azurewebsites.net/api';

    const params = new URLSearchParams();
    if (dataset) params.set('dataset', dataset);
    if (filters) params.set('filters', JSON.stringify(filters));

    const queryString = params.toString();
    return `${azureBase}/dashboard${queryString ? `?${queryString}` : ''}`;
  };
  
  const openDashboard = (dataset?: string, filters?: Record<string, any>) => {
    const url = generateLink(dataset, filters);
    window.open(url, '_blank', 'width=1200,height=800');
  };
  
  return {
    generateLink,
    openDashboard,
  };
}