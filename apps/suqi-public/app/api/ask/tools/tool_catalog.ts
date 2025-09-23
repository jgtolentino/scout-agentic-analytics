// Tool adapter for catalog Q&A (RAG over data dictionary/metrics)
export async function runCatalogQA(question: string) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';

  try {
    // Try to use a dedicated catalog Q&A endpoint
    const res = await fetch(`${apiBase}/api/catalog/qa`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify({ question })
    });

    if (res.ok) {
      const result = await res.json();
      return {
        type: "catalog_answer",
        question,
        answer: result.answer,
        citations: result.citations || [],
        confidence: result.confidence || 0.8,
        summary: `Found information about: ${question}`
      };
    }

    // Fallback to built-in knowledge base
    return await runBuiltinCatalogQA(question);

  } catch (error) {
    console.warn('Catalog Q&A service unavailable, using built-in knowledge:', error);
    return await runBuiltinCatalogQA(question);
  }
}

// Built-in knowledge base for common Scout v7 questions
async function runBuiltinCatalogQA(question: string): Promise<any> {
  const q = question.toLowerCase();

  // Data dictionary knowledge
  if (q.includes('canonical_tx_id') || q.includes('canonical transaction id')) {
    return {
      type: "catalog_answer",
      question,
      answer: "canonical_tx_id is the normalized transaction identifier used for joining data across tables. It's derived from the original transaction ID by converting to lowercase and removing hyphens. The normalized version (canonical_tx_id_norm) is stored as a persisted computed column for efficient joins.",
      citations: ["gold.vw_FlatExport", "silver.Transactions", "system design docs"],
      confidence: 0.95,
      summary: "Explained canonical transaction ID normalization"
    };
  }

  if (q.includes('si-only') || q.includes('si only') || q.includes('timestamp')) {
    return {
      type: "catalog_answer",
      question,
      answer: "SI-only timestamp policy means that all production views and exports use timestamps exclusively from SalesInteractions table, never from PayloadTransactions. This ensures data consistency and prevents timestamp contamination from unreliable payload sources.",
      citations: ["gold.vw_FlatExport", "ETL documentation"],
      confidence: 0.9,
      summary: "Explained SI-only timestamp policy"
    };
  }

  if (q.includes('change tracking') || q.includes('delta')) {
    return {
      type: "catalog_answer",
      question,
      answer: "Change Tracking is enabled on key tables to efficiently detect and export only changed data. The auto-sync system uses CHANGE_TRACKING_CURRENT_VERSION() to identify deltas since the last export, making the ETL process highly efficient for large datasets.",
      citations: ["025_enhanced_etl_column_mapping.sql", "auto_sync_tracked.py"],
      confidence: 0.9,
      summary: "Explained Change Tracking delta detection"
    };
  }

  if (q.includes('parity') || q.includes('flat vs crosstab')) {
    return {
      type: "catalog_answer",
      question,
      answer: "Parity checking compares record counts between flat export (gold.vw_FlatExport) and crosstab views to ensure data consistency. The system runs automated parity checks and alerts if differences exceed 1% threshold, indicating potential data quality issues.",
      citations: ["dbo.sp_parity_flat_vs_crosstab", "system.v_task_status"],
      confidence: 0.9,
      summary: "Explained parity checking between flat and crosstab views"
    };
  }

  if (q.includes('task framework') || q.includes('task tracking')) {
    return {
      type: "catalog_answer",
      question,
      answer: "The task framework provides comprehensive tracking of all ETL operations through system tables. It includes task registration, run tracking, heartbeats, and metrics collection. Key procedures include sp_task_register, sp_task_run_begin, sp_task_heartbeat, and sp_task_run_end.",
      citations: ["026_task_framework.sql", "system.v_task_status", "system.v_task_run_history"],
      confidence: 0.95,
      summary: "Explained task framework for ETL operation tracking"
    };
  }

  if (q.includes('medallion') || q.includes('bronze silver gold')) {
    return {
      type: "catalog_answer",
      question,
      answer: "Scout v7 follows medallion architecture: Bronze (raw ingested data), Silver (cleaned and normalized), Gold (business-ready aggregated views), and Platinum (analytics-optimized materialized views). This ensures data quality progression and clear separation of concerns.",
      citations: ["Architecture documentation", "ETL pipeline design"],
      confidence: 0.9,
      summary: "Explained medallion architecture data layers"
    };
  }

  // Metrics knowledge
  if (q.includes('revenue') || q.includes('sales amount')) {
    return {
      type: "catalog_answer",
      question,
      answer: "Revenue is calculated from the 'amount' field in transactions, representing the total sales value. It's aggregated using SUM() in semantic queries and can be broken down by various dimensions like category, brand, store, time period, etc.",
      citations: ["gold.vw_FlatExport", "semantic query API"],
      confidence: 0.9,
      summary: "Explained revenue calculation and aggregation"
    };
  }

  if (q.includes('basket') || q.includes('basket_count')) {
    return {
      type: "catalog_answer",
      question,
      answer: "Basket count represents the number of items in a single transaction. Average basket size is calculated using AVG(basket_count) and can be used to analyze customer purchase behavior and product affinity.",
      citations: ["silver.Transactions", "semantic query API"],
      confidence: 0.85,
      summary: "Explained basket count metric"
    };
  }

  // Agent knowledge
  if (q.includes('agent') || q.includes('superclaude')) {
    return {
      type: "catalog_answer",
      question,
      answer: "Scout v7 includes 16 registered agents in the SuperClaude framework, including auto-sync, parity check, semantic query, geo export, and various analysis agents. All agents are enabled by default and follow the Bruno secure executor model with no credentials exposed to LLMs.",
      citations: ["superclaude_agents.yaml", "agent registry documentation"],
      confidence: 0.9,
      summary: "Explained Scout v7 agent system"
    };
  }

  // Default response for unknown questions
  return {
    type: "catalog_answer",
    question,
    answer: "I don't have specific information about that topic in my knowledge base. You can try asking about Scout v7 data models, ETL processes, task framework, agents, or specific metrics like revenue, transactions, or basket counts.",
    citations: [],
    confidence: 0.3,
    summary: "Unable to find specific information"
  };
}