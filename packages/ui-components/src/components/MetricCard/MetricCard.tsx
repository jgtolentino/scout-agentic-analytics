/**
 * Scout MetricCard Component (Original)
 * Simple metric card component for Scout dashboard
 */

import React from 'react';

export interface MetricCardProps {
  title: string;
  value: string | number;
  change?: string;
  trend?: 'up' | 'down' | 'neutral';
  variant?: 'default' | 'compact' | 'detailed';
  icon?: React.ReactNode;
  prefix?: string;
}

export const MetricCard: React.FC<MetricCardProps> = ({
  title,
  value,
  change,
  trend = 'neutral',
  variant = 'default',
  icon,
  prefix = '',
}) => {
  const cardStyle: React.CSSProperties = {
    backgroundColor: 'white',
    borderRadius: '8px',
    padding: variant === 'compact' ? '16px' : '24px',
    boxShadow: '0 1px 3px rgba(0, 0, 0, 0.1)',
    border: '1px solid #e5e7eb',
  };

  const titleStyle: React.CSSProperties = {
    fontSize: '14px',
    fontWeight: 500,
    color: '#6b7280',
    marginBottom: '8px',
  };

  const valueStyle: React.CSSProperties = {
    fontSize: variant === 'compact' ? '20px' : '24px',
    fontWeight: 'bold',
    color: '#111827',
    marginBottom: change ? '4px' : 0,
  };

  const changeStyle: React.CSSProperties = {
    fontSize: '12px',
    fontWeight: 500,
    color: trend === 'up' ? '#10b981' : trend === 'down' ? '#ef4444' : '#6b7280',
  };

  return (
    <div style={cardStyle}>
      {icon && (
        <div style={{ marginBottom: '8px', color: '#6b7280' }}>
          {icon}
        </div>
      )}
      <div style={titleStyle}>{title}</div>
      <div style={valueStyle}>
        {prefix}{typeof value === 'number' ? value.toLocaleString() : value}
      </div>
      {change && (
        <div style={changeStyle}>
          {trend === 'up' ? '↗' : trend === 'down' ? '↘' : '→'} {change}
        </div>
      )}
    </div>
  );
};