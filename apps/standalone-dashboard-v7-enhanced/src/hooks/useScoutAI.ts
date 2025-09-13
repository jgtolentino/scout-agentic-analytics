/**
 * Scout AI Hook - Business Intelligence Assistant
 * Integrates with Scout intelligent router for retail analytics insights
 */
import { useState, useCallback } from 'react';
import { routePrompt, getCurrentUserId, formatDateRange } from '../lib/scout-ai-api';
import type { AIContext, DateRange, RoutePromptResponse } from '../lib/scout-ai-api';

export type ScoutAIContext = AIContext;

export interface ScoutAIMessage {
  role: 'user' | 'assistant';
  content: string;
  type?: 'text' | 'insight' | 'chart' | 'data';
  data?: any;
  recommendations?: string[];
  timestamp: Date;
  intent?: AIContext;
  route?: string;
  latency?: number;
}

export interface ScoutInsight {
  title: string;
  value: string | number;
  change?: {
    value: number;
    period: string;
    direction: 'up' | 'down' | 'neutral';
  };
  chart?: {
    type: 'line' | 'bar' | 'pie' | 'trend';
    data: any[];
  };
  context: string;
  actionable: string[];
}

interface UseScoutAIReturn {
  messages: ScoutAIMessage[];
  isLoading: boolean;
  error: string | null;
  sendMessage: (content: string, filters?: { region?: string; dateRange?: DateRange | string }) => Promise<void>;
  clearMessages: () => void;
  generateInsight: (metric: string) => Promise<ScoutInsight>;
  getRecommendations: (context: string) => string[];
  askPrompt: (query: string, filters?: { region?: string; dateRange?: DateRange | string }, hint?: "auto" | AIContext) => Promise<RoutePromptResponse>;
}

export function useScoutAI(context: ScoutAIContext = 'executive'): UseScoutAIReturn {
  const [messages, setMessages] = useState<ScoutAIMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Context-specific configurations
  const contextConfig = {
    executive: {
      description: "Executive KPIs, revenue trends, and performance metrics",
      quickActions: ["Show revenue trends", "What are our KPIs?", "Monthly growth analysis", "Performance summary"],
      defaultFilters: { dateRange: "this_month" }
    },
    consumer: {
      description: "Customer behavior, personas, and shopping patterns",
      quickActions: ["Show customer segments", "Shopping behavior analysis", "Peak hours", "Customer personas"],
      defaultFilters: { dateRange: "last_30_days" }
    },
    competition: {
      description: "Market share, brand analysis, and competitive positioning",
      quickActions: ["Market share analysis", "Brand comparison", "Competitor insights", "Substitution patterns"],
      defaultFilters: { dateRange: "this_month" }
    },
    geographic: {
      description: "Regional performance, location trends, and geographic analysis",
      quickActions: ["Regional performance", "Store density map", "Geographic trends", "Location analysis"],
      defaultFilters: { dateRange: "this_month" }
    }
  };

  /**
   * Main function to ask prompts via the intelligent router
   */
  const askPrompt = useCallback(async (
    query: string, 
    filters?: { region?: string; dateRange?: DateRange | string }, 
    hint: "auto" | AIContext = "auto"
  ): Promise<RoutePromptResponse> => {
    setError(null);
    setIsLoading(true);

    try {
      const userId = getCurrentUserId();
      const dateRange = filters?.dateRange ? formatDateRange(filters.dateRange) : formatDateRange("last_30_days");
      
      const response = await routePrompt({
        query: query.trim(),
        filters: {
          region: filters?.region,
          dateRange
        },
        hint: hint === "auto" ? context : hint,
        user_id: userId || undefined
      });

      return response;

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
      setError(errorMessage);
      throw new Error(errorMessage);
    } finally {
      setIsLoading(false);
    }
  }, [context]);

  /**
   * Send a message and add to conversation
   */
  const sendMessage = useCallback(async (
    content: string, 
    filters?: { region?: string; dateRange?: DateRange | string }
  ) => {
    if (!content.trim()) return;

    setError(null);
    setIsLoading(true);

    // Add user message immediately
    const userMessage: ScoutAIMessage = {
      role: 'user',
      content: content.trim(),
      timestamp: new Date()
    };

    setMessages(prev => [...prev, userMessage]);

    try {
      // Route the prompt through our intelligent router
      const response = await askPrompt(content, filters, "auto");

      // Generate assistant response based on the data
      const assistantContent = generateResponseContent(response);
      
      const assistantMessage: ScoutAIMessage = {
        role: 'assistant',
        content: assistantContent,
        type: 'data',
        data: response.data,
        timestamp: new Date(),
        intent: response.intent,
        route: response.route,
        latency: response.latency_ms,
        recommendations: generateRecommendations(response.intent, response.data)
      };

      setMessages(prev => [...prev, assistantMessage]);

    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to process your request';
      setError(errorMessage);

      // Add error message to conversation
      const errorResponse: ScoutAIMessage = {
        role: 'assistant',
        content: `I apologize, but I encountered an error: ${errorMessage}. Please try rephrasing your question or contact support if the issue persists.`,
        type: 'text',
        timestamp: new Date()
      };

      setMessages(prev => [...prev, errorResponse]);
    } finally {
      setIsLoading(false);
    }
  }, [askPrompt]);

  /**
   * Generate human-readable content from router response
   */
  function generateResponseContent(response: RoutePromptResponse): string {
    const { intent, data, latency_ms } = response;
    
    try {
      switch (intent) {
        case 'executive':
          return generateExecutiveResponse(data);
        case 'consumer':
          return generateConsumerResponse(data);
        case 'competition':
          return generateCompetitionResponse(data);
        case 'geographic':
          return generateGeographicResponse(data);
        default:
          return `I found some ${intent} insights for you. The data shows various metrics and trends that might be helpful for your analysis.`;
      }
    } catch (error) {
      console.warn('Error generating response content:', error);
      return `I've retrieved your ${intent} data successfully. You can explore the detailed metrics and trends in the data panel.`;
    }
  }

  function generateExecutiveResponse(data: any): string {
    if (!data?.summary) return "I've retrieved executive performance data for you.";
    
    const { total_revenue, avg_ticket, total_orders, growth_mom } = data.summary;
    
    return `📊 **Executive Summary**

**Key Performance Indicators:**
• Total Revenue: ₱${total_revenue?.toLocaleString() || 'N/A'}
• Average Ticket: ₱${avg_ticket?.toFixed(2) || 'N/A'}
• Total Orders: ${total_orders?.toLocaleString() || 'N/A'}
• Month-over-Month Growth: ${growth_mom ? (growth_mom > 0 ? '+' : '') + growth_mom.toFixed(1) + '%' : 'N/A'}

${growth_mom > 10 ? '🟢 Strong growth momentum!' : growth_mom > 0 ? '🟡 Positive growth trend.' : '🔴 Growth needs attention.'}`;
  }

  function generateConsumerResponse(data: any): string {
    if (!data?.personas) return "I've retrieved consumer behavior data for you.";
    
    const topPersona = data.personas?.[0];
    const peakHour = data.behavior?.reduce((max: any, curr: any) => 
      curr.transaction_count > (max?.transaction_count || 0) ? curr : max, null);
    
    return `👥 **Consumer Insights**

**Top Customer Persona:** ${topPersona?.persona || 'N/A'} (${topPersona?.share || 0}% of customers)
• Average Spend: ₱${topPersona?.avg_spend?.toLocaleString() || 'N/A'}
• Shopping Frequency: Every ${topPersona?.frequency || 'N/A'} days

**Shopping Patterns:**
• Peak Hour: ${peakHour?.hour || 'N/A'}:00 (${peakHour?.transaction_count || 0} transactions)
• Peak Average Spend: ₱${peakHour?.avg_spend || 0}

💡 Focus on ${topPersona?.persona || 'key personas'} during peak hours for maximum impact.`;
  }

  function generateCompetitionResponse(data: any): string {
    if (!data?.market_share) return "I've retrieved competitive analysis data for you.";
    
    const ourShare = data.market_share?.find((brand: any) => 
      brand.brand?.toLowerCase().includes('our') || brand.brand?.toLowerCase().includes('us'));
    const topCompetitor = data.market_share?.find((brand: any) => 
      !brand.brand?.toLowerCase().includes('our') && !brand.brand?.toLowerCase().includes('us'));
    
    return `🏆 **Competitive Analysis**

**Our Market Position:**
• Market Share: ${ourShare?.share_pct?.toFixed(1) || 'N/A'}%
• Trend: ${ourShare?.trend || 'Unknown'}
• Est. Revenue: ₱${ourShare?.revenue_est?.toLocaleString() || 'N/A'}

**Top Competitor:** ${topCompetitor?.brand || 'N/A'}
• Market Share: ${topCompetitor?.share_pct?.toFixed(1) || 'N/A'}%
• Trend: ${topCompetitor?.trend || 'Unknown'}

${data.substitution?.length ? `🔄 ${data.substitution.length} substitution patterns identified` : ''}`;
  }

  function generateGeographicResponse(data: any): string {
    if (!data?.regional_performance) return "I've retrieved geographic performance data for you.";
    
    const topRegion = data.regional_performance?.[0];
    const totalStores = data.regional_performance?.reduce((sum: number, region: any) => 
      sum + (region.stores || 0), 0);
    
    return `🗺️ **Geographic Performance**

**Top Performing Region:** ${topRegion?.region || 'N/A'}
• Revenue: ₱${topRegion?.revenue?.toLocaleString() || 'N/A'}
• Orders: ${topRegion?.orders?.toLocaleString() || 'N/A'}
• Growth: ${topRegion?.growth_rate ? (topRegion.growth_rate > 0 ? '+' : '') + topRegion.growth_rate.toFixed(1) + '%' : 'N/A'}

**Network Overview:**
• Total Stores: ${totalStores || 'N/A'}
• Revenue per Store: ₱${topRegion?.revenue_per_store?.toLocaleString() || 'N/A'}

${data.heatmap_data?.length ? `📍 ${data.heatmap_data.length} high-intensity locations mapped` : ''}`;
  }

  /**
   * Generate recommendations based on intent and data
   */
  function generateRecommendations(intent: AIContext, data: any): string[] {
    const recommendations: Record<AIContext, string[]> = {
      executive: [
        "Review monthly targets and adjust forecasts",
        "Analyze top-performing channels for scaling",
        "Monitor key metrics daily for early trend detection",
        "Consider seasonal adjustments for future periods"
      ],
      consumer: [
        "Optimize marketing during peak shopping hours",
        "Develop targeted campaigns for top personas",
        "Implement loyalty programs for frequent shoppers",
        "A/B test messaging for different customer segments"
      ],
      competition: [
        "Monitor competitor pricing and promotions",
        "Identify differentiation opportunities",
        "Track market share changes monthly",
        "Analyze substitution patterns for product strategy"
      ],
      geographic: [
        "Focus expansion efforts on high-performing regions",
        "Optimize store locations based on density analysis",
        "Tailor regional marketing to local preferences",
        "Consider performance-based resource allocation"
      ]
    };

    return recommendations[intent] || [];
  }

  /**
   * Clear conversation messages
   */
  const clearMessages = useCallback(() => {
    setMessages([]);
    setError(null);
  }, []);

  /**
   * Generate insights for specific metrics (legacy compatibility)
   */
  const generateInsight = useCallback(async (metric: string): Promise<ScoutInsight> => {
    try {
      const response = await askPrompt(`Show insights for ${metric}`, contextConfig[context].defaultFilters);
      
      return {
        title: `${metric} Analysis`,
        value: "See detailed data",
        context: response.explain,
        actionable: generateRecommendations(response.intent, response.data)
      };
    } catch (error) {
      throw new Error(`Failed to generate insight for ${metric}`);
    }
  }, [askPrompt, context]);

  /**
   * Get context-specific recommendations
   */
  const getRecommendations = useCallback((contextName: string): string[] => {
    const ctx = contextName as AIContext;
    return generateRecommendations(ctx, null);
  }, []);

  return {
    messages,
    isLoading,
    error,
    sendMessage,
    clearMessages,
    generateInsight,
    getRecommendations,
    askPrompt
  };
}