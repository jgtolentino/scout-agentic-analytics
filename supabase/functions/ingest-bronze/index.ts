import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface StorageEvent {
  type: 'INSERT' | 'UPDATE'
  record: {
    bucket_id: string
    name: string
    id: string
    created_at: string
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  try {
    const event: StorageEvent = await req.json()
    
    // Only process files in scout-ingest bucket
    if (event.record.bucket_id !== 'scout-ingest') {
      return new Response(JSON.stringify({ message: 'Ignoring non-ingest bucket' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      })
    }

    console.log(`Processing file: ${event.record.name}`)

    // Download the file
    const { data: fileData, error: downloadError } = await supabase.storage
      .from('scout-ingest')
      .download(event.record.name)

    if (downloadError) throw downloadError

    // Parse file content based on type
    const fileName = event.record.name
    const fileText = await fileData.text()
    let records: any[] = []

    if (fileName.endsWith('.json')) {
      // Handle both single JSON and JSON lines
      if (fileText.trim().startsWith('[')) {
        records = JSON.parse(fileText)
      } else {
        // JSON lines format
        records = fileText.trim().split('\n').filter(Boolean).map(line => JSON.parse(line))
      }
    } else if (fileName.endsWith('.csv')) {
      // Simple CSV parsing (can be enhanced)
      const lines = fileText.trim().split('\n')
      const headers = lines[0].split(',').map(h => h.trim())
      records = lines.slice(1).map(line => {
        const values = line.split(',')
        const record: any = {}
        headers.forEach((header, index) => {
          record[header] = values[index]?.trim()
        })
        return record
      })
    }

    // Extract device ID from file path
    const pathParts = fileName.split('/')
    const deviceId = pathParts.find(part => part.includes('device-')) || 'unknown'

    // Insert records into bronze table
    const bronzeRecords = records.map(record => ({
      device_id: record.device_id || deviceId,
      captured_at: record.timestamp || record.captured_at || new Date().toISOString(),
      src_filename: fileName,
      payload: record
    }))

    const { error: insertError } = await supabase
      .from('bronze_edge_raw')
      .insert(bronzeRecords)

    if (insertError) throw insertError

    console.log(`Inserted ${bronzeRecords.length} records from ${fileName}`)

    // Move file to processed folder
    const processedPath = fileName.replace(/^/, 'processed/')
    const { error: moveError } = await supabase.storage
      .from('scout-ingest')
      .move(fileName, processedPath)

    if (moveError) {
      console.warn('Could not move file to processed folder:', moveError)
    }

    // Trigger downstream processing
    const { error: rpcError } = await supabase.rpc('scout_platinum.compute_store_features')
    if (rpcError) {
      console.warn('Could not compute features:', rpcError)
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Processed ${bronzeRecords.length} records from ${fileName}` 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Error processing file:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})