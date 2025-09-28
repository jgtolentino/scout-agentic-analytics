'use client';

// Multi-Mode Data Service for Scout v7.1 Dashboard
// Supports Azure Functions, Parquet files, and Mock data sources

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

// Data source configuration
type DataSourceMode = 'azure' | 'parquet' | 'mock';

const DATA_SOURCE = (process.env.NEXT_PUBLIC_DATA_SOURCE || 'azure') as DataSourceMode;
const AZURE_FUNCTION_BASE = process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE || 'https://fn-scout-readonly.azurewebsites.net/api';
const PARQUET_BASE_URL = process.env.NEXT_PUBLIC_PARQUET_BASE_URL || '/data/parquet';
const FUNCTION_KEY = process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY;

const USE_AZURE = DATA_SOURCE === 'azure' || DATA_SOURCE === 'production';
const USE_PARQUET = DATA_SOURCE === 'parquet';
const USE_MOCK = DATA_SOURCE === 'mock' || process.env.NEXT_PUBLIC_USE_MOCK === '1';

// Multi-mode data service call with fallback chain
export async function callRPC<T = any>(
  functionName: string,
  params: Record<string, any> = {}
): Promise<T> {
  console.log(`📊 Data Service (${DATA_SOURCE}): ${functionName} called with params:`, params);

  // Route to appropriate data source
  if (USE_AZURE) {
    return callAzureRPC<T>(functionName, params);
  } else if (USE_PARQUET) {
    return callParquetRPC<T>(functionName, params);
  } else {
    console.log(`📊 Using mock data for ${functionName}`);
    return callMockRPC<T>(functionName, params);
  }
}

// Azure Functions API call with retry logic and fallback
async function callAzureRPC<T = any>(
  functionName: string,
  params: Record<string, any> = {}
): Promise<T> {
  console.log(`🔷 Azure Functions: ${functionName}`);

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
        console.warn(`🔄 All Azure attempts failed for ${functionName}, falling back to Parquet then Mock`);
        try {
          return await callParquetRPC<T>(functionName, params);
        } catch (parquetError) {
          console.warn(`🔄 Parquet fallback failed, using mock data`);
          return callMockRPC<T>(functionName, params);
        }
      }

      // Exponential backoff
      await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
    }
  }

  // This should never be reached, but TypeScript requires it
  return callMockRPC<T>(functionName, params);
}

// Parquet file data source
async function callParquetRPC<T = any>(
  functionName: string,
  params: Record<string, any> = {}
): Promise<T> {
  console.log(`📄 Parquet Data: ${functionName}`);

  // Map RPC function names to Parquet file paths
  const parquetFileMapping: Record<string, string> = {
    'rpc_executive_overview': 'executive_overview.parquet',
    'rpc_sku_counts': 'sku_counts.parquet',
    'rpc_pareto_category': 'pareto_categories.parquet',
    'rpc_basket_pairs': 'basket_pairs.parquet',
    'rpc_behavior_kpis': 'behavior_kpis.parquet',
    'rpc_request_methods': 'request_methods.parquet',
    'rpc_acceptance_by_method': 'acceptance_by_method.parquet',
    'rpc_top_paths': 'top_paths.parquet',
    'rpc_geo_metric': 'geo_metrics.parquet',
    'rpc_compare': 'compare_data.parquet',
    'rpc_insights': 'insights.parquet'
  };

  const fileName = parquetFileMapping[functionName];
  if (!fileName) {
    console.warn(`⚠️ No Parquet file mapped for ${functionName}, falling back to mock`);
    return callMockRPC<T>(functionName, params);
  }

  try {
    const url = `${PARQUET_BASE_URL}/${fileName}`;

    // For browser environments, we'll load JSON versions of Parquet data
    // In production, this would be handled by a service that converts Parquet to JSON
    const jsonUrl = url.replace('.parquet', '.json');

    const response = await fetch(jsonUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
      cache: 'force-cache' // Cache Parquet data aggressively
    });

    if (!response.ok) {
      throw new Error(`Parquet file ${fileName} not found: ${response.status}`);
    }

    const data = await response.json();
    console.log(`✅ Parquet data loaded: ${fileName}`);

    // Apply basic filtering based on params
    return applyParquetFilters(data, params) as T;

  } catch (error) {
    console.error(`❌ Parquet data failed for ${functionName}:`, error);
    console.warn(`🔄 Falling back to mock data`);
    return callMockRPC<T>(functionName, params);
  }
}

// Apply basic filtering to Parquet data
function applyParquetFilters(data: any, params: Record<string, any>): any {
  if (!params.filters || !Array.isArray(data)) {
    return data;
  }

  const { filters } = params;
  let filteredData = data;

  // Apply region filter
  if (filters.region && data.some((item: any) => item.region)) {
    filteredData = filteredData.filter((item: any) => item.region === filters.region);
  }

  // Apply category filter
  if (filters.category && data.some((item: any) => item.category)) {
    filteredData = filteredData.filter((item: any) => item.category === filters.category);
  }

  // Apply date range filter (simplified)
  if (filters.date_start && data.some((item: any) => item.date)) {
    filteredData = filteredData.filter((item: any) =>
      new Date(item.date) >= new Date(filters.date_start)
    );
  }

  // Apply limit
  if (params.top_n) {
    filteredData = filteredData.slice(0, params.top_n);
  }

  return filteredData;
}

// Fallback to mock data when other sources are unavailable
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

// Switch data source mode
export function switchDataSource(mode: DataSourceMode): void {
  // This would typically update environment or localStorage
  // For now, we'll update a runtime flag
  console.log(`🔄 Switching data source to: ${mode}`);

  // In a real implementation, this might:
  // 1. Update localStorage
  // 2. Trigger a page reload
  // 3. Update runtime configuration

  if (typeof window !== 'undefined') {
    localStorage.setItem('dataSource', mode);
    window.location.reload();
  }
}

// Get current data source from runtime or localStorage
export function getCurrentDataSource(): DataSourceMode {
  if (typeof window !== 'undefined') {
    const stored = localStorage.getItem('dataSource') as DataSourceMode;
    if (stored && ['azure', 'parquet', 'mock'].includes(stored)) {
      return stored;
    }
  }
  return DATA_SOURCE;
}

// Health check for data service
export function getDataServiceStatus() {
  const currentSource = getCurrentDataSource();
  const hasAzureConfig = !!AZURE_FUNCTION_BASE && AZURE_FUNCTION_BASE !== 'https://fn-scout-readonly.azurewebsites.net/api';
  const hasParquetConfig = !!PARQUET_BASE_URL && PARQUET_BASE_URL !== '/data/parquet';

  const statusMap = {
    azure: 'azure',
    parquet: 'parquet',
    mock: 'mock'
  };

  const providerMap = {
    azure: 'Azure Functions',
    parquet: 'Parquet Files',
    mock: 'Local Mock Data'
  };

  const messageMap = {
    azure: `🔷 Using Azure Functions at ${AZURE_FUNCTION_BASE}${FUNCTION_KEY ? ' (authenticated)' : ' (no auth)'}`,
    parquet: `📄 Using Parquet files from ${PARQUET_BASE_URL}`,
    mock: '📊 Using local mock data'
  };

  return {
    status: statusMap[currentSource] || 'mock',
    provider: providerMap[currentSource] || 'Local Mock Data',
    version: '3.0.0',
    timestamp: new Date().toISOString(),
    configuration: {
      currentSource,
      azureBaseUrl: AZURE_FUNCTION_BASE,
      parquetBaseUrl: PARQUET_BASE_URL,
      hasAuth: !!FUNCTION_KEY,
      dataSource: currentSource,
      useAzure: currentSource === 'azure',
      useParquet: currentSource === 'parquet',
      useMock: currentSource === 'mock',
      hasAzureConfig,
      hasParquetConfig
    },
    message: messageMap[currentSource] || '📊 Using local mock data'
  };
}

// Test data source connections
export async function testDataSourceConnection(source?: DataSourceMode): Promise<{
  success: boolean;
  responseTime: number;
  error?: string;
}> {
  const testSource = source || getCurrentDataSource();
  const startTime = Date.now();

  try {
    switch (testSource) {
      case 'azure':
        return await testAzureConnection();
      case 'parquet':
        return await testParquetConnection();
      case 'mock':
        return {
          success: true,
          responseTime: Date.now() - startTime,
        };
      default:
        return {
          success: false,
          responseTime: Date.now() - startTime,
          error: `Unknown data source: ${testSource}`
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

// Test Azure connection
async function testAzureConnection(): Promise<{
  success: boolean;
  responseTime: number;
  error?: string;
}> {

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

// Test Parquet data source
async function testParquetConnection(): Promise<{
  success: boolean;
  responseTime: number;
  error?: string;
}> {
  const startTime = Date.now();

  try {
    // Test if we can access a sample Parquet file
    const testUrl = `${PARQUET_BASE_URL}/executive_overview.json`;
    const response = await fetch(testUrl, {
      method: 'HEAD',
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
        error: `Parquet data not accessible: ${response.status} ${response.statusText}`
      };
    }
  } catch (error) {
    return {
      success: false,
      responseTime: Date.now() - startTime,
      error: error instanceof Error ? error.message : 'Parquet connection failed'
    };
  }
}