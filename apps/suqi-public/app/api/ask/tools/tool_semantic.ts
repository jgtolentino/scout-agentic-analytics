// Tool adapter for semantic query API
export async function runSemantic(params: any) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';

  // Validate required parameters
  if (!params.dimensions && !params.measures) {
    throw new Error("SEMANTIC_QUERY requires at least dimensions or measures");
  }

  // Set defaults for common parameters
  const payload = {
    dimensions: params.dimensions || [],
    measures: params.measures || ["revenue", "transactions"],
    filters: params.filters || [],
    rollup: params.rollup ?? true,
    limit: params.limit || 1000,
    orderBy: params.orderBy || [{ by: params.measures?.[0] || "revenue", dir: "desc" }],
    ...params
  };

  try {
    const res = await fetch(`${apiBase}/api/semantic/query`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(`SEMANTIC_QUERY failed ${res.status}: ${errorText}`);
    }

    const result = await res.json();

    // Add metadata for chat display
    return {
      ...result,
      type: "table",
      query_params: payload,
      row_count: result.data?.length || 0,
      has_rollup: payload.rollup && result.data?.some((row: any) => row.__grouping_id > 0),
      summary: generateSummary(result, payload)
    };
  } catch (error) {
    console.error('Semantic query error:', error);
    throw new Error(`Failed to execute semantic query: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

function generateSummary(result: any, params: any): string {
  const rowCount = result.data?.length || 0;
  const dimensions = params.dimensions?.join(', ') || 'none';
  const measures = params.measures?.join(', ') || 'none';

  if (rowCount === 0) {
    return `Query returned no results for dimensions: ${dimensions}, measures: ${measures}`;
  }

  const hasRollup = params.rollup && result.data?.some((row: any) => row.__grouping_id > 0);
  const rollupNote = hasRollup ? ' (includes rollup totals)' : '';

  return `Found ${rowCount} rows for ${dimensions} by ${measures}${rollupNote}`;
}