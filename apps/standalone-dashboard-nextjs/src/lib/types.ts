// Scout Dashboard Analytics Types
// Independent of any database provider (Azure Functions compatible)

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

// Core filter interface for analytics queries
export interface AnalyticsFilters {
  date_preset?: string;
  date_start?: string;
  date_end?: string;
  region?: string;
  province?: string;
  city?: string;
  store?: string;
  category?: string;
  brand?: string;
  sku?: string;
  cohort?: string;
  segment?: string;
  loyalty_tier?: string;
  daypart?: string;
  dow?: string;
  compare_mode?: string;
  compare_entities?: string[];
}

// Analytics data return types
export interface ExecutiveOverview {
  purchases: number;
  total_spend: number;
  top_category: string;
  monthly_trend: { month: string; spend: number }[];
  category_distribution?: { category: string; value: number; share: number }[];
  category_performance?: { category: string; performance: number }[];
}

export interface SKUCounts {
  total: number;
  active: number;
  new: number;
}

export interface ParetoCategory {
  category: string;
  revenue: number;
  percentage: number;
  cumulative: number;
}

export interface BasketPair {
  source: string;
  target: string;
  support: number;
  lift: number;
  confidence: number;
}

export interface BehaviorKPIs {
  conversion_rate: number;
  suggestion_accept_rate: number;
  brand_loyalty_rate: number;
}

export interface RequestMethod {
  method: string;
  count: number;
  percentage: number;
}

export interface AcceptanceByMethod {
  method: string;
  accepted: number;
  total: number;
  rate: number;
}

export interface TopPath {
  path: string;
  users: number;
  conversion_rate: number;
  avg_time: number;
}

export interface GeoMetric {
  region?: string;
  province?: string;
  city?: string;
  code?: string;
  name?: string;
  level?: string;
  value: number;
  users?: number;
  share?: number;
  rank?: number;
}

export interface CompareResult {
  mode: string;
  items: string[];
  metrics: {
    revenue: Record<string, number>;
    transactions: Record<string, number>;
    conversion_rate: Record<string, number>;
  };
  timestamp: string;
}

// Insight types for analytics insights
export interface Insight {
  id: string;
  type: 'anomaly' | 'trend' | 'forecast' | 'recommendation' | 'opportunity';
  title: string;
  description: string;
  confidence: number;
  impact?: 'low' | 'medium' | 'high';
  category?: string;
  created_at?: string;
  is_read?: boolean;
  metadata?: Json;
}

// Data service status
export interface DataServiceStatus {
  status: 'azure' | 'mock' | 'hybrid';
  provider: string;
  version: string;
  timestamp: string;
  configuration: {
    azureBaseUrl: string;
    hasAuth: boolean;
    dataSource: string;
    useAzure: boolean;
    hasConfig: boolean;
  };
  message: string;
}

// Azure connection test result
export interface AzureConnectionTest {
  success: boolean;
  responseTime: number;
  error?: string;
}

// Chart data types
export interface ChartData {
  x: (string | number)[];
  y: (string | number)[];
  type?: string;
  name?: string;
  labels?: string[];
  values?: number[];
  parents?: string[];
}

// Dashboard state
export interface DashboardState {
  filters: AnalyticsFilters;
  loading: boolean;
  error: string | null;
  lastUpdated: string;
}