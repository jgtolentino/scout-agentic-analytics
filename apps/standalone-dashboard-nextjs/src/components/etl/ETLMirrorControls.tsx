"use client";

import React, { useState } from 'react';
import { Card } from '@/components/AmazonCard';
import { useMirrorToS3, MirrorRequest } from '@/lib/hooks/useETL';
import toast from 'react-hot-toast';

interface ETLMirrorControlsProps {
  className?: string;
  onMirrorComplete?: (result: any) => void;
}

export default function ETLMirrorControls({ className, onMirrorComplete }: ETLMirrorControlsProps) {
  const [sourcePath, setSourcePath] = useState('');
  const [destinationBucket, setDestinationBucket] = useState('scout-data');
  const [destinationPrefix, setDestinationPrefix] = useState('mirror/');
  const [useCustomSettings, setUseCustomSettings] = useState(false);

  const { mirrorData, isMirroring, error, data, isSuccess, reset } = useMirrorToS3();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!sourcePath) {
      toast.error('Please specify a source path');
      return;
    }

    const mirrorRequest: MirrorRequest = {
      source_path: sourcePath,
    };

    // Add custom S3 settings if specified
    if (useCustomSettings) {
      if (destinationBucket) {
        mirrorRequest.destination_bucket = destinationBucket;
      }
      if (destinationPrefix) {
        mirrorRequest.destination_prefix = destinationPrefix;
      }
    }

    try {
      await mirrorData(mirrorRequest);
      toast.success('Mirror operation started successfully!');
      onMirrorComplete?.(data);
    } catch (err) {
      toast.error('Mirror failed: ' + (err as Error).message);
    }
  };

  const handleReset = () => {
    setSourcePath('');
    setDestinationBucket('scout-data');
    setDestinationPrefix('mirror/');
    setUseCustomSettings(false);
    reset();
  };

  const commonSourcePaths = [
    { label: 'All Export Files', value: 'exports/' },
    { label: 'Gold Layer Exports', value: 'exports/gold/' },
    { label: 'Silver Layer Exports', value: 'exports/silver/' },
    { label: 'Bronze Layer Exports', value: 'exports/bronze/' },
    { label: 'Latest Export', value: 'exports/latest/' },
  ];

  return (
    <Card className={className}>
      <div className="space-y-4">
        <div className="border-b border-gray-200 pb-4">
          <h3 className="text-lg font-semibold text-gray-900">Mirror to S3</h3>
          <p className="text-sm text-gray-600">Sync exported data from Supabase Storage to AWS S3</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Source Path Selection */}
          <div>
            <label htmlFor="sourcePath" className="block text-sm font-medium text-gray-700 mb-2">
              Source Path in Supabase Storage
            </label>
            <input
              type="text"
              id="sourcePath"
              value={sourcePath}
              onChange={(e) => setSourcePath(e.target.value)}
              placeholder="e.g., exports/gold/brand_performance/"
              disabled={isMirroring}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500 font-mono text-sm"
            />
            <p className="mt-1 text-xs text-gray-500">
              Path to files in Supabase Storage (relative to bucket root)
            </p>
          </div>

          {/* Common Source Paths */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Quick Select
            </label>
            <div className="flex flex-wrap gap-2">
              {commonSourcePaths.map((path) => (
                <button
                  key={path.value}
                  type="button"
                  onClick={() => setSourcePath(path.value)}
                  disabled={isMirroring}
                  className="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200 disabled:bg-gray-50 disabled:cursor-not-allowed transition-colors"
                >
                  {path.label}
                </button>
              ))}
            </div>
          </div>

          {/* Custom S3 Settings Toggle */}
          <div>
            <label className="flex items-center">
              <input
                type="checkbox"
                checked={useCustomSettings}
                onChange={(e) => setUseCustomSettings(e.target.checked)}
                disabled={isMirroring}
                className="mr-2 text-orange-600 focus:ring-orange-500"
              />
              <span className="text-sm font-medium text-gray-700">Use custom S3 destination settings</span>
            </label>
          </div>

          {/* Custom S3 Settings */}
          {useCustomSettings && (
            <div className="space-y-4 p-4 bg-gray-50 rounded-lg border border-gray-200">
              <div>
                <label htmlFor="destinationBucket" className="block text-sm font-medium text-gray-700 mb-2">
                  S3 Bucket Name
                </label>
                <input
                  type="text"
                  id="destinationBucket"
                  value={destinationBucket}
                  onChange={(e) => setDestinationBucket(e.target.value)}
                  placeholder="scout-data"
                  disabled={isMirroring}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500 font-mono text-sm"
                />
              </div>
              <div>
                <label htmlFor="destinationPrefix" className="block text-sm font-medium text-gray-700 mb-2">
                  S3 Key Prefix
                </label>
                <input
                  type="text"
                  id="destinationPrefix"
                  value={destinationPrefix}
                  onChange={(e) => setDestinationPrefix(e.target.value)}
                  placeholder="mirror/"
                  disabled={isMirroring}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500 font-mono text-sm"
                />
                <p className="mt-1 text-xs text-gray-500">
                  Prefix for S3 keys (e.g., "mirror/" → s3://bucket/mirror/...)
                </p>
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3 pt-4">
            <button
              type="submit"
              disabled={isMirroring || !sourcePath}
              className="flex-1 px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-600 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
            >
              {isMirroring ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                  Syncing...
                </>
              ) : (
                <>
                  <span>☁️</span>
                  Mirror to S3
                </>
              )}
            </button>
            <button
              type="button"
              onClick={handleReset}
              disabled={isMirroring}
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
                <h4 className="text-sm font-medium text-green-800">Mirror Completed!</h4>
                <div className="mt-2 text-sm text-green-700">
                  {data.s3_path && (
                    <p>Files synced to: <span className="font-mono text-xs">{data.s3_path}</span></p>
                  )}
                  {data.metadata && (
                    <div className="mt-2 space-y-1">
                      <p>Files synced: {data.metadata.files_synced?.toLocaleString()}</p>
                      <p>Total size: {data.metadata.total_size ? `${(data.metadata.total_size / 1024 / 1024).toFixed(2)} MB` : 'Unknown'}</p>
                      <p>Sync time: {data.metadata.sync_timestamp}</p>
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
                <h4 className="text-sm font-medium text-red-800">Mirror Failed</h4>
                <div className="mt-2 text-sm text-red-700">
                  <p>{error.message}</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* S3 Configuration Info */}
        <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
          <div className="flex">
            <div className="text-yellow-400">
              <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <h4 className="text-sm font-medium text-yellow-800">S3 Configuration Required</h4>
              <div className="mt-2 text-sm text-yellow-700 space-y-1">
                <p>• Ensure AWS credentials are configured in the function environment</p>
                <p>• S3 bucket must exist and be accessible</p>
                <p>• IAM permissions required: s3:PutObject, s3:ListBucket</p>
                <p>• Large files may take time to sync - monitor status for progress</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Card>
  );
}