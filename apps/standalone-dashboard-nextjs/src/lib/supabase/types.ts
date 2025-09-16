// Supabase Database Types
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

// Core filter interface matching our FilterBus
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

// RPC Function return types
export interface ExecutiveOverview {
  purchases: number;
  total_spend: number;
  top_category: string;
  monthly_trend: { month: string; spend: number }[];
  category_distribution: { category: string; value: number; share: number }[];
  category_performance: { category: string; performance: number }[];
}

export interface SKUCounts {
  total: number;
  active: number;
  new: number;
}

export interface ParetoCategory {
  category: string;
  revenue: number;
  cumulative_pct: number;
}

export interface BasketPair {
  category_a: string;
  category_b: string;
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
}

export interface AcceptanceByMethod {
  method: string;
  acceptance_rate: number;
}

export interface TopPath {
  path: string;
  users: number;
  conversion_rate: number;
  avg_time_minutes: number;
}

export interface GeoMetric {
  code: string;
  name: string;
  level: string;
  value: number;
  share: number;
  rank: number;
}

export interface CompareResult {
  baseline: any;
  comparison: any;
  delta_absolute: number;
  delta_percentage: number;
}

// Insight types
export interface Insight {
  id: string;
  type: 'anomaly' | 'trend' | 'forecast' | 'recommendation';
  title: string;
  description: string;
  delta: string;
  confidence: number;
  timestamp: string;
  metadata?: Json;
}

// Database schema interface
export interface Database {
  public: {
    Tables: {
      // Add your actual table definitions here
      insights: {
        Row: Insight;
        Insert: Omit<Insight, 'id' | 'timestamp'>;
        Update: Partial<Omit<Insight, 'id' | 'timestamp'>>;
      };
    };
    Views: {
      // Add your views here
    };
    Functions: {
      // RPC function signatures
      rpc_executive_overview: {
        Args: { filters: AnalyticsFilters };
        Returns: ExecutiveOverview;
      };
      rpc_sku_counts: {
        Args: { filters: AnalyticsFilters };
        Returns: SKUCounts;
      };
      rpc_pareto_category: {
        Args: { filters: AnalyticsFilters };
        Returns: ParetoCategory[];
      };
      rpc_basket_pairs: {
        Args: { filters: AnalyticsFilters; top_n?: number };
        Returns: BasketPair[];
      };
      rpc_behavior_kpis: {
        Args: { filters: AnalyticsFilters };
        Returns: BehaviorKPIs;
      };
      rpc_request_methods: {
        Args: { filters: AnalyticsFilters };
        Returns: RequestMethod[];
      };
      rpc_acceptance_by_method: {
        Args: { filters: AnalyticsFilters };
        Returns: AcceptanceByMethod[];
      };
      rpc_top_paths: {
        Args: { filters: AnalyticsFilters };
        Returns: TopPath[];
      };
      rpc_geo_metric: {
        Args: { 
          level: string; 
          parent_code?: string; 
          filters: AnalyticsFilters 
        };
        Returns: GeoMetric[];
      };
      rpc_compare: {
        Args: { 
          mode: string; 
          items: string[]; 
          filters: AnalyticsFilters 
        };
        Returns: CompareResult;
      };
    };
  };
}