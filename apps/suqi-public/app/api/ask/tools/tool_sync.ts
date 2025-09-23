// Tool adapter for auto-sync agent
export async function runSync(params: any = {}) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';

  try {
    // Trigger the auto-sync agent
    const res = await fetch(`${apiBase}/api/agents/run`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify({
        agent_code: "AUTO_SYNC_FLAT",
        ctx: params
      })
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(`AUTO_SYNC_FLAT trigger failed ${res.status}: ${errorText}`);
    }

    const result = await res.json();

    // Poll for completion status if we have a run_id
    if (result.run_id) {
      let attempts = 0;
      const maxAttempts = 30; // 30 seconds max wait

      while (attempts < maxAttempts) {
        await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
        attempts++;

        try {
          const statusRes = await fetch(`${apiBase}/api/agents/status/${result.run_id}`, {
            headers: { "x-source": "ask-suqi" }
          });

          if (statusRes.ok) {
            const statusData = await statusRes.json();

            if (statusData.status === "SUCCESS" || statusData.status === "ERROR") {
              return {
                type: "sync_status",
                run_id: result.run_id,
                status: statusData.status,
                records_processed: statusData.records_out,
                message: statusData.message || "Sync operation completed",
                duration_seconds: attempts,
                summary: generateSyncSummary(statusData, attempts)
              };
            }
          }
        } catch (statusError) {
          console.warn('Could not fetch sync status:', statusError);
          break;
        }
      }
    }

    // Fallback response if we can't get detailed status
    return {
      type: "sync_status",
      run_id: result.run_id || "unknown",
      status: "INITIATED",
      message: "Auto-sync has been initiated",
      summary: "Flat export sync initiated. Check task logs for completion status."
    };

  } catch (error) {
    console.error('Auto-sync error:', error);
    throw new Error(`Failed to run auto-sync: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

// Alternative implementation for direct sync operation
export async function runSyncDirect(params: any = {}) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';

  try {
    // Call a direct sync endpoint if available
    const res = await fetch(`${apiBase}/api/scout/sync`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify(params)
    });

    if (!res.ok) {
      throw new Error(`Direct sync failed ${res.status}`);
    }

    const result = await res.json();

    return {
      type: "sync_status",
      status: "COMPLETED",
      records_processed: result.records_processed,
      tables_updated: result.tables_updated,
      export_files: result.export_files,
      processing_time_ms: result.processing_time_ms,
      summary: `✅ Sync completed successfully. Processed ${result.records_processed} records in ${result.processing_time_ms}ms.`
    };

  } catch (error) {
    console.error('Direct sync error:', error);
    throw error;
  }
}

// Export a one-time sync operation
export async function runExportOnce(params: any = {}) {
  const apiBase = process.env.API_BASE || 'http://localhost:3001';

  try {
    const res = await fetch(`${apiBase}/api/agents/run`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-source": "ask-suqi"
      },
      body: JSON.stringify({
        agent_code: "EXPORT_ONCE",
        ctx: params
      })
    });

    if (!res.ok) {
      throw new Error(`EXPORT_ONCE trigger failed ${res.status}`);
    }

    const result = await res.json();

    return {
      type: "export_status",
      run_id: result.run_id,
      status: "INITIATED",
      summary: "One-time export initiated. Data will be exported to the configured output location."
    };

  } catch (error) {
    console.error('Export once error:', error);
    throw error;
  }
}

function generateSyncSummary(statusData: any, durationSeconds: number): string {
  if (statusData.status === "SUCCESS") {
    const recordsText = statusData.records_out ?
      ` Processed ${statusData.records_out} records.` :
      '';
    return `✅ Auto-sync completed successfully in ${durationSeconds} seconds.${recordsText}`;
  } else if (statusData.status === "ERROR") {
    return `❌ Auto-sync failed after ${durationSeconds} seconds. Error: ${statusData.message || 'Unknown error'}`;
  } else {
    return `🔄 Auto-sync is ${statusData.status.toLowerCase()} after ${durationSeconds} seconds.`;
  }
}