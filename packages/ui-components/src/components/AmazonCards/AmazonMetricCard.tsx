/**
 * Amazon Metric Card Component
 * Migrated from Dash create_card function to React
 */

import React from 'react';
import { amazonTokens } from '../../tokens/amazon-design-tokens';

export interface AmazonMetricCardProps {
  title: string;
  value: string | number;
  icon: string; // FontAwesome class like "fa-list", "fa-coins", "fa-tags"
  id?: string;
  className?: string;
  variant?: 'default' | 'compact';
}

export const AmazonMetricCard: React.FC<AmazonMetricCardProps> = ({
  title,
  value,
  icon,
  id,
  className = '',
  variant = 'default',
}) => {
  const cardStyle: React.CSSProperties = {
    border: `1px solid ${amazonTokens.colors.border}`,
    borderRadius: amazonTokens.borderRadius.card,
    textAlign: 'left',
    boxShadow: amazonTokens.shadows.card,
    backgroundColor: amazonTokens.colors.cardBackground,
    marginBottom: amazonTokens.spacing.medium,
  };

  const cardBodyStyle: React.CSSProperties = {
    padding: variant === 'compact' ? '15px' : amazonTokens.components.card.padding,
    color: amazonTokens.colors.textPrimary,
  };

  const iconStyle: React.CSSProperties = {
    fontSize: variant === 'compact' ? '20px' : amazonTokens.components.icon.size,
    marginRight: variant === 'compact' ? '15px' : amazonTokens.components.icon.marginRight,
    marginBottom: variant === 'compact' ? '10px' : amazonTokens.components.icon.marginBottom,
    color: amazonTokens.colors.primary,
  };

  const titleStyle: React.CSSProperties = {
    whiteSpace: 'nowrap',
    fontSize: variant === 'compact' ? '16px' : amazonTokens.typography.fontSize.subtitleSmall,
    fontWeight: amazonTokens.typography.fontWeight.normal,
    margin: 0,
    marginBottom: '0.5rem',
  };

  const valueStyle: React.CSSProperties = {
    fontSize: variant === 'compact' ? '18px' : '24px',
    fontWeight: amazonTokens.typography.fontWeight.bold,
    margin: 0,
    color: amazonTokens.colors.textPrimary,
  };

  return (
    <div 
      className={`amazon-metric-card ${className}`} 
      style={cardStyle}
      id={id}
    >
      <div style={cardBodyStyle}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
          }}
        >
          <i
            className={`fas ${icon}`}
            style={iconStyle}
          />
          <h3 style={titleStyle}>{title}</h3>
        </div>
        <h4 style={valueStyle}>
          {typeof value === 'number' ? value.toLocaleString() : value}
        </h4>
      </div>
    </div>
  );
};