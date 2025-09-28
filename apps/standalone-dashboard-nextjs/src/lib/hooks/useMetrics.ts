'use client';

import useSWR from 'swr';
import { dataService } from '@/lib/dataService';
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
} from '@/lib/types';

// Executive Overview Hook
export function useExecutiveOverview(filters: AnalyticsFilters) {
  return useSWR(
    ['executive_overview', filters],
    () => dataService.getExecutiveOverview(filters),
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
    () => dataService.getSKUCounts(filters),
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
    () => dataService.getParetoCategories(filters),
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
    () => dataService.getBasketPairs(filters, topN),
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
    () => dataService.getBehaviorKPIs(filters),
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
    () => dataService.getRequestMethods(filters),
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
    () => dataService.getAcceptanceByMethod(filters),
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
    () => dataService.getTopPaths(filters),
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
    () => dataService.getGeoMetric(level, parentCode, filters),
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
    () => dataService.getCompare(mode, items, filters),
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
    () => dataService.getInsights(filters),
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