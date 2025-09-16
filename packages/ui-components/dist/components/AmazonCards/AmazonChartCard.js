import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
/**
 * Amazon Chart Card Component
 * Migrated from Dash dcc.Graph + Loading to React/Plotly.js
 */
import { useState } from 'react';
import { amazonTokens } from '../../tokens/amazon-design-tokens';
export const AmazonChartCard = ({ id, figure, height = amazonTokens.components.chart.height, loading = false, loadingType = 'circle', loadingColor = amazonTokens.components.chart.loadingColor, className = '', config = { displayModeBar: false }, }) => {
    const [isLoading, setIsLoading] = useState(loading);
    const cardStyle = {
        border: `2px solid ${amazonTokens.colors.border}`,
        borderRadius: amazonTokens.borderRadius.card,
        boxShadow: amazonTokens.shadows.chart,
        backgroundColor: amazonTokens.colors.cardBackground,
        height: typeof height === 'string' ? height : `${height}px`,
        position: 'relative',
        overflow: 'hidden',
    };
    const loadingStyle = {
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
    const spinnerStyle = {
        width: '40px',
        height: '40px',
        border: `4px solid ${amazonTokens.colors.accent}`,
        borderTop: `4px solid ${loadingColor}`,
        borderRadius: '50%',
        animation: 'spin 1s linear infinite',
    };
    return (_jsxs("div", { className: `amazon-chart-card ${className}`, style: cardStyle, id: id, children: [(isLoading || loading) && (_jsxs("div", { style: loadingStyle, children: [loadingType === 'circle' && (_jsx("div", { style: spinnerStyle })), loadingType === 'dot' && (_jsx("div", { style: {
                            display: 'flex',
                            gap: '4px',
                            alignItems: 'center'
                        }, children: [1, 2, 3].map((i) => (_jsx("div", { style: {
                                width: '8px',
                                height: '8px',
                                backgroundColor: loadingColor,
                                borderRadius: '50%',
                                animation: `bounce 1.4s ease-in-out ${i * 0.16}s infinite both`,
                            } }, i))) }))] })), figure && (_jsx("div", { id: `chart-${id}`, style: {
                    width: '100%',
                    height: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: amazonTokens.colors.textPrimary,
                    fontFamily: amazonTokens.typography.fontFamily,
                }, children: "Chart placeholder - implement with react-plotly.js" })), _jsx("style", { children: `
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
      ` })] }));
};
