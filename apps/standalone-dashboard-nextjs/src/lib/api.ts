'use client';

import { ENV } from './env';

// Edge Function caller
export async function callEdgeFunction<T>(
  functionName: string, 
  body: any = {},
  options: RequestInit = {}
): Promise<T> {
  const baseUrl = ENV.SUPABASE_URL;
  const anonKey = ENV.SUPABASE_ANON_KEY;
  const functionBase = ENV.SUPABASE_FUNCTIONS_URL || '/functions/v1';
  
  if (!baseUrl || !anonKey) {
    console.warn(`Edge function ${functionName} called but Supabase not configured, using mock data`);
    throw new Error('Supabase not configured');
  }
  
  const url = `${baseUrl}${functionBase}/${functionName}`;
  
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${anonKey}`,
      ...options.headers,
    },
    body: JSON.stringify(body),
    cache: "no-store",
    ...options,
  });

  if (!response.ok) {
    throw new Error(`Edge function ${functionName} failed: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

// Specific API functions with fallback data
export const api = {
  executive: async (filters: any) => {
    try {
      return await callEdgeFunction('executive', { filters });
    } catch (error) {
      console.warn('Executive API failed, using fallback data:', error);
      return {
        kpis: {
          purchases: 1850717,
          totalSpend: '₱ 44,053,400',
          topCategory: 'Beverages'
        },
        trend: {
          x: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          y: [3.5, 3.2, 3.6, 3.3, 3.8, 4.1]
        },
        categories: {
          labels: ['Beverages', 'Snacks', 'Household', 'Personal Care', 'Tobacco'],
          values: [87619, 38256, 27267, 26913, 22734]
        },
        performance: {
          categories: ['Personal Care', 'Beverages', 'Household', 'Snacks', 'Tobacco'],
          values: [59, 52, 50, 48, 47]
        }
      };
    }
  },

  trends: async (filters: any) => {
    try {
      return await callEdgeFunction('trends', { filters });
    } catch (error) {
      console.warn('Trends API failed, using fallback data:', error);
      return {
        transactions: {
          x: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          y: [420, 380, 440, 390, 460, 510]
        },
        seasonal: {
          x: ['Q1', 'Q2', 'Q3', 'Q4'],
          y: [1240, 1350, 980, 1580]
        },
        weekly: {
          revenue: { x: ['Week 1', 'Week 2', 'Week 3', 'Week 4'], y: [85, 92, 78, 95] },
          units: { x: ['Week 1', 'Week 2', 'Week 3', 'Week 4'], y: [45, 52, 38, 58] }
        }
      };
    }
  },

  productMix: async (filters: any) => {
    try {
      return await callEdgeFunction('product_mix', { filters });
    } catch (error) {
      console.warn('Product Mix API failed, using fallback data:', error);
      return {
        categoryDistribution: {
          labels: ['Beverages', 'Snacks', 'Household', 'Personal Care', 'Tobacco'],
          values: [35, 25, 18, 12, 10]
        },
        priceSegments: {
          x: ['Premium', 'Mid-range', 'Budget'],
          y: [42, 38, 20]
        },
        brandMatrix: {
          x: [45, 35, 25, 20, 15, 12, 8, 6, 4, 2],
          y: [22, 18, 15, 12, 8, 6, 4, 3, 2, 1],
          text: ['Coca-Cola', 'Pepsi', 'Sprite', 'Royal', 'Sarsi', 'Mountain Dew', 'Fanta', '7-Up', 'Mirinda', 'Others'],
          size: [25, 22, 18, 15, 12, 10, 8, 6, 4, 2]
        }
      };
    }
  },

  behavior: async (filters: any) => {
    try {
      return await callEdgeFunction('behavior', { filters });
    } catch (error) {
      console.warn('Behavior API failed, using fallback data:', error);
      const hours = ['6a', '9a', '12p', '3p', '6p', '9p'];
      const dow = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return {
        heatmap: {
          x: hours,
          y: dow,
          z: dow.map((_, r) => hours.map((_, c) => Math.round(40 + 20 * Math.sin((r + c) / 2))))
        },
        channels: {
          x: ['Direct', 'Search', 'Social', 'Referral', 'Email'],
          y: [32, 28, 18, 14, 8]
        },
        basket: {
          x: [120, 150, 190, 210, 260],
          y: [1.1, 1.2, 1.35, 1.42, 1.55],
          text: ['New', 'Repeat', 'Loyal', 'Promo', 'Whale'],
          size: [12, 16, 22, 18, 26]
        }
      };
    }
  },

  profiling: async (filters: any) => {
    try {
      return await callEdgeFunction('profiling', { filters });
    } catch (error) {
      console.warn('Profiling API failed, using fallback data:', error);
      return {
        gender: {
          labels: ['Female', 'Male', 'Other'],
          values: [51.5, 46, 2.5]
        },
        age: {
          x: ['18–24', '25–34', '35–44', '45–54', '55–64', '65+'],
          y: [770, 1800, 1200, 680, 370, 160]
        },
        income: {
          y: ['<25k', '$25–49k', '$50–74k', '$75–99k', '$100–149k', '>$150k'],
          x: [690, 1200, 1100, 760, 790, 460]
        },
        education: {
          y: ['HS or less', 'HS/GED', "Bachelor's", 'Graduate', 'Prefer not to say'],
          x: [46, 1900, 2200, 870, 32]
        }
      };
    }
  },

  competition: async (filters: any) => {
    try {
      return await callEdgeFunction('competition', { filters });
    } catch (error) {
      console.warn('Competition API failed, using fallback data:', error);
      return {
        marketShare: {
          cocaCola: {
            x: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
            y: [18, 19, 19.5, 20, 20.5, 21, 20.2, 20.8, 21.1, 21.4, 22.2, 22.9]
          },
          pepsi: {
            x: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
            y: [15, 15.3, 16, 16.2, 16.8, 17.4, 17.9, 18.1, 18.4, 18.8, 19.2, 19.7]
          }
        },
        brandShare: {
          x: ['Alaska', 'Oishi', 'Nestlé', 'Unilever', 'P&G'],
          y: [23, 19, 17, 16, 12]
        },
        scorecard: {
          x: ['Price', 'Availability', 'Promo', 'Shelf', 'Delivery'],
          y: ['You', 'Brand A', 'Brand B', 'Brand C'],
          z: [
            [4.3, 4.0, 4.6, 4.1, 4.5],
            [4.1, 3.9, 4.2, 3.8, 4.1],
            [3.8, 3.7, 4.0, 3.5, 3.9],
            [4.0, 3.8, 4.1, 3.7, 3.8]
          ]
        }
      };
    }
  },

  geography: async (filters: any) => {
    try {
      return await callEdgeFunction('geography', { filters });
    } catch (error) {
      console.warn('Geography API failed, using fallback data:', error);
      return {
        regions: {
          regions: ['NCR', 'Luzon', 'Visayas', 'Mindanao'],
          revenue: [920, 860, 540, 480]
        },
        cities: {
          x: ['Metro Manila', 'Cebu', 'Davao', 'Baguio', 'Iloilo'],
          y: [310, 210, 180, 130, 120]
        },
        footprint: {
          x: [121.0, 123.9, 125.6, 120.6, 122.5],
          y: [14.6, 10.3, 7.1, 16.4, 10.7],
          text: ['Manila', 'Cebu', 'Davao', 'Baguio', 'Iloilo'],
          size: [22, 18, 16, 12, 12]
        }
      };
    }
  },

  // Journey Analytics APIs - extend existing pattern
  cohortRetention: async (filters: any) => {
    try {
      return await callEdgeFunction('competitive-cohorts', { filters });
    } catch (error) {
      console.warn('Cohort Retention API failed, using fallback data:', error);
      return generateCohortFallback(filters);
    }
  },

  brandSwitching: async (filters: any) => {
    try {
      return await callEdgeFunction('competitive-switching', { filters });
    } catch (error) {
      console.warn('Brand Switching API failed, using fallback data:', error);
      return generateSwitchingFallback(filters);
    }
  },

  journeyFunnel: async (filters: any, steps?: string[]) => {
    try {
      return await callEdgeFunction('competitive-funnel', { filters, steps });
    } catch (error) {
      console.warn('Journey Funnel API failed, using fallback data:', error);
      return generateFunnelFallback(filters, steps);
    }
  },

  journeyPaths: async (filters: any, maxDepth?: number) => {
    try {
      return await callEdgeFunction('competitive-paths', { filters, maxDepth });
    } catch (error) {
      console.warn('Journey Paths API failed, using fallback data:', error);
      return generatePathsFallback(filters);
    }
  }
};

// Fallback data generators that match your existing data patterns
function generateCohortFallback(filters: any) {
  const cohorts = ['Jul 2024', 'Aug 2024', 'Sep 2024', 'Oct 2024', 'Nov 2024', 'Dec 2024'];
  const periods = ['Month 0', 'Month 1', 'Month 2', 'Month 3', 'Month 4', 'Month 5'];
  
  const retention = cohorts.map((_, cohortIndex) => {
    return periods.map((_, periodIndex) => {
      if (periodIndex === 0) return 100;
      const baseRetention = 85 - (periodIndex * 12);
      const cohortVariation = (cohortIndex - 2.5) * 2;
      return Math.max(20, Math.min(100, baseRetention + cohortVariation));
    });
  });

  return {
    cohort: filters.cohort || 'all',
    periods,
    retention,
    customerCounts: [15420, 18750, 16890, 19230, 17650, 21450],
    metadata: {
      totalCohorts: cohorts.length,
      averageRetention: 73.2,
      bestPerformingCohort: 'Dec 2024'
    }
  };
}

function generateSwitchingFallback(filters: any) {
  const brands = ['Coca-Cola', 'Pepsi', 'Sprite', 'Royal', '7-Up'];
  
  const nodes = brands.map((brand, index) => ({
    id: brand,
    label: brand,
    value: 1000 + index * 200,
    color: ['#ff6b35', '#004e7c', '#00a6d6', '#ff9f1c', '#2fa84f'][index]
  }));

  const links = [];
  for (let from = 0; from < brands.length; from++) {
    for (let to = 0; to < brands.length; to++) {
      if (from !== to) {
        const switchCount = Math.floor(Math.random() * 150) + 50;
        const percentage = (switchCount / nodes[from].value) * 100;
        
        links.push({
          source: brands[from],
          target: brands[to],
          value: switchCount,
          percentage: Math.round(percentage * 10) / 10
        });
      }
    }
  }

  const matrix = brands.map(() => new Array(brands.length).fill(0));
  links.forEach(link => {
    const fromIndex = brands.indexOf(link.source);
    const toIndex = brands.indexOf(link.target);
    matrix[fromIndex][toIndex] = link.value;
  });

  return {
    nodes,
    links: links.sort((a, b) => b.value - a.value).slice(0, 10),
    switchingMatrix: { brands, matrix },
    metadata: {
      totalSwitches: links.reduce((sum, link) => sum + link.value, 0),
      retentionRate: 78.5,
      topSwitchingPair: { from: 'Coca-Cola', to: 'Pepsi', percentage: 12.3 }
    }
  };
}

function generateFunnelFallback(filters: any, steps?: string[]) {
  const defaultSteps = steps || ['Entry', 'Browse', 'Pickup', 'Queue', 'Pay'];
  
  let currentCount = 10000;
  const stepData = defaultSteps.map((step, index) => {
    if (index === 0) {
      return { name: step, count: currentCount, percentage: 100 };
    }
    
    const dropoffRate = [0, 0.15, 0.25, 0.08, 0.12][index] || 0.1;
    const newCount = Math.floor(currentCount * (1 - dropoffRate));
    const percentage = (newCount / 10000) * 100;
    const dropoff = currentCount - newCount;
    
    currentCount = newCount;
    
    return {
      name: step,
      count: newCount,
      percentage: Math.round(percentage * 10) / 10,
      dropoff
    };
  });

  const topPaths = [
    { path: ['Entry', 'Browse', 'Pickup', 'Pay'], count: 4250, percentage: 42.5, conversionRate: 85.0 },
    { path: ['Entry', 'Browse', 'Queue', 'Pay'], count: 2100, percentage: 21.0, conversionRate: 75.0 },
    { path: ['Entry', 'Pickup', 'Pay'], count: 1800, percentage: 18.0, conversionRate: 90.0 },
    { path: ['Entry', 'Browse', 'Exit'], count: 1500, percentage: 15.0, conversionRate: 0 },
    { path: ['Entry', 'Exit'], count: 350, percentage: 3.5, conversionRate: 0 }
  ];

  return {
    steps: stepData,
    conversion: Math.round((currentCount / 10000) * 1000) / 10,
    averageTime: 12.5,
    pathAnalysis: { topPaths }
  };
}

function generatePathsFallback(filters: any) {
  const nodes = [
    { id: 'entry', label: 'Entry', type: 'entry' as const, value: 10000 },
    { id: 'beverages', label: 'Beverages', type: 'zone' as const, value: 6500 },
    { id: 'snacks', label: 'Snacks', type: 'zone' as const, value: 4200 },
    { id: 'household', label: 'Household', type: 'zone' as const, value: 3800 },
    { id: 'pickup', label: 'Pickup', type: 'action' as const, value: 7500 },
    { id: 'queue', label: 'Queue', type: 'action' as const, value: 6800 },
    { id: 'pay', label: 'Pay', type: 'action' as const, value: 6200 },
    { id: 'exit', label: 'Exit', type: 'exit' as const, value: 10000 }
  ];

  const links = [
    { source: 'entry', target: 'beverages', value: 6500 },
    { source: 'entry', target: 'snacks', value: 2000 },
    { source: 'entry', target: 'household', value: 1500 },
    { source: 'beverages', target: 'snacks', value: 2200 },
    { source: 'beverages', target: 'pickup', value: 4300 },
    { source: 'snacks', target: 'household', value: 1800 },
    { source: 'snacks', target: 'pickup', value: 2400 },
    { source: 'household', target: 'pickup', value: 800 },
    { source: 'pickup', target: 'queue', value: 6800 },
    { source: 'queue', target: 'pay', value: 6200 },
    { source: 'pay', target: 'exit', value: 6200 },
    { source: 'beverages', target: 'exit', value: 200 },
    { source: 'snacks', target: 'exit', value: 200 },
    { source: 'queue', target: 'exit', value: 600 }
  ];

  const states = nodes.map(n => n.id);
  const probabilities = states.map(() => new Array(states.length).fill(0));
  
  links.forEach(link => {
    const fromIndex = states.indexOf(link.source);
    const toIndex = states.indexOf(link.target);
    const sourceTotal = nodes.find(n => n.id === link.source)?.value || 1;
    probabilities[fromIndex][toIndex] = link.value / sourceTotal;
  });

  return {
    nodes,
    links,
    transitionMatrix: { states, probabilities }
  };
}