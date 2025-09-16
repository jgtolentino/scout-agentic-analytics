'use client';

import { callEdgeFunction } from '../api';

// Dimension types
export type DimensionOption = {
  value: string;
  label: string;
  children?: DimensionOption[];
  metadata?: Record<string, any>;
};

export type CohortInfo = {
  id: string;
  label: string;
  period: string; // 'july_2024', 'aug_2024', etc.
  startDate: string;
  customerCount: number;
};

export type SegmentInfo = {
  id: string;
  label: string;
  description: string;
  customerCount: number;
  criteria: Record<string, any>;
};

// Dimension API functions
export const dimensionAPI = {
  // Brand hierarchy: Category → Brand → SKU
  getBrands: async (category?: string): Promise<DimensionOption[]> => {
    try {
      return await callEdgeFunction('dimensions/brands', { category });
    } catch (error) {
      console.warn('Brands API failed, using fallback data:', error);
      return getFallbackBrands(category);
    }
  },

  // Region hierarchy: Region → Province → City → Store
  getRegions: async (level?: 'region' | 'province' | 'city' | 'store', parent?: string): Promise<DimensionOption[]> => {
    try {
      return await callEdgeFunction('dimensions/regions', { level, parent });
    } catch (error) {
      console.warn('Regions API failed, using fallback data:', error);
      return getFallbackRegions(level, parent);
    }
  },

  // Available cohorts for analysis
  getCohorts: async (type?: 'monthly' | 'weekly' | 'quarterly'): Promise<CohortInfo[]> => {
    try {
      return await callEdgeFunction('dimensions/cohorts', { type });
    } catch (error) {
      console.warn('Cohorts API failed, using fallback data:', error);
      return getFallbackCohorts(type);
    }
  },

  // Customer segments
  getSegments: async (): Promise<SegmentInfo[]> => {
    try {
      return await callEdgeFunction('dimensions/segments');
    } catch (error) {
      console.warn('Segments API failed, using fallback data:', error);
      return getFallbackSegments();
    }
  },

  // SKUs for a specific brand
  getSKUs: async (brand: string): Promise<DimensionOption[]> => {
    try {
      return await callEdgeFunction('dimensions/skus', { brand });
    } catch (error) {
      console.warn('SKUs API failed, using fallback data:', error);
      return getFallbackSKUs(brand);
    }
  },

  // Stores for a specific city/region
  getStores: async (city?: string, region?: string): Promise<DimensionOption[]> => {
    try {
      return await callEdgeFunction('dimensions/stores', { city, region });
    } catch (error) {
      console.warn('Stores API failed, using fallback data:', error);
      return getFallbackStores(city, region);
    }
  }
};

// Fallback data for offline/development mode
function getFallbackBrands(category?: string): DimensionOption[] {
  const allBrands = [
    {
      value: 'Beverages',
      label: 'Beverages',
      children: [
        { value: 'Coca-Cola', label: 'Coca-Cola', metadata: { marketShare: 22.9 } },
        { value: 'Pepsi', label: 'Pepsi', metadata: { marketShare: 19.7 } },
        { value: 'Sprite', label: 'Sprite', metadata: { marketShare: 15.2 } },
        { value: 'Royal', label: 'Royal', metadata: { marketShare: 12.1 } },
        { value: '7-Up', label: '7-Up', metadata: { marketShare: 8.3 } }
      ]
    },
    {
      value: 'Snacks',
      label: 'Snacks',
      children: [
        { value: 'Oishi', label: 'Oishi', metadata: { marketShare: 18.5 } },
        { value: 'Jack n Jill', label: 'Jack n Jill', metadata: { marketShare: 16.2 } },
        { value: 'Lays', label: 'Lays', metadata: { marketShare: 14.8 } },
        { value: 'Pringles', label: 'Pringles', metadata: { marketShare: 11.3 } }
      ]
    },
    {
      value: 'Household',
      label: 'Household',
      children: [
        { value: 'Tide', label: 'Tide', metadata: { marketShare: 25.1 } },
        { value: 'Ariel', label: 'Ariel', metadata: { marketShare: 22.3 } },
        { value: 'Surf', label: 'Surf', metadata: { marketShare: 18.7 } }
      ]
    },
    {
      value: 'Personal Care',
      label: 'Personal Care',
      children: [
        { value: 'Palmolive', label: 'Palmolive', metadata: { marketShare: 19.2 } },
        { value: 'Head & Shoulders', label: 'Head & Shoulders', metadata: { marketShare: 16.8 } },
        { value: 'Pantene', label: 'Pantene', metadata: { marketShare: 14.5 } }
      ]
    }
  ];

  if (category) {
    const categoryBrands = allBrands.find(cat => cat.value === category);
    return categoryBrands?.children || [];
  }

  return allBrands;
}

function getFallbackRegions(level?: string, parent?: string): DimensionOption[] {
  const regionHierarchy: Record<string, DimensionOption[]> = {
    regions: [
      {
        value: 'NCR',
        label: 'National Capital Region (NCR)',
        metadata: { population: 13484462 }
      },
      {
        value: 'Luzon',
        label: 'Luzon',
        metadata: { population: 57470000 }
      },
      {
        value: 'Visayas',
        label: 'Visayas',
        metadata: { population: 20234000 }
      },
      {
        value: 'Mindanao',
        label: 'Mindanao',
        metadata: { population: 25537000 }
      }
    ],
    NCR: [
      { value: 'Metro Manila', label: 'Metro Manila', metadata: { cities: 16 } }
    ],
    Luzon: [
      { value: 'Laguna', label: 'Laguna', metadata: { cities: 30 } },
      { value: 'Cavite', label: 'Cavite', metadata: { cities: 23 } },
      { value: 'Batangas', label: 'Batangas', metadata: { cities: 32 } }
    ],
    'Metro Manila': [
      { value: 'Manila', label: 'Manila', metadata: { stores: 45 } },
      { value: 'Quezon City', label: 'Quezon City', metadata: { stores: 67 } },
      { value: 'Makati', label: 'Makati', metadata: { stores: 23 } },
      { value: 'Taguig', label: 'Taguig', metadata: { stores: 18 } }
    ]
  };

  if (!level || level === 'region') {
    return regionHierarchy.regions;
  }

  if (parent && regionHierarchy[parent]) {
    return regionHierarchy[parent];
  }

  return [];
}

function getFallbackCohorts(type?: string): CohortInfo[] {
  const cohorts = [
    {
      id: 'july_2024',
      label: 'July 2024 Cohort',
      period: 'july_2024',
      startDate: '2024-07-01',
      customerCount: 15420
    },
    {
      id: 'august_2024',
      label: 'August 2024 Cohort',
      period: 'august_2024',
      startDate: '2024-08-01',
      customerCount: 18750
    },
    {
      id: 'september_2024',
      label: 'September 2024 Cohort',
      period: 'september_2024',
      startDate: '2024-09-01',
      customerCount: 16890
    },
    {
      id: 'october_2024',
      label: 'October 2024 Cohort',
      period: 'october_2024',
      startDate: '2024-10-01',
      customerCount: 19230
    },
    {
      id: 'november_2024',
      label: 'November 2024 Cohort',
      period: 'november_2024',
      startDate: '2024-11-01',
      customerCount: 17650
    },
    {
      id: 'december_2024',
      label: 'December 2024 Cohort',
      period: 'december_2024',
      startDate: '2024-12-01',
      customerCount: 21450
    }
  ];

  if (type === 'quarterly') {
    return cohorts.filter((_, index) => index % 3 === 0);
  }

  return cohorts;
}

function getFallbackSegments(): SegmentInfo[] {
  return [
    {
      id: 'new_customers',
      label: 'New Customers',
      description: 'First-time visitors within the last 30 days',
      customerCount: 34500,
      criteria: { visits: 1, period: 'last_30_days' }
    },
    {
      id: 'returning_customers',
      label: 'Returning Customers',
      description: 'Customers with 2-5 visits in the last 90 days',
      customerCount: 67800,
      criteria: { visits: '2-5', period: 'last_90_days' }
    },
    {
      id: 'loyal_customers',
      label: 'Loyal Customers',
      description: 'Customers with 6+ visits and high engagement',
      customerCount: 23400,
      criteria: { visits: '6+', engagement: 'high' }
    },
    {
      id: 'whale_customers',
      label: 'Whale Customers',
      description: 'Top 5% of customers by lifetime value',
      customerCount: 5670,
      criteria: { percentile: 95, metric: 'lifetime_value' }
    }
  ];
}

function getFallbackSKUs(brand: string): DimensionOption[] {
  const skuMap: Record<string, DimensionOption[]> = {
    'Coca-Cola': [
      { value: 'COKE_330ML', label: 'Coca-Cola 330ml Can', metadata: { price: '₱35' } },
      { value: 'COKE_500ML', label: 'Coca-Cola 500ml Bottle', metadata: { price: '₱45' } },
      { value: 'COKE_1L', label: 'Coca-Cola 1L Bottle', metadata: { price: '₱65' } }
    ],
    'Pepsi': [
      { value: 'PEPSI_330ML', label: 'Pepsi 330ml Can', metadata: { price: '₱35' } },
      { value: 'PEPSI_500ML', label: 'Pepsi 500ml Bottle', metadata: { price: '₱45' } },
      { value: 'PEPSI_1L', label: 'Pepsi 1L Bottle', metadata: { price: '₱65' } }
    ],
    'Oishi': [
      { value: 'OISHI_PRAWN', label: 'Oishi Prawn Crackers', metadata: { price: '₱12' } },
      { value: 'OISHI_POTATO', label: 'Oishi Potato Fries', metadata: { price: '₱15' } },
      { value: 'OISHI_FISHDA', label: 'Oishi Fishda Crackers', metadata: { price: '₱10' } }
    ]
  };

  return skuMap[brand] || [];
}

function getFallbackStores(city?: string, region?: string): DimensionOption[] {
  const storeMap: Record<string, DimensionOption[]> = {
    'Manila': [
      { value: 'MNL_001', label: 'SM Manila Store 1', metadata: { type: 'Mall', size: 'Large' } },
      { value: 'MNL_002', label: 'Robinsons Manila', metadata: { type: 'Mall', size: 'Medium' } },
      { value: 'MNL_003', label: '7-Eleven Ermita', metadata: { type: 'Convenience', size: 'Small' } }
    ],
    'Quezon City': [
      { value: 'QC_001', label: 'SM North EDSA', metadata: { type: 'Mall', size: 'Large' } },
      { value: 'QC_002', label: 'Gateway Mall', metadata: { type: 'Mall', size: 'Medium' } },
      { value: 'QC_003', label: 'Trinoma Mall', metadata: { type: 'Mall', size: 'Large' } }
    ],
    'Makati': [
      { value: 'MKT_001', label: 'Greenbelt Mall', metadata: { type: 'Mall', size: 'Large' } },
      { value: 'MKT_002', label: 'Glorietta', metadata: { type: 'Mall', size: 'Large' } },
      { value: 'MKT_003', label: 'Ayala Center', metadata: { type: 'Mall', size: 'Large' } }
    ]
  };

  if (city && storeMap[city]) {
    return storeMap[city];
  }

  // Return all stores if no specific city
  return Object.values(storeMap).flat();
}