/**
 * Scout AI Router API Client
 * Intelligent routing for Scout business intelligence queries
 */

export type AIContext = "executive" | "consumer" | "competition" | "geographic";

export interface DateRange {
  from: string;
  to: string;
}

export interface RoutePromptRequest {
  query: string;
  filters?: {
    region?: string;
    dateRange?: DateRange | string;
  };
  hint?: "auto" | AIContext;
  user_id?: string;
}

export interface RoutePromptResponse {
  intent: AIContext;
  route: string;
  params: {
    from: string;
    to: string;
    region: string | null;
  };
  data: any;
  explain: string;
  latency_ms: number;
}

export interface ScoutAIError {
  error: string;
  status?: number;
}

// Configuration
const USE_MOCK = (import.meta.env.VITE_USE_MOCK || "0") === "1";
const FUNCTIONS_URL = (import.meta.env.VITE_SUPABASE_FUNCTIONS_URL || "").replace(/\/$/, "");
const API_BASE = FUNCTIONS_URL || "/api/scout-ai"; // Dev proxy fallback

/**
 * Route a user prompt through the intelligent Scout AI router
 */
export async function routePrompt(payload: RoutePromptRequest): Promise<RoutePromptResponse> {
  // Mock mode for development/testing
  if (USE_MOCK) {
    return getMockResponse(payload.hint || "executive");
  }

  const endpoint = FUNCTIONS_URL 
    ? `${FUNCTIONS_URL}/scout_ai_router`
    : `${API_BASE}/router`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`HTTP ${response.status}: ${errorText}`);
    }

    return await response.json();

  } catch (error) {
    console.error("Scout AI Router Error:", error);
    
    // Fallback to executive context on error
    if (error instanceof Error) {
      throw new Error(`Router failed: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Generate mock response for development
 */
function getMockResponse(context: AIContext): RoutePromptResponse {
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  const mockData = {
    executive: {
      summary: {
        total_revenue: 15420000,
        avg_ticket: 850.75,
        total_orders: 18150,
        growth_mom: 12.5
      },
      trends: [
        { date: "2025-08-15", revenue: 520000, orders: 610 },
        { date: "2025-08-16", revenue: 480000, orders: 565 },
        { date: "2025-08-17", revenue: 610000, orders: 720 },
        { date: "2025-08-18", revenue: 580000, orders: 680 }
      ],
      kpis: [
        { name: "Revenue", value: 15420000, unit: "PHP" },
        { name: "Orders", value: 18150, unit: "count" },
        { name: "Avg Ticket", value: 850.75, unit: "PHP" },
        { name: "Growth (MoM)", value: 12.5, unit: "%" }
      ]
    },
    consumer: {
      personas: [
        { persona: "Premium Shopper", share: 25, avg_spend: 1250, frequency: 14 },
        { persona: "Family Buyer", share: 45, avg_spend: 680, frequency: 21 },
        { persona: "Convenience Seeker", share: 30, avg_spend: 420, frequency: 35 }
      ],
      behavior: [
        { hour: 9, avg_spend: 450, transaction_count: 120, peak_indicator: false },
        { hour: 12, avg_spend: 680, transaction_count: 280, peak_indicator: true },
        { hour: 18, avg_spend: 720, transaction_count: 340, peak_indicator: true },
        { hour: 21, avg_spend: 380, transaction_count: 95, peak_indicator: false }
      ],
      segments: [
        { name: "High Value", description: "Top 20% spenders", share: 20 },
        { name: "Regular", description: "Frequent shoppers", share: 45 },
        { name: "Occasional", description: "Infrequent buyers", share: 35 }
      ]
    },
    competition: {
      market_share: [
        { brand: "Our Brand", share_pct: 28.5, revenue_est: 12500000, trend: "growing" },
        { brand: "Competitor A", share_pct: 22.1, revenue_est: 9800000, trend: "stable" },
        { brand: "Competitor B", share_pct: 18.7, revenue_est: 8200000, trend: "declining" },
        { brand: "Others", share_pct: 30.7, revenue_est: 13500000, trend: "stable" }
      ],
      substitution: [
        { from_brand: "Competitor A", to_brand: "Our Brand", substitution_rate: 0.15, volume: 450 },
        { from_brand: "Competitor B", to_brand: "Our Brand", substitution_rate: 0.22, volume: 680 }
      ],
      competitive_gaps: [
        { gap: "Price Premium", impact: "Medium", opportunity: "Consider promotional pricing" },
        { gap: "Product Variety", impact: "High", opportunity: "Expand SKU portfolio" }
      ]
    },
    geographic: {
      regional_performance: [
        { region: "NCR", revenue: 8500000, orders: 9800, stores: 45, revenue_per_store: 188888.89, growth_rate: 15.2 },
        { region: "Region IV-A", revenue: 3200000, orders: 3900, stores: 22, revenue_per_store: 145454.55, growth_rate: 8.7 },
        { region: "Region III", revenue: 2100000, orders: 2650, stores: 18, revenue_per_store: 116666.67, growth_rate: 12.1 }
      ],
      heatmap_data: [
        { lat: 14.5995, lng: 120.9842, intensity: 0.85, location_name: "Makati CBD", revenue: 1250000 },
        { lat: 14.6507, lng: 121.0467, intensity: 0.72, location_name: "Ortigas Center", revenue: 980000 },
        { lat: 14.5764, lng: 121.0851, intensity: 0.68, location_name: "BGC", revenue: 890000 }
      ],
      store_density: [
        { area: "Metro Manila", store_count: 45, population: 13484462, density_ratio: 33.4, market_penetration: 8.2 },
        { area: "Cavite", store_count: 12, population: 3678301, density_ratio: 32.6, market_penetration: 6.8 }
      ]
    }
  };

  return {
    intent: context,
    route: `mock:scout_ai_${context}`,
    params: {
      from: thirtyDaysAgo.toISOString(),
      to: now.toISOString(),
      region: null
    },
    data: mockData[context],
    explain: "mock=development_mode",
    latency_ms: Math.floor(Math.random() * 100) + 50
  };
}

/**
 * Helper function to format dates for API calls
 */
export function formatDateRange(range?: DateRange | string): DateRange {
  if (typeof range === "string") {
    // Handle common string formats
    const now = new Date();
    switch (range) {
      case "today":
        return {
          from: new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString(),
          to: now.toISOString()
        };
      case "this_week":
        const weekStart = new Date(now.getTime() - (now.getDay() * 24 * 60 * 60 * 1000));
        return {
          from: weekStart.toISOString(),
          to: now.toISOString()
        };
      case "this_month":
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
        return {
          from: monthStart.toISOString(),
          to: now.toISOString()
        };
      case "last_30_days":
      default:
        const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
        return {
          from: thirtyDaysAgo.toISOString(),
          to: now.toISOString()
        };
    }
  }

  if (range?.from && range?.to) {
    return range;
  }

  // Default to last 30 days
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));
  return {
    from: thirtyDaysAgo.toISOString(),
    to: now.toISOString()
  };
}

/**
 * Get user ID from authentication context
 */
export function getCurrentUserId(): string | null {
  try {
    // Try to get from Supabase auth
    if (typeof window !== "undefined" && (window as any).supabase) {
      const { data } = (window as any).supabase.auth.getUser();
      return data?.user?.id || null;
    }

    // Fallback: try localStorage or session storage
    return localStorage.getItem("supabase.auth.user_id") || 
           sessionStorage.getItem("supabase.auth.user_id") ||
           null;
  } catch (error) {
    console.warn("Could not determine user ID:", error);
    return null;
  }
}