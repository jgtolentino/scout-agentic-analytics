'use client';

import useSWR from 'swr';
import { callSupabaseRPC } from '@/lib/supabase/client';
import type {
  AnalyticsFilters,
  ExecutiveOverview,
  SKUCounts,
  ParetoCategory,
  BasketPair,
  BehaviorKPIs,
  RequestMethod,
  AcceptanceByMethod,
  TopPath,
  GeoMetric,
  CompareResult,
  Insight
} from '@/lib/supabase/types';

// Executive Overview Hook
export function useExecutiveOverview(filters: AnalyticsFilters) {
  return useSWR(
    ['executive_overview', filters],
    () => callSupabaseRPC<ExecutiveOverview>('rpc_executive_overview', { filters }),
    {
      refreshInterval: 300000, // 5 minutes
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// SKU Counts Hook
export function useSKUCounts(filters: AnalyticsFilters) {
  return useSWR(
    ['sku_counts', filters],
    () => callSupabaseRPC<SKUCounts>('rpc_sku_counts', { filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Pareto Analysis Hook
export function useParetoCategories(filters: AnalyticsFilters) {
  return useSWR(
    ['pareto_categories', filters],
    () => callSupabaseRPC<ParetoCategory[]>('rpc_pareto_category', { filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Basket Analysis Hook
export function useBasketPairs(filters: AnalyticsFilters, topN: number = 10) {
  return useSWR(
    ['basket_pairs', filters, topN],
    () => callSupabaseRPC<BasketPair[]>('rpc_basket_pairs', { filters, top_n: topN }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Behavior KPIs Hook
export function useBehaviorKPIs(filters: AnalyticsFilters) {
  return useSWR(
    ['behavior_kpis', filters],
    () => callSupabaseRPC<BehaviorKPIs>('rpc_behavior_kpis', { filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Request Methods Hook
export function useRequestMethods(filters: AnalyticsFilters) {
  return useSWR(
    ['request_methods', filters],
    () => callSupabaseRPC<RequestMethod[]>('rpc_request_methods', { filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Acceptance by Method Hook
export function useAcceptanceByMethod(filters: AnalyticsFilters) {
  return useSWR(
    ['acceptance_by_method', filters],
    () => callSupabaseRPC<AcceptanceByMethod[]>('rpc_acceptance_by_method', { filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Top Paths Hook
export function useTopPaths(filters: AnalyticsFilters) {
  return useSWR(
    ['top_paths', filters],
    () => callSupabaseRPC<TopPath[]>('rpc_top_paths', { filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Geography Hook
export function useGeoMetric(
  level: string,
  parentCode?: string,
  filters: AnalyticsFilters
) {
  return useSWR(
    ['geo_metric', level, parentCode, filters],
    () => callSupabaseRPC<GeoMetric[]>('rpc_geo_metric', { 
      level, 
      parent_code: parentCode, 
      filters 
    }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Compare Hook
export function useCompare(
  mode: string,
  items: string[],
  filters: AnalyticsFilters
) {
  return useSWR(
    ['compare', mode, items, filters],
    () => callSupabaseRPC<CompareResult>('rpc_compare', { mode, items, filters }),
    {
      refreshInterval: 300000,
      revalidateOnFocus: false,
      errorRetryCount: 3,
      dedupingInterval: 60000, // 1 minute
    }
  );
}

// Insights Hook  
export function useInsights(filters?: AnalyticsFilters) {
  return useSWR(
    ['insights', filters],
    async () => {
      // For now, return mock insights until insights table is populated
      const mockInsights: Insight[] = [
        {
          id: '1',
          type: 'trend',
          title: 'Sales Increase',
          description: 'Sales have increased 15% this month compared to last month',
          delta: '+15%',
          confidence: 0.95,
          timestamp: new Date().toISOString(),
        },
        {
          id: '2', 
          type: 'anomaly',
          title: 'Regional Variance',
          description: 'NCR region showing 25% higher conversion rates',
          delta: '+25%',
          confidence: 0.88,
          timestamp: new Date().toISOString(),
        },
      ];
      return mockInsights;
    },
    {
      refreshInterval: 600000, // 10 minutes
      revalidateOnFocus: false,
      errorRetryCount: 3,
    }
  );
}

// Combined Dashboard Hook for performance
export function useDashboardData(filters: AnalyticsFilters) {
  const executiveData = useExecutiveOverview(filters);
  const skuData = useSKUCounts(filters);
  const behaviorData = useBehaviorKPIs(filters);
  const insightsData = useInsights(filters);

  return {
    executive: executiveData,
    sku: skuData,
    behavior: behaviorData,
    insights: insightsData,
    isLoading: executiveData.isLoading || skuData.isLoading || behaviorData.isLoading,
    error: executiveData.error || skuData.error || behaviorData.error,
  };
}