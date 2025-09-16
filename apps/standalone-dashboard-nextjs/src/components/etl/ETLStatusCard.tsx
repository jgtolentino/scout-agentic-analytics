"use client";

import React from 'react';
import { Card } from '@/components/AmazonCard';
import { useETLStatus, ETLStatus } from '@/lib/hooks/useETL';
import clsx from 'clsx';

interface ETLStatusCardProps {
  className?: string;
  maxItems?: number;
}

const StatusBadge = ({ status }: { status: ETLStatus['status'] }) => {
  const statusConfig = {
    pending: { color: 'bg-yellow-100 text-yellow-800', icon: '⏳', label: 'Pending' },
    running: { color: 'bg-blue-100 text-blue-800', icon: '⚡', label: 'Running' },
    completed: { color: 'bg-green-100 text-green-800', icon: '✅', label: 'Completed' },
    failed: { color: 'bg-red-100 text-red-800', icon: '❌', label: 'Failed' }
  };

  const config = statusConfig[status];
  return (
    <span className={clsx('inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium gap-1', config.color)}>
      <span>{config.icon}</span>
      {config.label}
    </span>
  );
};

const ProgressBar = ({ percentage }: { percentage: number }) => {
  return (
    <div className="w-full bg-gray-200 rounded-full h-2">
      <div 
        className="bg-orange-600 h-2 rounded-full transition-all duration-300"
        style={{ width: `${Math.min(100, Math.max(0, percentage))}%` }}
      />
    </div>
  );
};

const formatDuration = (startTime: string, endTime?: string) => {
  const start = new Date(startTime);
  const end = endTime ? new Date(endTime) : new Date();
  const diffMs = end.getTime() - start.getTime();
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  
  if (diffMinutes > 0) {
    return `${diffMinutes}m ${diffSeconds % 60}s`;
  }
  return `${diffSeconds}s`;
};

export default function ETLStatusCard({ className, maxItems = 10 }: ETLStatusCardProps) {
  const { data: statusList, isLoading, error, refetch } = useETLStatus();

  const displayItems = statusList?.slice(0, maxItems) || [];

  return (
    <Card className={clsx('h-fit', className)}>
      <div className="space-y-4">
        <div className="flex items-center justify-between border-b border-gray-200 pb-4">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">Pipeline Status</h3>
            <p className="text-sm text-gray-600">Real-time ETL pipeline monitoring</p>
          </div>
          <button
            onClick={() => refetch()}
            disabled={isLoading}
            className="p-2 text-gray-400 hover:text-gray-600 transition-colors disabled:opacity-50"
            title="Refresh status"
          >
            <svg 
              className={clsx("w-5 h-5", isLoading && "animate-spin")} 
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24"
            >
              <path 
                strokeLinecap="round" 
                strokeLinejoin="round" 
                strokeWidth={2} 
                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" 
              />
            </svg>
          </button>
        </div>

        {isLoading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="animate-pulse">
                <div className="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>
                <div className="h-2 bg-gray-300 rounded w-1/2"></div>
              </div>
            ))}
          </div>
        ) : error ? (
          <div className="text-center py-8">
            <div className="text-red-400 mb-2">
              <svg className="h-8 w-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <p className="text-sm text-red-600 mb-3">Failed to load pipeline status</p>
            <button
              onClick={() => refetch()}
              className="text-xs bg-red-100 text-red-600 px-3 py-1 rounded-md hover:bg-red-200 transition-colors"
            >
              Retry
            </button>
          </div>
        ) : displayItems.length === 0 ? (
          <div className="text-center py-8">
            <div className="text-gray-400 mb-2">
              <svg className="h-8 w-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
            </div>
            <p className="text-sm text-gray-500">No pipeline activity yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {displayItems.map((status, index) => (
              <div key={status.pipeline_id} className="border border-gray-200 rounded-lg p-3 hover:bg-gray-50 transition-colors">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-sm text-gray-600">
                      #{status.pipeline_id.slice(-6)}
                    </span>
                    <StatusBadge status={status.status} />
                  </div>
                  <div className="text-xs text-gray-500">
                    {status.started_at && formatDuration(status.started_at, status.completed_at)}
                  </div>
                </div>

                {/* Progress bar for running jobs */}
                {status.status === 'running' && status.progress_percentage !== undefined && (
                  <div className="mb-2">
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs text-gray-500">Progress</span>
                      <span className="text-xs font-medium">{status.progress_percentage}%</span>
                    </div>
                    <ProgressBar percentage={status.progress_percentage} />
                  </div>
                )}

                {/* Metadata display */}
                {status.metadata && (
                  <div className="text-xs text-gray-600 space-y-1">
                    {status.metadata.dataset && (
                      <div className="flex justify-between">
                        <span>Dataset:</span>
                        <span className="font-mono">{status.metadata.dataset}</span>
                      </div>
                    )}
                    {status.metadata.format && (
                      <div className="flex justify-between">
                        <span>Format:</span>
                        <span className="font-mono">{status.metadata.format}</span>
                      </div>
                    )}
                    {status.metadata.destination && (
                      <div className="flex justify-between">
                        <span>Destination:</span>
                        <span className="font-mono text-xs truncate max-w-32">{status.metadata.destination}</span>
                      </div>
                    )}
                  </div>
                )}

                {/* Error message */}
                {status.error_message && (
                  <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded text-xs text-red-700">
                    <span className="font-medium">Error:</span> {status.error_message}
                  </div>
                )}

                {/* Completion time */}
                {status.completed_at && (
                  <div className="mt-2 text-xs text-gray-500">
                    Completed: {new Date(status.completed_at).toLocaleString()}
                  </div>
                )}
              </div>
            ))}

            {statusList && statusList.length > maxItems && (
              <div className="text-center pt-2">
                <span className="text-xs text-gray-500">
                  Showing {maxItems} of {statusList.length} pipelines
                </span>
              </div>
            )}
          </div>
        )}

        {/* Summary Stats */}
        {statusList && statusList.length > 0 && (
          <div className="border-t border-gray-200 pt-4">
            <div className="grid grid-cols-4 gap-4 text-center">
              <div>
                <div className="text-lg font-semibold text-gray-900">
                  {statusList.filter(s => s.status === 'completed').length}
                </div>
                <div className="text-xs text-gray-500">Completed</div>
              </div>
              <div>
                <div className="text-lg font-semibold text-blue-600">
                  {statusList.filter(s => s.status === 'running').length}
                </div>
                <div className="text-xs text-gray-500">Running</div>
              </div>
              <div>
                <div className="text-lg font-semibold text-yellow-600">
                  {statusList.filter(s => s.status === 'pending').length}
                </div>
                <div className="text-xs text-gray-500">Pending</div>
              </div>
              <div>
                <div className="text-lg font-semibold text-red-600">
                  {statusList.filter(s => s.status === 'failed').length}
                </div>
                <div className="text-xs text-gray-500">Failed</div>
              </div>
            </div>
          </div>
        )}
      </div>
    </Card>
  );
}