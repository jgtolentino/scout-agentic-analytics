/**
 * Amazon Metric Card Component
 * Migrated from Dash create_card function to React
 */
import React from 'react';
export interface AmazonMetricCardProps {
    title: string;
    value: string | number;
    icon: string;
    id?: string;
    className?: string;
    variant?: 'default' | 'compact';
}
export declare const AmazonMetricCard: React.FC<AmazonMetricCardProps>;
