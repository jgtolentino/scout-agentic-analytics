import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

// Mock knowledge base - in production, replace with vector store
const KNOWLEDGE_BASE = [
  {
    id: "canonical_tx_id",
    title: "Canonical Transaction ID",
    content: "canonical_tx_id is the normalized transaction identifier used for joining data across tables. It's derived from the original transaction ID by converting to lowercase and removing hyphens. The normalized version (canonical_tx_id_norm) is stored as a persisted computed column for efficient joins.",
    tags: ["transaction", "id", "normalization", "joins"],
    type: "data_model",
    confidence: 0.95
  },
  {
    id: "si_only_timestamps",
    title: "SI-Only Timestamp Policy",
    content: "SI-only timestamp policy means that all production views and exports use timestamps exclusively from SalesInteractions table, never from PayloadTransactions. This ensures data consistency and prevents timestamp contamination from unreliable payload sources.",
    tags: ["timestamp", "salesinteractions", "data_quality"],
    type: "policy",
    confidence: 0.9
  },
  {
    id: "change_tracking",
    title: "Change Tracking",
    content: "Change Tracking is enabled on key tables to efficiently detect and export only changed data. The auto-sync system uses CHANGE_TRACKING_CURRENT_VERSION() to identify deltas since the last export, making the ETL process highly efficient for large datasets.",
    tags: ["etl", "change_tracking", "delta", "performance"],
    type: "architecture",
    confidence: 0.9
  },
  {
    id: "medallion_architecture",
    title: "Medallion Architecture",
    content: "Scout v7 follows medallion architecture: Bronze (raw ingested data), Silver (cleaned and normalized), Gold (business-ready aggregated views), and Platinum (analytics-optimized materialized views). This ensures data quality progression and clear separation of concerns.",
    tags: ["architecture", "bronze", "silver", "gold", "platinum"],
    type: "architecture",
    confidence: 0.9
  },
  {
    id: "task_framework",
    title: "Task Framework",
    content: "The task framework provides comprehensive tracking of all ETL operations through system tables. It includes task registration, run tracking, heartbeats, and metrics collection. Key procedures include sp_task_register, sp_task_run_begin, sp_task_heartbeat, and sp_task_run_end.",
    tags: ["etl", "tracking", "tasks", "monitoring"],
    type: "system",
    confidence: 0.95
  },
  {
    id: "parity_checking",
    title: "Parity Checking",
    content: "Parity checking compares record counts between flat export (gold.vw_FlatExport) and crosstab views to ensure data consistency. The system runs automated parity checks and alerts if differences exceed 1% threshold, indicating potential data quality issues.",
    tags: ["data_quality", "validation", "parity", "monitoring"],
    type: "quality",
    confidence: 0.9
  },
  {
    id: "revenue_metric",
    title: "Revenue Calculation",
    content: "Revenue is calculated from the 'amount' field in transactions, representing the total sales value. It's aggregated using SUM() in semantic queries and can be broken down by various dimensions like category, brand, store, time period, etc.",
    tags: ["metrics", "revenue", "amount", "aggregation"],
    type: "metrics",
    confidence: 0.9
  },
  {
    id: "basket_count",
    title: "Basket Count",
    content: "Basket count represents the number of items in a single transaction. Average basket size is calculated using AVG(basket_count) and can be used to analyze customer purchase behavior and product affinity.",
    tags: ["metrics", "basket", "items", "customer_behavior"],
    type: "metrics",
    confidence: 0.85
  },
  {
    id: "semantic_layer",
    title: "Semantic Query Layer",
    content: "The semantic layer provides a safe, parameterized SQL interface with predefined dimensions (date, region, city, brand, category, etc.) and measures (revenue, transactions, basket_avg). It supports GROUP BY ROLLUP for automatic subtotals and various filtering operations.",
    tags: ["semantic", "sql", "api", "dimensions", "measures"],
    type: "api",
    confidence: 0.9
  },
  {
    id: "agent_system",
    title: "Scout v7 Agent System",
    content: "Scout v7 includes 16 registered agents in the SuperClaude framework, including auto-sync, parity check, semantic query, geo export, and various analysis agents. All agents are enabled by default and follow the Bruno secure executor model with no credentials exposed to LLMs.",
    tags: ["agents", "superclaude", "automation", "security"],
    type: "system",
    confidence: 0.9
  }
];

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { question } = body;

    if (!question || typeof question !== 'string') {
      return NextResponse.json(
        { error: "Question is required and must be a string" },
        { status: 400 }
      );
    }

    if (question.trim().length === 0) {
      return NextResponse.json(
        { error: "Question cannot be empty" },
        { status: 400 }
      );
    }

    // Simple keyword-based search (replace with vector search in production)
    const results = await searchKnowledgeBase(question);

    if (results.length === 0) {
      return NextResponse.json({
        question,
        answer: "I don't have specific information about that topic in my knowledge base. You can try asking about Scout v7 data models, ETL processes, task framework, agents, or specific metrics like revenue, transactions, or basket counts.",
        citations: [],
        confidence: 0.3,
        search_results: 0
      });
    }

    // Get the best match
    const bestMatch = results[0];

    // Generate answer based on the best match and related content
    const answer = await generateAnswer(question, results);

    return NextResponse.json({
      question,
      answer: answer.text,
      citations: answer.citations,
      confidence: answer.confidence,
      search_results: results.length,
      related_topics: results.slice(1, 4).map(r => ({
        title: r.title,
        type: r.type,
        relevance: r.score
      }))
    });

  } catch (error) {
    console.error('Catalog Q&A error:', error);
    return NextResponse.json(
      { error: "Internal server error", message: error instanceof Error ? error.message : 'Unknown error' },
      { status: 500 }
    );
  }
}

async function searchKnowledgeBase(question: string): Promise<any[]> {
  const q = question.toLowerCase();
  const words = q.split(/\s+/).filter(w => w.length > 2);

  const results = KNOWLEDGE_BASE.map(item => {
    let score = 0;

    // Exact phrase matching in title (highest weight)
    if (item.title.toLowerCase().includes(q)) {
      score += 10;
    }

    // Exact phrase matching in content
    if (item.content.toLowerCase().includes(q)) {
      score += 5;
    }

    // Tag matching
    for (const tag of item.tags) {
      if (q.includes(tag.toLowerCase())) {
        score += 3;
      }
    }

    // Word matching in title
    for (const word of words) {
      if (item.title.toLowerCase().includes(word)) {
        score += 2;
      }
    }

    // Word matching in content
    for (const word of words) {
      if (item.content.toLowerCase().includes(word)) {
        score += 1;
      }
    }

    // Word matching in tags
    for (const word of words) {
      for (const tag of item.tags) {
        if (tag.toLowerCase().includes(word)) {
          score += 1;
        }
      }
    }

    return { ...item, score };
  }).filter(item => item.score > 0)
    .sort((a, b) => b.score - a.score);

  return results;
}

async function generateAnswer(question: string, results: any[]): Promise<{
  text: string;
  citations: string[];
  confidence: number;
}> {
  if (results.length === 0) {
    return {
      text: "I don't have information about that topic.",
      citations: [],
      confidence: 0.3
    };
  }

  const primary = results[0];
  const related = results.slice(1, 3);

  let answer = primary.content;

  // Add related information if highly relevant
  if (related.length > 0 && related[0].score > primary.score * 0.7) {
    answer += `\n\nRelated: ${related[0].content}`;
  }

  // Calculate confidence based on search score and item confidence
  const searchConfidence = Math.min(1.0, primary.score / 10);
  const overallConfidence = (searchConfidence + primary.confidence) / 2;

  const citations = [primary.title];
  if (related.length > 0) {
    citations.push(...related.slice(0, 2).map(r => r.title));
  }

  return {
    text: answer,
    citations,
    confidence: overallConfidence
  };
}

// Health check endpoint
export async function GET() {
  return NextResponse.json({
    service: "Catalog Q&A",
    version: "1.0.0",
    status: "healthy",
    knowledge_base_size: KNOWLEDGE_BASE.length,
    search_method: "keyword_based",
    timestamp: new Date().toISOString()
  });
}