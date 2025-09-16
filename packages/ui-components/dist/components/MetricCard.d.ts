import React from 'react';
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
export default function MetricCard({ title, value, change, trend, prefix, suffix, subtitle, icon, className, size, showProgressBar, progressValue, variant }: MetricCardProps): import("react/jsx-runtime").JSX.Element;
