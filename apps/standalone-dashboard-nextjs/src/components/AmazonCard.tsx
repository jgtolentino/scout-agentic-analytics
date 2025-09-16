"use client";

import React from 'react';
import clsx from 'clsx';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export function Card({ children, className = '' }: CardProps) {
  return (
    <div className={clsx(
      "bg-white rounded-lg border border-gray-200 p-6 shadow-sm hover:shadow-md transition-shadow",
      "amazon-card", 
      className
    )}>
      {children}
    </div>
  );
}

interface KPIProps {
  title?: string;
  label?: string; // Support both title and label for compatibility
  value: string | number;
  subtitle?: string;
  hint?: string; // Support both subtitle and hint for compatibility
  trend?: 'up' | 'down' | 'flat';
  trendValue?: string;
}

export function KPI({ title, label, value, subtitle, hint, trend, trendValue }: KPIProps) {
  const displayTitle = title || label;
  const displaySubtitle = subtitle || hint;
  
  const trendColor = trend === 'up' ? 'text-green-600' : trend === 'down' ? 'text-red-600' : 'text-gray-500';
  const trendIcon = trend === 'up' ? '↗' : trend === 'down' ? '↘' : '→';

  return (
    <div className="text-center" role="region" aria-labelledby={displayTitle ? `kpi-${displayTitle.replace(/\s+/g, '-').toLowerCase()}` : undefined}>
      {displayTitle && <h3 id={`kpi-${displayTitle.replace(/\s+/g, '-').toLowerCase()}`} className="text-sm font-medium text-gray-500 mb-2">{displayTitle}</h3>}
      <div className="text-3xl font-bold text-gray-900 mb-1" aria-label={`Value: ${value}`}>{value}</div>
      {displaySubtitle && <p className="text-xs text-gray-600 mb-1">{displaySubtitle}</p>}
      {trend && trendValue && (
        <p className={clsx("text-xs flex items-center justify-center gap-1", trendColor)} 
           aria-label={`Trend ${trend}: ${trendValue}`}>
          <span aria-hidden="true">{trendIcon}</span>
          {trendValue}
        </p>
      )}
    </div>
  );
}

export function Skeleton({ className = '' }: { className?: string }) {
  return (
    <div className={clsx("animate-pulse bg-gray-200 rounded", className)}>
      <div className="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>
      <div className="h-2 bg-gray-300 rounded w-1/2"></div>
    </div>
  );
}

interface ErrorBoxProps {
  message: string;
}

export function ErrorBox({ message }: ErrorBoxProps) {
  return (
    <div className="bg-red-50 border border-red-200 rounded-lg p-4">
      <div className="flex">
        <div className="text-red-400">
          <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
          </svg>
        </div>
        <div className="ml-3">
          <h3 className="text-sm font-medium text-red-800">Error</h3>
          <div className="mt-2 text-sm text-red-700">
            <p>{message}</p>
          </div>
        </div>
      </div>
    </div>
  );
}