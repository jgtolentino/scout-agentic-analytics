import React from 'react';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { clsx } from 'clsx';

export interface MetricCardProps {
  title: string;
  value: string | number;
  change?: string;
  trend?: 'up' | 'down' | 'neutral';
  prefix?: string;
  suffix?: string;
  subtitle?: string;
  icon?: React.ReactNode;
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  showProgressBar?: boolean;
  progressValue?: number;
  variant?: 'default' | 'compact' | 'detailed';
}

export default function MetricCard({
  title,
  value,
  change,
  trend = 'neutral',
  prefix = '',
  suffix = '',
  subtitle,
  icon,
  className,
  size = 'md',
  showProgressBar = false,
  progressValue,
  variant = 'default'
}: MetricCardProps) {
  const trendConfig = {
    up: {
      color: 'text-green-600',
      bg: 'bg-green-100',
      icon: TrendingUp
    },
    down: {
      color: 'text-red-600',
      bg: 'bg-red-100',
      icon: TrendingDown
    },
    neutral: {
      color: 'text-gray-600',
      bg: 'bg-gray-100',
      icon: Minus
    }
  };

  const sizeConfig = {
    sm: {
      card: 'p-3',
      title: 'text-xs',
      value: 'text-lg',
      change: 'text-xs',
      icon: 12
    },
    md: {
      card: 'p-4',
      title: 'text-sm',
      value: 'text-2xl',
      change: 'text-sm',
      icon: 14
    },
    lg: {
      card: 'p-6',
      title: 'text-base',
      value: 'text-3xl',
      change: 'text-base',
      icon: 16
    }
  };

  const config = sizeConfig[size];
  const trendTheme = trendConfig[trend];
  const TrendIcon = trendTheme.icon;

  const cardClasses = clsx(
    'bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow duration-200',
    config.card,
    className
  );

  const renderCompact = () => (
    <div className={cardClasses}>
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            {icon && <div className="text-gray-400">{icon}</div>}
            <p className={clsx('font-medium text-gray-600', config.title)}>{title}</p>
          </div>
          <p className={clsx('font-bold text-gray-900 mt-1', config.value)}>
            {prefix}{value}{suffix}
          </p>
        </div>
        {change && (
          <div className={clsx('flex items-center gap-1 px-2 py-1 rounded-full', trendTheme.bg)}>
            <TrendIcon size={config.icon} className={trendTheme.color} />
            <span className={clsx('font-medium', trendTheme.color, config.change)}>
              {change}
            </span>
          </div>
        )}
      </div>
    </div>
  );

  const renderDefault = () => (
    <div className={cardClasses}>
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-2">
            {icon && <div className="text-gray-400">{icon}</div>}
            <p className={clsx('font-medium text-gray-600', config.title)}>{title}</p>
          </div>
          <p className={clsx('font-bold text-gray-900 mt-2', config.value)}>
            {prefix}{value}{suffix}
          </p>
          {subtitle && (
            <p className="text-xs text-gray-500 mt-1">{subtitle}</p>
          )}
        </div>
        
        {change && (
          <div className={clsx('flex items-center gap-1 px-2.5 py-0.5 rounded-full', trendTheme.bg)}>
            <TrendIcon size={config.icon} className={trendTheme.color} />
            <span className={clsx('font-medium', trendTheme.color, config.change)}>
              {change}
            </span>
          </div>
        )}
      </div>
      
      {showProgressBar && (
        <div className="mt-4 w-full bg-gray-200 rounded-full h-1.5">
          <div 
            className="bg-blue-500 h-1.5 rounded-full transition-all duration-500"
            style={{ width: `${progressValue || Math.random() * 40 + 60}%` }}
          />
        </div>
      )}
    </div>
  );

  const renderDetailed = () => (
    <div className={cardClasses}>
      <div className="flex items-start justify-between mb-3">
        {icon && <div className="text-gray-400">{icon}</div>}
        {change && (
          <div className={clsx('flex items-center gap-1 px-2.5 py-0.5 rounded-full', trendTheme.bg)}>
            <TrendIcon size={config.icon} className={trendTheme.color} />
            <span className={clsx('font-medium', trendTheme.color, config.change)}>
              {change}
            </span>
          </div>
        )}
      </div>
      
      <div className="space-y-2">
        <p className={clsx('font-medium text-gray-600', config.title)}>{title}</p>
        <p className={clsx('font-bold text-gray-900', config.value)}>
          {prefix}{value}{suffix}
        </p>
        {subtitle && (
          <p className="text-sm text-gray-500">{subtitle}</p>
        )}
      </div>
      
      {showProgressBar && (
        <div className="mt-4 space-y-1">
          <div className="flex justify-between text-xs text-gray-500">
            <span>Progress</span>
            <span>{progressValue || Math.floor(Math.random() * 40 + 60)}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div 
              className="bg-blue-500 h-2 rounded-full transition-all duration-500"
              style={{ width: `${progressValue || Math.random() * 40 + 60}%` }}
            />
          </div>
        </div>
      )}
    </div>
  );

  switch (variant) {
    case 'compact':
      return renderCompact();
    case 'detailed':
      return renderDetailed();
    default:
      return renderDefault();
  }
}