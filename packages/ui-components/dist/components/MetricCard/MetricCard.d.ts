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
export declare const MetricCard: React.FC<MetricCardProps>;
