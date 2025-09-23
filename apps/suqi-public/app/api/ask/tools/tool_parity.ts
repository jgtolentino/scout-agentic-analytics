// Tool adapter for parity check agent
export async function runParity(params: { daysBack?: number } = {}) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';
  const daysBack = params.daysBack || 30;

  try {
    // Trigger the parity check agent
    const res = await fetch(`${apiBase}/api/agents/run`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify({
        agent_code: "PARITY_CHECK",
        ctx: { days: daysBack }
      })
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(`PARITY_CHECK trigger failed ${res.status}: ${errorText}`);
    }

    const result = await res.json();

    // For SQL procedure agents, we might need to fetch the results
    // since the stored procedure runs synchronously
    if (result.run_id) {
      // Wait a moment for the procedure to complete
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Try to fetch the run results
      try {
        const statusRes = await fetch(`${apiBase}/api/agents/status/${result.run_id}`, {
          headers: { "x-source": "ask-suqi" }
        });

        if (statusRes.ok) {
          const statusData = await statusRes.json();
          return {
            type: "parity_report",
            run_id: result.run_id,
            status: statusData.status || "COMPLETED",
            days_checked: daysBack,
            message: statusData.message || "Parity check completed",
            results: statusData.results,
            summary: `Parity check completed for last ${daysBack} days`
          };
        }
      } catch (statusError) {
        console.warn('Could not fetch parity check status:', statusError);
      }
    }

    // Fallback response
    return {
      type: "parity_report",
      run_id: result.run_id || "unknown",
      status: "INITIATED",
      days_checked: daysBack,
      message: "Parity check has been initiated",
      summary: `Initiated parity check for last ${daysBack} days. Check run status for results.`
    };

  } catch (error) {
    console.error('Parity check error:', error);
    throw new Error(`Failed to run parity check: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

// Alternative implementation for direct SQL execution if agent framework not available
export async function runParityDirect(params: { daysBack?: number } = {}) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';
  const daysBack = params.daysBack || 30;

  try {
    // Call a direct parity endpoint if available
    const res = await fetch(`${apiBase}/api/scout/parity`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify({ days_back: daysBack })
    });

    if (!res.ok) {
      throw new Error(`Direct parity check failed ${res.status}`);
    }

    const result = await res.json();

    return {
      type: "parity_report",
      status: "COMPLETED",
      days_checked: daysBack,
      flat_count: result.flat_count,
      crosstab_count: result.crosstab_count,
      difference: result.difference,
      difference_percent: result.difference_percent,
      is_within_threshold: result.is_within_threshold,
      summary: generateParitySummary(result, daysBack)
    };

  } catch (error) {
    console.error('Direct parity check error:', error);
    throw error;
  }
}

function generateParitySummary(result: any, daysBack: number): string {
  if (result.is_within_threshold) {
    return `✅ Parity check passed for last ${daysBack} days. Flat (${result.flat_count}) and crosstab (${result.crosstab_count}) counts match within acceptable threshold.`;
  } else {
    const diffPercent = (result.difference_percent * 100).toFixed(2);
    return `⚠️ Parity check found ${diffPercent}% difference for last ${daysBack} days. Flat: ${result.flat_count}, Crosstab: ${result.crosstab_count}, Difference: ${result.difference}`;
  }
}