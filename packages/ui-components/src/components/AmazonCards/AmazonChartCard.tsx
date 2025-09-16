/**
 * Amazon Chart Card Component
 * Migrated from Dash dcc.Graph + Loading to React/Plotly.js
 */

import React, { useState } from 'react';
import { amazonTokens } from '../../tokens/amazon-design-tokens';

export interface AmazonChartCardProps {
  id?: string;
  figure: any; // Plotly figure object
  height?: string | number;
  loading?: boolean;
  loadingType?: 'circle' | 'dot' | 'default';
  loadingColor?: string;
  className?: string;
  config?: Partial<Plotly.Config>;
}

export const AmazonChartCard: React.FC<AmazonChartCardProps> = ({
  id,
  figure,
  height = amazonTokens.components.chart.height,
  loading = false,
  loadingType = 'circle',
  loadingColor = amazonTokens.components.chart.loadingColor,
  className = '',
  config = { displayModeBar: false },
}) => {
  const [isLoading, setIsLoading] = useState(loading);

  const cardStyle: React.CSSProperties = {
    border: `2px solid ${amazonTokens.colors.border}`,
    borderRadius: amazonTokens.borderRadius.card,
    boxShadow: amazonTokens.shadows.chart,
    backgroundColor: amazonTokens.colors.cardBackground,
    height: typeof height === 'string' ? height : `${height}px`,
    position: 'relative',
    overflow: 'hidden',
  };

  const loadingStyle: React.CSSProperties = {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
    zIndex: 10,
  };

  const spinnerStyle: React.CSSProperties = {
    width: '40px',
    height: '40px',
    border: `4px solid ${amazonTokens.colors.accent}`,
    borderTop: `4px solid ${loadingColor}`,
    borderRadius: '50%',
    animation: 'spin 1s linear infinite',
  };

  return (
    <div
      className={`amazon-chart-card ${className}`}
      style={cardStyle}
      id={id}
    >
      {(isLoading || loading) && (
        <div style={loadingStyle}>
          {loadingType === 'circle' && (
            <div style={spinnerStyle} />
          )}
          {loadingType === 'dot' && (
            <div style={{ 
              display: 'flex', 
              gap: '4px',
              alignItems: 'center' 
            }}>
              {[1, 2, 3].map((i) => (
                <div
                  key={i}
                  style={{
                    width: '8px',
                    height: '8px',
                    backgroundColor: loadingColor,
                    borderRadius: '50%',
                    animation: `bounce 1.4s ease-in-out ${i * 0.16}s infinite both`,
                  }}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {figure && (
        <div 
          id={`chart-${id}`}
          style={{
            width: '100%',
            height: '100%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: amazonTokens.colors.textPrimary,
            fontFamily: amazonTokens.typography.fontFamily,
          }}
        >
          {/* Placeholder for Plotly.js chart - implement in consuming app */}
          Chart placeholder - implement with react-plotly.js
        </div>
      )}

      <style>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }

        @keyframes bounce {
          0%, 80%, 100% {
            transform: scale(0);
          }
          40% {
            transform: scale(1);
          }
        }
      `}</style>
    </div>
  );
};