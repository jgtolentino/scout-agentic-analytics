'use client';

// Azure Functions Data Service for Scout v7.1 Dashboard
// Connects to Azure Functions API with fallback to mock data

import { getMockData, withMockDelay } from '@/lib/mocks/registry';
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

// Azure Functions configuration
const AZURE_FUNCTION_BASE = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE || 'https://fn-scout-readonly.azurewebsites.net/api';
const USE_AZURE = process.env.NEXT_PUBLIC_DATA_SOURCE === 'azure' || process.env.NEXT_PUBLIC_DATA_SOURCE === 'production';
const FUNCTION_KEY = process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY;

// Azure Functions API call with retry logic and fallback
export async function callRPC<T = any>(
  functionName: string,
  params: Record<string, any> = {}
): Promise<T> {
  console.log(`🔷 Azure Data Service: ${functionName} called with params:`, params);

  if (!USE_AZURE) {
    console.log(`📊 Fallback: Using mock data for ${functionName}`);
    return callMockRPC<T>(functionName, params);
  }

  // Map RPC function names to Azure Function endpoints
  const azureEndpointMapping: Record<string, string> = {
    'rpc_executive_overview': 'analytics/executive',
    'rpc_sku_counts': 'analytics/sku-counts',
    'rpc_pareto_category': 'analytics/pareto',
    'rpc_basket_pairs': 'analytics/basket',
    'rpc_behavior_kpis': 'analytics/behavior',
    'rpc_request_methods': 'analytics/methods',
    'rpc_acceptance_by_method': 'analytics/acceptance',
    'rpc_top_paths': 'analytics/paths',
    'rpc_geo_metric': 'analytics/geography',
    'rpc_compare': 'analytics/compare',
    'rpc_insights': 'analytics/insights'
  };

  const endpoint = azureEndpointMapping[functionName];
  if (!endpoint) {
    console.warn(`⚠️ Unknown Azure endpoint for ${functionName}, falling back to mock`);
    return callMockRPC<T>(functionName, params);
  }

  const url = `${AZURE_FUNCTION_BASE}/${endpoint}`;
  const maxRetries = 3;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Add function key if available
      if (FUNCTION_KEY) {
        headers['x-functions-key'] = FUNCTION_KEY;
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout

      const response = await fetch(url, {
        method: 'POST',
        headers,
        body: JSON.stringify(params),
        signal: controller.signal,
        cache: 'no-store'
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        throw new Error(`Azure Function ${endpoint} failed: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      console.log(`✅ Azure Function ${endpoint} success (attempt ${attempt})`);
      return data as T;

    } catch (error) {
      console.error(`❌ Azure Function ${endpoint} failed (attempt ${attempt}):`, error);

      if (attempt === maxRetries) {
        console.warn(`🔄 All Azure attempts failed for ${functionName}, falling back to mock data`);
        return callMockRPC<T>(functionName, params);
      }

      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
    }
  }

  // This should never be reached, but TypeScript requires it
  return callMockRPC<T>(functionName, params);
}

// Fallback to mock data when Azure is unavailable
async function callMockRPC<T = any>(
  functionName: string,
  params: Record<string, any> = {}
): Promise<T> {
  const mockMapping: Record<string, string> = {
    'rpc_executive_overview': 'get_executive_overview',
    'rpc_sku_counts': 'get_sku_counts',
    'rpc_pareto_category': 'get_pareto_categories',
    'rpc_basket_pairs': 'get_basket_pairs',
    'rpc_behavior_kpis': 'get_behavior_kpis',
    'rpc_request_methods': 'get_request_methods',
    'rpc_acceptance_by_method': 'get_acceptance_by_method',
    'rpc_top_paths': 'get_top_paths',
    'rpc_geo_metric': 'get_geo_metrics',
    'rpc_compare': 'get_compare_data',
    'rpc_insights': 'get_insights'
  };

  const mockFunction = mockMapping[functionName] || functionName;
  let data = getMockData<T>(mockFunction, params);

  if (!data) {
    console.warn(`⚠️ No mock data found for ${functionName}, returning empty response`);
    data = {} as T;
  }

  return withMockDelay(data, Math.random() * 200 + 50);
}

// Batch RPC calls
export async function callMultipleRPCs(calls: Array<{
  name: string;
  params?: Record<string, any>;
}>): Promise<Record<string, any>> {
  console.log(`📊 Data Service: Batch calls:`, calls.map(c => c.name));

  const promises = calls.map(async ({ name, params = {} }) => {
    try {
      const result = await callRPC(name, params);
      return { [name]: { data: result, error: null } };
    } catch (error) {
      return { [name]: { data: null, error } };
    }
  });

  const results = await Promise.all(promises);
  return Object.assign({}, ...results);
}

// Generate mock compare data for comparison functionality
function generateCompareData(mode: string, items: string[]): CompareResult {
  const mockCompareData: CompareResult = {
    mode,
    items,
    metrics: {
      revenue: items.reduce((acc, item, index) => ({
        ...acc,
        [item]: Math.random() * 100000 + 50000
      }), {}),
      transactions: items.reduce((acc, item, index) => ({
        ...acc,
        [item]: Math.floor(Math.random() * 1000) + 500
      }), {}),
      conversion_rate: items.reduce((acc, item, index) => ({
        ...acc,
        [item]: Math.random() * 0.3 + 0.1
      }), {})
    },
    timestamp: new Date().toISOString()
  };

  return mockCompareData;
}

// Export individual data fetchers for compatibility
export const dataService = {
  // Executive Overview - Maps to Azure Function analytics/executive
  async getExecutiveOverview(filters: AnalyticsFilters): Promise<ExecutiveOverview> {
    return callRPC<ExecutiveOverview>('rpc_executive_overview', { filters });
  },

  // SKU Counts - Maps to Azure Function analytics/sku-counts
  async getSKUCounts(filters: AnalyticsFilters): Promise<SKUCounts> {
    return callRPC<SKUCounts>('rpc_sku_counts', { filters });
  },

  // Pareto Categories - Maps to Azure Function analytics/pareto
  async getParetoCategories(filters: AnalyticsFilters): Promise<ParetoCategory[]> {
    return callRPC<ParetoCategory[]>('rpc_pareto_category', { filters });
  },

  // Basket Pairs - Maps to Azure Function analytics/basket
  async getBasketPairs(filters: AnalyticsFilters, topN: number = 10): Promise<BasketPair[]> {
    return callRPC<BasketPair[]>('rpc_basket_pairs', { filters, top_n: topN });
  },

  // Behavior KPIs - Maps to Azure Function analytics/behavior
  async getBehaviorKPIs(filters: AnalyticsFilters): Promise<BehaviorKPIs> {
    return callRPC<BehaviorKPIs>('rpc_behavior_kpis', { filters });
  },

  // Request Methods - Maps to Azure Function analytics/methods
  async getRequestMethods(filters: AnalyticsFilters): Promise<RequestMethod[]> {
    return callRPC<RequestMethod[]>('rpc_request_methods', { filters });
  },

  // Acceptance by Method - Maps to Azure Function analytics/acceptance
  async getAcceptanceByMethod(filters: AnalyticsFilters): Promise<AcceptanceByMethod[]> {
    return callRPC<AcceptanceByMethod[]>('rpc_acceptance_by_method', { filters });
  },

  // Top Paths - Maps to Azure Function analytics/paths
  async getTopPaths(filters: AnalyticsFilters): Promise<TopPath[]> {
    return callRPC<TopPath[]>('rpc_top_paths', { filters });
  },

  // Geography - Maps to Azure Function analytics/geography
  async getGeoMetric(
    level: string,
    parentCode?: string,
    filters?: AnalyticsFilters
  ): Promise<GeoMetric[]> {
    return callRPC<GeoMetric[]>('rpc_geo_metric', {
      level,
      parent_code: parentCode,
      filters
    });
  },

  // Compare - Maps to Azure Function analytics/compare
  async getCompare(
    mode: string,
    items: string[],
    filters: AnalyticsFilters
  ): Promise<CompareResult> {
    return callRPC<CompareResult>('rpc_compare', { mode, items, filters });
  },

  // Insights - Maps to Azure Function analytics/insights
  async getInsights(filters?: AnalyticsFilters): Promise<Insight[]> {
    return callRPC<Insight[]>('rpc_insights', { filters });
  }
};

// Health check for data service
export function getDataServiceStatus() {
  const isAzureMode = USE_AZURE;
  const hasAzureConfig = !!AZURE_FUNCTION_BASE && AZURE_FUNCTION_BASE !== 'https://fn-scout-readonly.azurewebsites.net/api';

  return {
    status: isAzureMode ? 'azure' : 'mock',
    provider: isAzureMode ? 'Azure Functions' : 'Local Mock Data',
    version: '2.0.0',
    timestamp: new Date().toISOString(),
    configuration: {
      azureBaseUrl: AZURE_FUNCTION_BASE,
      hasAuth: !!FUNCTION_KEY,
      dataSource: process.env.NEXT_PUBLIC_DATA_SOURCE || 'mock_csv',
      useAzure: isAzureMode,
      hasConfig: hasAzureConfig
    },
    message: isAzureMode
      ? `🔷 Using Azure Functions at ${AZURE_FUNCTION_BASE}${FUNCTION_KEY ? ' (authenticated)' : ' (no auth)'}`
      : '📊 Using local mock data - Azure disabled'
  };
}

// Test Azure connection
export async function testAzureConnection(): Promise<{
  success: boolean;
  responseTime: number;
  error?: string;
}> {
  if (!USE_AZURE) {
    return {
      success: false,
      responseTime: 0,
      error: 'Azure mode disabled'
    };
  }

  const startTime = Date.now();

  try {
    const response = await fetch(`${AZURE_FUNCTION_BASE}/health`, {
      method: 'GET',
      headers: FUNCTION_KEY ? { 'x-functions-key': FUNCTION_KEY } : {},
      signal: AbortSignal.timeout(5000)
    });

    const responseTime = Date.now() - startTime;

    if (response.ok) {
      return {
        success: true,
        responseTime
      };
    } else {
      return {
        success: false,
        responseTime,
        error: `HTTP ${response.status}: ${response.statusText}`
      };
    }
  } catch (error) {
    return {
      success: false,
      responseTime: Date.now() - startTime,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}