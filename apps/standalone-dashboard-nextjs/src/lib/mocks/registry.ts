'use client';

// Mock Registry System for Scout v7.1 Dashboard
// Provides realistic data for all dashboard components in development mode

import type {
  ExecutiveOverview,
  SKUCounts,
  ParetoCategory,
  BasketPair,
  BehaviorKPIs,
  RequestMethod,
  AcceptanceByMethod,
  TopPath,
  GeoMetric,
  Insight
} from '@/lib/types';

// Registry interface for type safety
interface MockRegistry {
  executive_overview: ExecutiveOverview;
  sku_counts: SKUCounts;
  pareto_categories: ParetoCategory[];
  basket_pairs: BasketPair[];
  behavior_kpis: BehaviorKPIs;
  request_methods: RequestMethod[];
  acceptance_by_method: AcceptanceByMethod[];
  top_paths: TopPath[];
  geo_metrics: GeoMetric[];
  insights: Insight[];
}

// Mock data storage
const mockData: MockRegistry = {
  executive_overview: {
    purchases: 45287,
    total_spend: 2847293,
    top_category: 'Personal Care',
    monthly_trend: [
      { month: '2024-06', spend: 235000 },
      { month: '2024-07', spend: 267000 },
      { month: '2024-08', spend: 298000 },
      { month: '2024-09', spend: 324000 },
      { month: '2024-10', spend: 285000 },
      { month: '2024-11', spend: 341000 }
    ]
  },

  sku_counts: {
    total: 12847,
    active: 8934,
    new: 1256
  },

  pareto_categories: [
    { category: 'Personal Care', revenue: 847293, percentage: 28.5, cumulative: 28.5 },
    { category: 'Beverages', revenue: 634821, percentage: 21.3, cumulative: 49.8 },
    { category: 'Household', revenue: 492847, percentage: 16.6, cumulative: 66.4 },
    { category: 'Snacks', revenue: 387234, percentage: 13.0, cumulative: 79.4 },
    { category: 'Tobacco', revenue: 298472, percentage: 10.0, cumulative: 89.4 },
    { category: 'Health', revenue: 186295, percentage: 6.3, cumulative: 95.7 },
    { category: 'Other', revenue: 128472, percentage: 4.3, cumulative: 100.0 }
  ],

  basket_pairs: [
    { source: 'Shampoo', target: 'Conditioner', confidence: 0.85, lift: 2.4, support: 0.23 },
    { source: 'Toothpaste', target: 'Toothbrush', confidence: 0.72, lift: 1.8, support: 0.19 },
    { source: 'Coffee', target: 'Sugar', confidence: 0.68, lift: 1.6, support: 0.31 },
    { source: 'Bread', target: 'Butter', confidence: 0.64, lift: 1.9, support: 0.28 },
    { source: 'Chips', target: 'Soda', confidence: 0.59, lift: 1.4, support: 0.22 },
    { source: 'Milk', target: 'Cereal', confidence: 0.56, lift: 1.7, support: 0.26 },
    { source: 'Beer', target: 'Snacks', confidence: 0.52, lift: 1.3, support: 0.18 },
    { source: 'Soap', target: 'Lotion', confidence: 0.48, lift: 1.5, support: 0.15 },
    { source: 'Rice', target: 'Beans', confidence: 0.45, lift: 1.2, support: 0.13 },
    { source: 'Juice', target: 'Water', confidence: 0.42, lift: 1.1, support: 0.17 }
  ],

  behavior_kpis: {
    conversion_rate: 0.142,
    suggestion_accept_rate: 0.267,
    brand_loyalty_rate: 0.634
  },

  request_methods: [
    { method: 'Voice', count: 8472, percentage: 42.3 },
    { method: 'Touch', count: 6834, percentage: 34.2 },
    { method: 'Search', count: 3245, percentage: 16.2 },
    { method: 'Browse', count: 1449, percentage: 7.3 }
  ],

  acceptance_by_method: [
    { method: 'Voice', accepted: 2847, total: 8472, rate: 0.336 },
    { method: 'Touch', accepted: 1823, total: 6834, rate: 0.267 },
    { method: 'Search', accepted: 1298, total: 3245, rate: 0.400 },
    { method: 'Browse', accepted: 434, total: 1449, rate: 0.300 }
  ],

  top_paths: [
    {
      path: 'Home → Search → Product → Cart → Purchase',
      users: 1547,
      conversion_rate: 0.152,
      avg_time: 284
    },
    {
      path: 'Home → Category → Product → Purchase',
      users: 1289,
      conversion_rate: 0.128,
      avg_time: 195
    },
    {
      path: 'Search → Filter → Compare → Cart → Purchase',
      users: 967,
      conversion_rate: 0.095,
      avg_time: 347
    },
    {
      path: 'Category → Brand → Product → Cart',
      users: 834,
      conversion_rate: 0.081,
      avg_time: 221
    },
    {
      path: 'Home → Recommendations → Purchase',
      users: 678,
      conversion_rate: 0.062,
      avg_time: 98
    }
  ],

  geo_metrics: [
    { region: 'Metro Manila', province: 'NCR', city: 'Manila', value: 847293, users: 12847 },
    { region: 'Metro Manila', province: 'NCR', city: 'Quezon City', value: 634821, users: 9234 },
    { region: 'Central Luzon', province: 'Bulacan', city: 'Malolos', value: 492847, users: 7123 },
    { region: 'Calabarzon', province: 'Cavite', city: 'Cavite City', value: 387234, users: 5678 },
    { region: 'Central Visayas', province: 'Cebu', city: 'Cebu City', value: 298472, users: 4521 },
    { region: 'Western Visayas', province: 'Iloilo', city: 'Iloilo City', value: 186295, users: 3456 },
    { region: 'Northern Mindanao', province: 'Cagayan de Oro', city: 'Cagayan de Oro', value: 128472, users: 2789 }
  ],

  insights: [
    {
      id: '1',
      type: 'trend',
      title: 'Personal Care Sales Surge',
      description: 'Personal care products show 32% growth this month, driven by premium skincare demand.',
      confidence: 0.89,
      impact: 'high',
      category: 'sales',
      created_at: '2024-11-15T10:30:00Z',
      is_read: false
    },
    {
      id: '2',
      type: 'anomaly',
      title: 'Unusual Drop in Beverages',
      description: 'Beverage sales dropped 15% in Metro Manila, possibly due to seasonal factors.',
      confidence: 0.76,
      impact: 'medium',
      category: 'performance',
      created_at: '2024-11-15T09:15:00Z',
      is_read: false
    },
    {
      id: '3',
      type: 'opportunity',
      title: 'Cross-sell Opportunity',
      description: 'Customers buying shampoo have 85% likelihood to purchase conditioner - optimize placement.',
      confidence: 0.92,
      impact: 'high',
      category: 'optimization',
      created_at: '2024-11-14T16:45:00Z',
      is_read: true
    }
  ]
};

// Mock RPC function mapper
const mockRPCFunctions: Record<string, keyof MockRegistry> = {
  'get_executive_overview': 'executive_overview',
  'get_sku_counts': 'sku_counts', 
  'get_pareto_categories': 'pareto_categories',
  'get_basket_pairs': 'basket_pairs',
  'get_behavior_kpis': 'behavior_kpis',
  'get_request_methods': 'request_methods',
  'get_acceptance_by_method': 'acceptance_by_method',
  'get_top_paths': 'top_paths',
  'get_geo_metrics': 'geo_metrics',
  'get_insights': 'insights'
};

// Main mock registry function
export function getMockData<T = any>(
  rpcFunction: string, 
  params: Record<string, any> = {}
): T | null {
  // Check if we're in mock mode
  if (process.env.NEXT_PUBLIC_USE_MOCK !== '1') {
    return null;
  }

  const mockKey = mockRPCFunctions[rpcFunction];
  if (!mockKey) {
    console.warn(`🎭 Mock registry: Unknown RPC function "${rpcFunction}"`);
    return null;
  }

  let data = mockData[mockKey];
  
  // Apply basic filtering/pagination for arrays
  if (Array.isArray(data)) {
    // Apply limit if specified
    if (params.limit && typeof params.limit === 'number') {
      data = data.slice(0, params.limit);
    }
    
    // Apply simple category/region filtering
    if (params.category && typeof params.category === 'string') {
      data = data.filter((item: any) => 
        item.category === params.category || 
        item.region === params.category
      );
    }
    
    if (params.region && typeof params.region === 'string') {
      data = data.filter((item: any) => 
        item.region === params.region
      );
    }
  }

  console.log(`🎭 Mock registry: Serving data for "${rpcFunction}" with params:`, params);
  return data as T;
}

// Helper function to simulate network delay
export function withMockDelay<T>(data: T, delay: number = 100): Promise<T> {
  return new Promise(resolve => {
    setTimeout(() => resolve(data), delay);
  });
}

// Development helper to list all available mock functions
export function listMockFunctions(): string[] {
  return Object.keys(mockRPCFunctions);
}

// Export the registry for direct access if needed
export { mockData, mockRPCFunctions };