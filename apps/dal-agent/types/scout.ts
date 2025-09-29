// Scout v7 Analytics Platform TypeScript Definitions

// =====================================================
// Core Transaction Models
// =====================================================

export interface ScoutTransaction {
  // Primary Keys
  transaction_id: string;
  interaction_id: string;
  facial_id: string;
  store_id: string;
  device_id: string;

  // Product Information
  category: string;
  brand: string;
  brand_raw?: string;
  product: string;
  sku?: string;
  product_id?: string;

  // Financial Data
  qty: number;
  unit: string;
  unit_price: number;
  total_price: number;
  payment_method?: string;

  // Temporal Data
  transaction_ts: string;
  date_ph: string;
  time_ph: string;
  day_of_week: string;
  weekday_weekend: 'Weekday' | 'Weekend';
  time_of_day: 'Morning' | 'Afternoon' | 'Evening' | 'Night';

  // Customer Demographics
  age: number;
  age_bracket?: string;
  gender: 'Male' | 'Female' | string;
  emotion?: string;
  emotional_state?: string;

  // Store & Location
  store_name?: string;
  store_location?: string;
  barangay?: string;
  municipality?: string;
  geo_latitude?: number;
  geo_longitude?: number;

  // Additional Context
  bought_with_other_brands?: boolean;
  transcript_audio?: string;
  transcription_text?: string;
  edge_version?: string;
}

// =====================================================
// Analytics & KPI Models
// =====================================================

export interface BrandPerformance {
  brand_name: string;
  official_name?: string;
  parent_company?: string;
  category: string;

  // Market Metrics
  market_share_percent: number;
  consumer_reach_points: number;
  crp_rank?: number;
  position_type: 'leader' | 'challenger' | 'follower' | 'niche';

  // Pricing Intelligence
  avg_price_php: number;
  min_price_php: number;
  max_price_php: number;
  price_volatility: number;
  vs_category_avg: number;

  // Performance Classification
  brand_tier: 'Tier 1 - National Leader' | 'Tier 2 - Strong Brand' | 'Tier 3 - Established' | 'Tier 4 - Emerging/Niche';
  value_proposition: 'Premium' | 'Mainstream' | 'Value';
  growth_status: 'High Growth' | 'Moderate Growth' | 'Stable' | 'Declining';

  // Growth Metrics
  brand_growth_yoy: number;
  household_penetration?: number;

  // Channel & Geographic
  channels_available: number;
  channel_list: string;
  direct_competitors: number;

  // Data Quality
  last_updated: string;
  confidence_score?: number;
  data_freshness?: string;
}

export interface CategoryAnalysis {
  category: string;
  market_size_php: number;
  market_size_usd: number;
  cagr_percent: number;
  market_concentration: 'high' | 'medium' | 'low';
  penetration_percent: number;
  consumption_per_capita_php: number;

  // Brand Analysis
  total_brands: number;
  major_brands: number;
  market_leaders: number;

  // Market Share Distribution
  total_tracked_share: number;
  leader_share: number;
  avg_brand_share: number;

  // CRP Analysis
  total_category_crp: number;
  top_brand_crp: number;
  avg_brand_crp: number;

  // Price Analysis
  avg_category_price: number;
  lowest_price: number;
  highest_price: number;
  price_spread: number;

  // Growth Metrics
  avg_brand_growth: number;
  fastest_growth: number;
  slowest_growth: number;

  // Health Score
  category_health_score: number;

  // Insights
  market_trends: string[];
  growth_drivers: string[];
  market_challenges: string[];

  // Data Quality
  data_confidence: number;
  data_freshness: string;
}

export interface StorePerformance {
  // Store Identity
  store_id: string;
  store_name: string;
  store_municipality: string;
  municipality: string;
  barangay: string;
  latitude: number;
  longitude: number;

  // Customer Metrics
  unique_customers: number;
  total_interactions: number;
  avg_visits_per_customer: number;

  // Temporal Patterns
  first_recorded_interaction: string;
  last_recorded_interaction: string;
  active_days: number;

  // Purchase Behavior
  transactions_with_purchase: number;
  avg_transaction_amount: number;
  total_revenue: number;

  // Demographics
  avg_customer_age: number;
  male_customers: number;
  female_customers: number;

  // Time Distribution
  morning_interactions: number;
  afternoon_interactions: number;
  evening_interactions: number;
  night_interactions: number;

  // Data Quality
  avg_data_completeness: number;
  store_geojson: string;
}

// =====================================================
// Geographic & Location Models
// =====================================================

export interface StoreLocation {
  store_id: string;
  store_name: string;

  // Coordinates
  latitude: number;
  longitude: number;

  // Administrative Hierarchy
  region_code: string;
  region_name: string;
  province_code: string;
  province_name: string;
  municipality_code: string;
  municipality_name: string;
  barangay: string;

  // GADM Levels
  gadm_level0: string; // Country
  gadm_level1: string; // Region
  gadm_level2: string; // Municipality
  gadm_level3: string; // Barangay

  // GeoJSON
  geojson: string;
  store_geometry?: any;
}

// =====================================================
// API Response Models
// =====================================================

export interface ApiResponse<T> {
  data: T;
  meta?: {
    total: number;
    page: number;
    limit: number;
    has_more: boolean;
  };
  cache?: {
    hit: boolean;
    ttl: number;
  };
  performance?: {
    query_time_ms: number;
    row_count: number;
  };
}

export interface NL2SQLRequest {
  question?: string;
  plan?: {
    intent: 'aggregate' | 'crosstab' | 'filter' | 'trend';
    rows: string[];
    cols: string[];
    measures: Array<{metric: string; aggregation?: string}>;
    filters: Record<string, any>;
    pivot: boolean;
    limit: number;
  };
}

export interface NL2SQLResponse {
  sql: string;
  results: any[];
  plan: any;
  performance: {
    parse_time_ms: number;
    execution_time_ms: number;
    row_count: number;
  };
  cache_hit: boolean;
}

// =====================================================
// Filter & Query Models
// =====================================================

export interface ScoutFilters {
  store_ids?: string[];
  brands?: string[];
  categories?: string[];
  date_range?: {
    start: string;
    end: string;
  };
  time_of_day?: string[];
  age_brackets?: string[];
  genders?: string[];
  municipalities?: string[];
  min_amount?: number;
  max_amount?: number;
}

export interface QueryOptions {
  limit?: number;
  offset?: number;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
  cache_ttl?: number;
  include_metadata?: boolean;
}

// =====================================================
// Dashboard Component Props
// =====================================================

export interface DashboardProps {
  filters?: ScoutFilters;
  onFiltersChange?: (filters: ScoutFilters) => void;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

export interface ChartProps {
  data: any[];
  loading?: boolean;
  error?: string;
  title?: string;
  height?: number;
  interactive?: boolean;
}

// =====================================================
// Utility Types
// =====================================================

export type DateRange = {
  start: Date;
  end: Date;
};

export type AggregationPeriod = 'hour' | 'day' | 'week' | 'month' | 'quarter' | 'year';

export type MetricType = 'count' | 'sum' | 'avg' | 'min' | 'max' | 'distinct_count';

export type ChartType = 'line' | 'bar' | 'area' | 'pie' | 'scatter' | 'heatmap' | 'map';

// =====================================================
// Constants
// =====================================================

export const SCOUT_STORES = [102, 103, 104, 109, 110, 112] as const;

export const TIME_OF_DAY_SEGMENTS = [
  'Morning',
  'Afternoon',
  'Evening',
  'Night'
] as const;

export const AGE_BRACKETS = [
  'Gen Z (≤18)',
  'Young Adult (19-25)',
  'Millennial (26-35)',
  'Gen X (36-50)',
  'Boomer (50+)'
] as const;

export const BRAND_TIERS = [
  'Tier 1 - National Leader',
  'Tier 2 - Strong Brand',
  'Tier 3 - Established',
  'Tier 4 - Emerging/Niche'
] as const;