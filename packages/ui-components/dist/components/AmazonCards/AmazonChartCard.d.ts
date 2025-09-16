/**
 * Amazon Chart Card Component
 * Migrated from Dash dcc.Graph + Loading to React/Plotly.js
 */
import React from 'react';
export interface AmazonChartCardProps {
    id?: string;
    figure: any;
    height?: string | number;
    loading?: boolean;
    loadingType?: 'circle' | 'dot' | 'default';
    loadingColor?: string;
    className?: string;
    config?: Partial<Plotly.Config>;
}
export declare const AmazonChartCard: React.FC<AmazonChartCardProps>;
