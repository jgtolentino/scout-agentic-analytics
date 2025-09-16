'use client';

import { api } from '../api';
import { Filters } from '../store';

// Competitive analysis data types
export type CohortRetentionData = {
  cohort: string;
  periods: string[];
  retention: number[][]; // [cohort_index][period_index] = retention_percentage
  customerCounts: number[];
  metadata: {
    totalCohorts: number;
    averageRetention: number;
    bestPerformingCohort: string;
  };
};

export type BrandSwitchingData = {
  nodes: Array<{
    id: string;
    label: string;
    value: number;
    color?: string;
  }>;
  links: Array<{
    source: string;
    target: string;
    value: number;
    percentage: number;
  }>;
  switchingMatrix: {
    brands: string[];
    matrix: number[][]; // [from_brand][to_brand] = switch_count
  };
  metadata: {
    totalSwitches: number;
    retentionRate: number;
    topSwitchingPair: { from: string; to: string; percentage: number };
  };
};

export type JourneyFunnelData = {
  steps: Array<{
    name: string;
    count: number;
    percentage: number;
    dropoff?: number;
  }>;
  conversion: number;
  averageTime: number;
  pathAnalysis: {
    topPaths: Array<{
      path: string[];
      count: number;
      percentage: number;
      conversionRate: number;
    }>;
  };
};

export type JourneyPathData = {
  nodes: Array<{
    id: string;
    label: string;
    type: 'entry' | 'zone' | 'action' | 'exit';
    value: number;
  }>;
  links: Array<{
    source: string;
    target: string;
    value: number;
  }>;
  transitionMatrix: {
    states: string[];
    probabilities: number[][]; // [from_state][to_state] = probability
  };
};

export type CompetitiveBenchmarkData = {
  brands: string[];
  metrics: Array<{
    name: string;
    values: number[];
    unit?: string;
    format?: 'percentage' | 'currency' | 'number';
  }>;
  deltas: Array<{
    metric: string;
    brandA: string;
    brandB: string;
    absoluteDelta: number;
    percentageDelta: number;
  }>;
};

// Competitive analysis API using our existing DAL pattern
export const competitiveAPI = {
  // Cohort retention analysis for brands
  getCohortRetention: async (filters: Filters): Promise<CohortRetentionData> => {
    return await api.cohortRetention(filters);
  },

  // Brand switching flow analysis
  getBrandSwitching: async (filters: Filters): Promise<BrandSwitchingData> => {
    return await api.brandSwitching(filters);
  },

  // Journey funnel analysis
  getJourneyFunnel: async (filters: Filters, steps?: string[]): Promise<JourneyFunnelData> => {
    return await api.journeyFunnel(filters, steps);
  },

  // Journey path analysis (for Sankey diagrams)
  getJourneyPaths: async (filters: Filters, maxDepth?: number): Promise<JourneyPathData> => {
    return await api.journeyPaths(filters, maxDepth);
  },

  // Competitive benchmarking
  getBenchmarkComparison: async (filters: Filters): Promise<CompetitiveBenchmarkData> => {
    const brands = ['Coca-Cola', 'Pepsi', 'Sprite'];
    
    const metrics = [
      {
        name: 'Market Share',
        values: [22.9, 19.7, 15.2],
        unit: '%',
        format: 'percentage' as const
      },
      {
        name: 'Average Basket Value',
        values: [250, 235, 220],
        unit: '₱',
        format: 'currency' as const
      },
      {
        name: 'Customer Retention',
        values: [78.5, 73.2, 71.8],
        unit: '%',
        format: 'percentage' as const
      },
      {
        name: 'Purchase Frequency',
        values: [3.2, 2.8, 2.6],
        unit: 'times/month',
        format: 'number' as const
      }
    ];

    const deltas = [];
    for (let i = 0; i < metrics.length; i++) {
      const metric = metrics[i];
      for (let a = 0; a < brands.length; a++) {
        for (let b = a + 1; b < brands.length; b++) {
          const absoluteDelta = metric.values[a] - metric.values[b];
          const percentageDelta = (absoluteDelta / metric.values[b]) * 100;
          
          deltas.push({
            metric: metric.name,
            brandA: brands[a],
            brandB: brands[b],
            absoluteDelta: Math.round(absoluteDelta * 10) / 10,
            percentageDelta: Math.round(percentageDelta * 10) / 10
          });
        }
      }
    }

    return { brands, metrics, deltas };
  }
};

// Note: Fallback data is now handled in the main api.ts DAL pattern