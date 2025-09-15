// Unified Ingestion Framework - Consolidates 8 ingest functions
// Supports: azure, bronze, google-json, stream, zip, isko, scout-edge, scout
// Strategy pattern for different ingestion types with unified error handling

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

interface IngestRequest {
  strategy: 'azure' | 'bronze' | 'google-json' | 'stream' | 'zip' | 'isko' | 'scout-edge' | 'scout'
  data?: any
  file_url?: string
  source_path?: string
  config?: {
    batch_size?: number
    timeout_ms?: number
    retry_attempts?: number
    validate_schema?: boolean
    auto_transform?: boolean
  }
  metadata?: {
    source: string
    timestamp: string
    user_id?: string
    trace_id?: string
  }
}

interface IngestResult {
  success: boolean
  strategy: string
  records_processed: number
  records_inserted: number
  errors: string[]
  processing_time_ms: number
  metadata?: any
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// Ingestion strategies
abstract class IngestStrategy {
  abstract process(request: IngestRequest): Promise<IngestResult>
  
  protected async logIngest(request: IngestRequest, result: IngestResult) {
    try {
      await supabase.from('ingestion_log').insert({
        strategy: request.strategy,
        source: request.metadata?.source || 'unknown',
        records_processed: result.records_processed,
        records_inserted: result.records_inserted,
        success: result.success,
        errors: result.errors,
        processing_time_ms: result.processing_time_ms,
        metadata: {
          ...request.metadata,
          config: request.config
        }
      });
    } catch (error) {
      console.error('Failed to log ingestion:', error);
    }
  }
}

class AzureIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Connect to Azure SQL and fetch data
      const { data: azureData, error } = await supabase.rpc('fetch_azure_sql_data', {
        table_name: request.data?.table_name || 'interactions',
        batch_size: request.config?.batch_size || 1000
      });

      if (error) {
        errors.push(`Azure fetch error: ${error.message}`);
      } else if (azureData) {
        recordsProcessed = azureData.length;
        
        // Transform and insert data
        const transformedData = azureData.map((row: any) => ({
          ...row,
          source: 'azure-sql',
          ingested_at: new Date().toISOString()
        }));

        const { data: insertResult, error: insertError } = await supabase
          .from('bronze_interactions')
          .insert(transformedData);

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = transformedData.length;
        }
      }
    } catch (error) {
      errors.push(`Azure strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'azure',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class BronzeIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Load from storage to bronze layer
      const { data: storageData, error } = await supabase.storage
        .from('bronze')
        .download(request.source_path!);

      if (error) {
        errors.push(`Storage error: ${error.message}`);
      } else {
        const textData = await storageData.text();
        const rows = textData.split('\n').filter(row => row.trim());
        recordsProcessed = rows.length;

        // Process each row
        const processedRows = [];
        for (const row of rows) {
          try {
            const parsedRow = JSON.parse(row);
            processedRows.push({
              ...parsedRow,
              ingested_at: new Date().toISOString(),
              source: 'bronze-storage'
            });
          } catch (parseError) {
            errors.push(`Parse error for row: ${parseError.message}`);
          }
        }

        if (processedRows.length > 0) {
          const { error: insertError } = await supabase
            .from('bronze_raw')
            .insert(processedRows);

          if (insertError) {
            errors.push(`Insert error: ${insertError.message}`);
          } else {
            recordsInserted = processedRows.length;
          }
        }
      }
    } catch (error) {
      errors.push(`Bronze strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'bronze',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class GoogleJsonIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Process Google JSON format
      const jsonData = request.data;
      if (Array.isArray(jsonData)) {
        recordsProcessed = jsonData.length;
        
        const transformedData = jsonData.map((item: any) => ({
          raw_data: item,
          source: 'google-json',
          ingested_at: new Date().toISOString(),
          metadata: request.metadata
        }));

        const { error: insertError } = await supabase
          .from('bronze_google_data')
          .insert(transformedData);

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = transformedData.length;
        }
      } else {
        errors.push('Invalid JSON data format - expected array');
      }
    } catch (error) {
      errors.push(`Google JSON strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'google-json',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class StreamIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Process streaming data
      const streamData = request.data;
      if (streamData && streamData.events) {
        recordsProcessed = streamData.events.length;
        
        const transformedEvents = streamData.events.map((event: any) => ({
          event_type: event.type,
          event_data: event.data,
          timestamp: event.timestamp || new Date().toISOString(),
          source: 'stream',
          ingested_at: new Date().toISOString()
        }));

        const { error: insertError } = await supabase
          .from('bronze_stream_events')
          .insert(transformedEvents);

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = transformedEvents.length;
        }
      } else {
        errors.push('Invalid stream data format - expected events array');
      }
    } catch (error) {
      errors.push(`Stream strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'stream',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class ZipIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Process ZIP file upload
      if (request.file_url) {
        const response = await fetch(request.file_url);
        const zipBuffer = await response.arrayBuffer();
        
        // Extract and process ZIP contents
        // Note: In a real implementation, you'd use a ZIP library
        errors.push('ZIP processing not fully implemented - placeholder');
        
        // Placeholder processing
        recordsProcessed = 1;
        
        const { error: insertError } = await supabase
          .from('bronze_zip_uploads')
          .insert({
            file_url: request.file_url,
            file_size: zipBuffer.byteLength,
            status: 'processed',
            ingested_at: new Date().toISOString()
          });

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = 1;
        }
      } else {
        errors.push('No file URL provided for ZIP ingestion');
      }
    } catch (error) {
      errors.push(`ZIP strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'zip',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class IskoIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Process Isko-specific data format
      const iskoData = request.data;
      if (iskoData) {
        recordsProcessed = Array.isArray(iskoData) ? iskoData.length : 1;
        
        const transformedData = {
          raw_data: iskoData,
          source: 'isko',
          ingested_at: new Date().toISOString(),
          metadata: request.metadata
        };

        const { error: insertError } = await supabase
          .from('bronze_isko_data')
          .insert(transformedData);

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = 1;
        }
      } else {
        errors.push('No Isko data provided');
      }
    } catch (error) {
      errors.push(`Isko strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'isko',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class ScoutEdgeIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Process Scout Edge data
      const scoutData = request.data;
      if (scoutData && scoutData.transactions) {
        recordsProcessed = scoutData.transactions.length;
        
        const transformedTransactions = scoutData.transactions.map((tx: any) => ({
          transaction_id: tx.id,
          device_id: tx.device_id,
          timestamp: tx.timestamp,
          data: tx,
          source: 'scout-edge',
          ingested_at: new Date().toISOString()
        }));

        const { error: insertError } = await supabase
          .from('scout_transactions')
          .insert(transformedTransactions);

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = transformedTransactions.length;
        }
      } else {
        errors.push('Invalid Scout Edge data format');
      }
    } catch (error) {
      errors.push(`Scout Edge strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'scout-edge',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

class ScoutIngestStrategy extends IngestStrategy {
  async process(request: IngestRequest): Promise<IngestResult> {
    const startTime = Date.now();
    const errors: string[] = [];
    let recordsProcessed = 0;
    let recordsInserted = 0;

    try {
      // Process regular Scout data
      const scoutData = request.data;
      if (scoutData) {
        recordsProcessed = Array.isArray(scoutData) ? scoutData.length : 1;
        
        const transformedData = {
          raw_data: scoutData,
          source: 'scout',
          ingested_at: new Date().toISOString(),
          metadata: request.metadata
        };

        const { error: insertError } = await supabase
          .from('scout_raw_data')
          .insert(transformedData);

        if (insertError) {
          errors.push(`Insert error: ${insertError.message}`);
        } else {
          recordsInserted = 1;
        }
      } else {
        errors.push('No Scout data provided');
      }
    } catch (error) {
      errors.push(`Scout strategy error: ${error.message}`);
    }

    const result: IngestResult = {
      success: errors.length === 0,
      strategy: 'scout',
      records_processed: recordsProcessed,
      records_inserted: recordsInserted,
      errors,
      processing_time_ms: Date.now() - startTime
    };

    await this.logIngest(request, result);
    return result;
  }
}

// Strategy factory
class IngestStrategyFactory {
  static create(strategy: string): IngestStrategy {
    switch (strategy) {
      case 'azure':
        return new AzureIngestStrategy();
      case 'bronze':
        return new BronzeIngestStrategy();
      case 'google-json':
        return new GoogleJsonIngestStrategy();
      case 'stream':
        return new StreamIngestStrategy();
      case 'zip':
        return new ZipIngestStrategy();
      case 'isko':
        return new IskoIngestStrategy();
      case 'scout-edge':
        return new ScoutEdgeIngestStrategy();
      case 'scout':
        return new ScoutIngestStrategy();
      default:
        throw new Error(`Unknown ingestion strategy: ${strategy}`);
    }
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { 
      status: 405, 
      headers: corsHeaders 
    });
  }

  try {
    const request: IngestRequest = await req.json();
    
    if (!request.strategy) {
      return new Response(JSON.stringify({ 
        error: 'strategy is required' 
      }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    console.log(`Processing ingestion with strategy: ${request.strategy}`);

    // Create and execute strategy
    const strategy = IngestStrategyFactory.create(request.strategy);
    const result = await strategy.process(request);

    console.log(`Ingestion completed: ${result.records_inserted}/${result.records_processed} records`);

    return new Response(JSON.stringify({
      success: result.success,
      result: result
    }), {
      status: result.success ? 200 : 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Unified ingestion error:', error);
    
    return new Response(JSON.stringify({ 
      success: false,
      error: 'Ingestion failed',
      details: error instanceof Error ? error.message : String(error)
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});

// Deploy with:
// supabase functions deploy ingest-unified