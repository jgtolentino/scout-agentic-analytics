import { chooseLLM } from "../shared/llm";
import { getTopAgents } from "./router";

export type PlanStep = {
  tool: string;
  params: any;
  reason: string;
};

export type Plan = {
  intent: string;
  steps: PlanStep[];
  confidence: number;
  fallback_reason?: string;
};

export async function plan(userQuery: string, context: any = {}): Promise<Plan> {
  try {
    const llm = chooseLLM();

    // Get top agent candidates as context
    const topAgents = getTopAgents(userQuery, 3);

    const systemPrompt = `You are Ask Suqi, an intelligent orchestrator for Scout v7 analytics platform.

Available tools and their capabilities:
- SEMANTIC_QUERY: Generate SQL over semantic layer with GROUP BY ROLLUP, filters, time grains. Use for: revenue, transactions, trends, breakdowns, aggregations.
- GEO_EXPORT: Create choropleth/heatmap visualizations by geographic hierarchy. Use for: maps, geographic analysis, location-based metrics.
- PARITY_CHECK: Validate data consistency between flat and crosstab views. Use for: data quality checks, validation, auditing.
- AUTO_SYNC_FLAT: Trigger Change Tracking export of latest data. Use for: refresh, sync, update, latest data.
- CATALOG_QA: Answer questions about data dictionary, metrics, system documentation. Use for: definitions, explanations, help.

Rules:
1. Return valid JSON only: {"intent": "...", "steps": [...], "confidence": 0.0-1.0}
2. Each step: {"tool": "TOOL_NAME", "params": {...}, "reason": "..."}
3. Never fabricate field names or values
4. For semantic queries, use these dimensions: date, region, city, barangay, store_name, brand, category, age_group, gender, emotion
5. For semantic queries, use these measures: revenue, transactions, basket_avg
6. For geo exports, use levels: region, city, barangay, store
7. If unsure, use CATALOG_QA
8. Confidence: 0.9+ for clear matches, 0.7+ for good matches, 0.5+ for uncertain

Common patterns:
- "Show revenue by category" → SEMANTIC_QUERY with dimensions: ["category"], measures: ["revenue"]
- "Map of sales in NCR" → GEO_EXPORT with level: "city", metric: "revenue", filters: {"region": ["NCR"]}
- "What is canonical_tx_id?" → CATALOG_QA with question: "What is canonical_tx_id?"
- "Check data quality" → PARITY_CHECK
- "Refresh data" → AUTO_SYNC_FLAT`;

    const userPrompt = `User query: "${userQuery}"

Context: ${JSON.stringify(context, null, 2)}

Top agent candidates based on signal matching:
${topAgents.map(a => `- ${a.code} (score: ${a.score}, confidence: ${a.confidence})`).join('\n')}

Analyze the query and create an execution plan. Respond with JSON only.`;

    const response = await llm.complete(systemPrompt, userPrompt);

    // Try to parse the LLM response
    let parsed: any;
    try {
      // Clean the response in case it has markdown or extra text
      const cleanResponse = response.replace(/```json\n?|```\n?/g, '').trim();
      parsed = JSON.parse(cleanResponse);
    } catch (parseError) {
      console.warn('Failed to parse LLM response:', response);
      return createFallbackPlan(userQuery, topAgents);
    }

    // Validate the parsed response
    if (!parsed.intent || !Array.isArray(parsed.steps)) {
      console.warn('Invalid LLM response structure:', parsed);
      return createFallbackPlan(userQuery, topAgents);
    }

    // Validate each step
    const validSteps = parsed.steps.filter((step: any) => {
      return step.tool && step.params && step.reason &&
             ['SEMANTIC_QUERY', 'GEO_EXPORT', 'PARITY_CHECK', 'AUTO_SYNC_FLAT', 'CATALOG_QA'].includes(step.tool);
    });

    if (validSteps.length === 0) {
      console.warn('No valid steps in LLM response');
      return createFallbackPlan(userQuery, topAgents);
    }

    return {
      intent: parsed.intent,
      steps: validSteps,
      confidence: Math.min(1.0, Math.max(0.0, parsed.confidence || 0.7))
    };

  } catch (error) {
    console.error('Planning error:', error);
    return createFallbackPlan(userQuery, getTopAgents(userQuery, 3));
  }
}

function createFallbackPlan(userQuery: string, topAgents: any[]): Plan {
  const q = userQuery.toLowerCase();

  // Simple rule-based fallback
  if (q.includes('revenue') || q.includes('sales') || q.includes('transaction') ||
      q.includes('breakdown') || q.includes('analysis') || q.includes('show')) {
    return {
      intent: "Get analytics data",
      steps: [{
        tool: "SEMANTIC_QUERY",
        params: {
          dimensions: ["category"],
          measures: ["revenue", "transactions"],
          rollup: true
        },
        reason: "User requested analytics data, defaulting to category breakdown"
      }],
      confidence: 0.6,
      fallback_reason: "LLM planning failed, used rule-based fallback"
    };
  }

  if (q.includes('map') || q.includes('geo') || q.includes('region') || q.includes('location')) {
    return {
      intent: "Geographic visualization",
      steps: [{
        tool: "GEO_EXPORT",
        params: {
          level: "city",
          metric: "revenue"
        },
        reason: "User requested geographic visualization"
      }],
      confidence: 0.6,
      fallback_reason: "LLM planning failed, used rule-based fallback"
    };
  }

  if (q.includes('parity') || q.includes('check') || q.includes('validate') || q.includes('quality')) {
    return {
      intent: "Data quality check",
      steps: [{
        tool: "PARITY_CHECK",
        params: { daysBack: 30 },
        reason: "User requested data quality validation"
      }],
      confidence: 0.7,
      fallback_reason: "LLM planning failed, used rule-based fallback"
    };
  }

  if (q.includes('sync') || q.includes('refresh') || q.includes('update') || q.includes('latest')) {
    return {
      intent: "Data sync operation",
      steps: [{
        tool: "AUTO_SYNC_FLAT",
        params: {},
        reason: "User requested data refresh/sync"
      }],
      confidence: 0.7,
      fallback_reason: "LLM planning failed, used rule-based fallback"
    };
  }

  // Default to catalog Q&A
  return {
    intent: "Information request",
    steps: [{
      tool: "CATALOG_QA",
      params: { question: userQuery },
      reason: "General information or definition request"
    }],
    confidence: 0.5,
    fallback_reason: "LLM planning failed, defaulting to catalog Q&A"
  };
}