/**
 * UI Components Library - Main Export Index
 * Includes both Scout and Amazon dashboard components
 */

// Scout Components (existing)
export { MetricCard } from './MetricCard/MetricCard';
export type { MetricCardProps } from './MetricCard/MetricCard';

export { LoadingSpinner } from './LoadingSpinner/LoadingSpinner';
export type { LoadingSpinnerProps } from './LoadingSpinner/LoadingSpinner';

export { ErrorBoundary } from './ErrorBoundary/ErrorBoundary';
export type { ErrorBoundaryProps } from './ErrorBoundary/ErrorBoundary';

// Amazon Layout Components (new)
export { AmazonLayout } from './AmazonLayout/Layout';
export type { AmazonLayoutProps } from './AmazonLayout/Layout';

export { Sidebar } from './AmazonLayout/Sidebar';
export type { SidebarProps } from './AmazonLayout/Sidebar';

export { AmazonDropdown } from './AmazonLayout/AmazonDropdown';
export type { AmazonDropdownProps, DropdownOption } from './AmazonLayout/AmazonDropdown';

// Amazon Card Components (new)
export { AmazonMetricCard } from './AmazonCards/AmazonMetricCard';
export type { AmazonMetricCardProps } from './AmazonCards/AmazonMetricCard';

export { AmazonChartCard } from './AmazonCards/AmazonChartCard';
export type { AmazonChartCardProps } from './AmazonCards/AmazonChartCard';

// Hooks
export { useScoutData } from '../hooks/useScoutData';
export type { ScoutFilters, ScoutMetrics } from '../hooks/useScoutData';

export { useAmazonCharts } from '../hooks/useAmazonCharts';
export type { ChartData, UseAmazonChartsOptions } from '../hooks/useAmazonCharts';

// Design Tokens
export { amazonTokens } from '../tokens/amazon-design-tokens';
export type { AmazonTokens } from '../tokens/amazon-design-tokens';