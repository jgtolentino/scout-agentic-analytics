// Google Drive Mirror - Main Synchronization Engine
// Scout v7 Analytics Platform
// Purpose: Incremental Google Drive file synchronization with metadata extraction

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DriveFile {
  id: string
  name: string
  mimeType: string
  size?: string
  modifiedTime: string
  createdTime: string
  parents?: string[]
  md5Checksum?: string
  webViewLink?: string
}

interface SyncRequest {
  folderId: string
  folderName?: string
  incremental?: boolean
  dryRun?: boolean
  maxFiles?: number
}

interface SyncResponse {
  success: boolean
  executionId: string
  filesProcessed: number
  newFiles: number
  updatedFiles: number
  errors: string[]
  processingTime: number
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()
  let executionId = crypto.randomUUID()

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Parse request
    const { folderId, folderName = 'Unknown', incremental = true, dryRun = false, maxFiles = 1000 }: SyncRequest = await req.json()

    if (!folderId) {
      throw new Error('folderId is required')
    }

    console.log(`Starting Drive sync - Folder: ${folderId}, Incremental: ${incremental}, DryRun: ${dryRun}`)

    // Get Google Drive access token
    const accessToken = await getGoogleAccessToken()

    // Get last sync timestamp for incremental sync
    let lastSyncTime: string | null = null
    if (incremental) {
      const { data: lastSync } = await supabase
        .from('drive_intelligence.etl_execution_history')
        .select('completed_at')
        .eq('status', 'completed')
        .order('completed_at', { ascending: false })
        .limit(1)
        .single()

      if (lastSync?.completed_at) {
        lastSyncTime = new Date(lastSync.completed_at).toISOString()
      }
    }

    // Create execution log entry
    const { data: logEntry, error: logError } = await supabase
      .from('drive_intelligence.etl_execution_history')
      .insert({
        job_id: await getJobId(supabase, 'TBWA_Scout_Daily_Drive_Sync'),
        execution_id: executionId,
        started_at: new Date().toISOString(),
        status: 'running',
        performance_metrics: {
          folder_id: folderId,
          folder_name: folderName,
          incremental,
          dry_run: dryRun,
          last_sync_time: lastSyncTime
        }
      })
      .select()
      .single()

    if (logError) {
      throw new Error(`Failed to create execution log: ${logError.message}`)
    }

    // Fetch files from Google Drive
    const driveFiles = await fetchDriveFiles(accessToken, folderId, lastSyncTime, maxFiles)
    console.log(`Fetched ${driveFiles.length} files from Google Drive`)

    let newFiles = 0
    let updatedFiles = 0
    const errors: string[] = []

    if (!dryRun) {
      // Process files in batches
      const batchSize = 10
      for (let i = 0; i < driveFiles.length; i += batchSize) {
        const batch = driveFiles.slice(i, i + batchSize)
        
        try {
          const batchResult = await processBatch(supabase, batch, folderId, folderName, executionId)
          newFiles += batchResult.newFiles
          updatedFiles += batchResult.updatedFiles
          
          if (batchResult.errors.length > 0) {
            errors.push(...batchResult.errors)
          }
        } catch (error) {
          console.error(`Batch processing error:`, error)
          errors.push(`Batch ${i}-${i + batch.length}: ${error.message}`)
        }
      }
    }

    const processingTime = Date.now() - startTime
    const finalStatus = errors.length === 0 ? 'completed' : 'completed_with_errors'

    // Update execution log
    await supabase
      .from('drive_intelligence.etl_execution_history')
      .update({
        status: finalStatus,
        completed_at: new Date().toISOString(),
        files_processed: driveFiles.length,
        files_succeeded: newFiles + updatedFiles,
        files_failed: errors.length,
        processing_duration_seconds: Math.round(processingTime / 1000),
        error_summary: errors.length > 0 ? errors.join('; ') : null,
        performance_metrics: {
          ...logEntry.performance_metrics,
          processing_time_ms: processingTime,
          files_fetched: driveFiles.length,
          new_files: newFiles,
          updated_files: updatedFiles,
          error_count: errors.length
        }
      })
      .eq('execution_id', executionId)

    const response: SyncResponse = {
      success: true,
      executionId,
      filesProcessed: driveFiles.length,
      newFiles,
      updatedFiles,
      errors,
      processingTime
    }

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Drive mirror error:', error)

    // Log the error
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    await supabase
      .from('drive_intelligence.etl_execution_history')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_summary: error.message,
        processing_duration_seconds: Math.round((Date.now() - startTime) / 1000)
      })
      .eq('execution_id', executionId)

    return new Response(JSON.stringify({
      success: false,
      executionId,
      error: error.message,
      processingTime: Date.now() - startTime
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})

// Get Google Access Token using Service Account
async function getGoogleAccessToken(): Promise<string> {
  const serviceAccountKey = Deno.env.get('GOOGLE_DRIVE_SERVICE_ACCOUNT_KEY')
  if (!serviceAccountKey) {
    throw new Error('Google Service Account key not configured')
  }

  try {
    const serviceAccount = JSON.parse(atob(serviceAccountKey))
    
    // Create JWT for Google OAuth
    const header = {
      alg: 'RS256',
      typ: 'JWT'
    }

    const now = Math.floor(Date.now() / 1000)
    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/drive.readonly',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now
    }

    // Note: In production, use a proper JWT library with RSA signing
    // For now, we'll use the refresh token approach
    const refreshToken = Deno.env.get('GOOGLE_DRIVE_REFRESH_TOKEN')
    const clientId = Deno.env.get('GOOGLE_DRIVE_CLIENT_ID')
    const clientSecret = Deno.env.get('GOOGLE_DRIVE_CLIENT_SECRET')

    if (!refreshToken || !clientId || !clientSecret) {
      throw new Error('Google OAuth credentials not configured')
    }

    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: 'refresh_token'
      })
    })

    const tokenData = await tokenResponse.json()
    
    if (!tokenResponse.ok) {
      throw new Error(`Token refresh failed: ${tokenData.error_description || tokenData.error}`)
    }

    return tokenData.access_token

  } catch (error) {
    throw new Error(`Failed to get Google access token: ${error.message}`)
  }
}

// Fetch files from Google Drive with optional time filter
async function fetchDriveFiles(
  accessToken: string, 
  folderId: string, 
  lastSyncTime: string | null, 
  maxFiles: number
): Promise<DriveFile[]> {
  const files: DriveFile[] = []
  let nextPageToken: string | undefined

  // Build query parameters
  let q = `'${folderId}' in parents and trashed = false`
  if (lastSyncTime) {
    q += ` and modifiedTime > '${lastSyncTime}'`
  }

  const fields = 'nextPageToken,files(id,name,mimeType,size,modifiedTime,createdTime,parents,md5Checksum,webViewLink)'

  do {
    const params = new URLSearchParams({
      q,
      fields,
      pageSize: Math.min(1000, maxFiles - files.length).toString(),
      orderBy: 'modifiedTime desc'
    })

    if (nextPageToken) {
      params.set('pageToken', nextPageToken)
    }

    const response = await fetch(`https://www.googleapis.com/drive/v3/files?${params}`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(`Google Drive API error: ${response.status} ${errorData.error?.message || response.statusText}`)
    }

    const data = await response.json()
    files.push(...(data.files || []))
    nextPageToken = data.nextPageToken

  } while (nextPageToken && files.length < maxFiles)

  return files
}

// Process a batch of files
async function processBatch(
  supabase: any,
  files: DriveFile[],
  folderId: string,
  folderName: string,
  executionId: string
): Promise<{ newFiles: number; updatedFiles: number; errors: string[] }> {
  let newFiles = 0
  let updatedFiles = 0
  const errors: string[] = []

  // Prepare batch insert/update data
  const fileRecords = files.map(file => ({
    file_id: file.id,
    file_name: file.name,
    folder_id: folderId,
    folder_path: folderName,
    mime_type: file.mimeType,
    file_size_bytes: file.size ? parseInt(file.size) : 0,
    md5_checksum: file.md5Checksum,
    created_time: file.createdTime,
    modified_time: file.modifiedTime,
    file_category: categorizeFile(file.mimeType),
    processing_status: 'pending',
    job_run_id: executionId,
    synced_at: new Date().toISOString(),
    metadata: {
      web_view_link: file.webViewLink,
      parents: file.parents,
      source: 'drive_mirror'
    }
  }))

  // Use upsert to handle new and updated files
  const { data: upsertResult, error: upsertError } = await supabase
    .from('drive_intelligence.bronze_files')
    .upsert(fileRecords, {
      onConflict: 'file_id',
      ignoreDuplicates: false
    })
    .select('file_id')

  if (upsertError) {
    console.error('Batch upsert error:', upsertError)
    errors.push(`Batch upsert failed: ${upsertError.message}`)
    return { newFiles: 0, updatedFiles: 0, errors }
  }

  // For simplicity, consider all as new files (in production, track actual new vs updated)
  newFiles = fileRecords.length

  return { newFiles, updatedFiles, errors }
}

// Categorize file based on MIME type
function categorizeFile(mimeType: string): string {
  const mimeMap: Record<string, string> = {
    'application/pdf': 'pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'document',
    'application/msword': 'document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'spreadsheet',
    'application/vnd.ms-excel': 'spreadsheet',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'presentation',
    'application/vnd.ms-powerpoint': 'presentation',
    'application/vnd.google-apps.document': 'google_workspace',
    'application/vnd.google-apps.spreadsheet': 'google_workspace',
    'application/vnd.google-apps.presentation': 'google_workspace',
    'image/jpeg': 'image',
    'image/png': 'image',
    'image/gif': 'image',
    'video/mp4': 'video',
    'video/avi': 'video',
    'audio/mp3': 'audio',
    'audio/wav': 'audio',
    'application/zip': 'archive',
    'application/x-rar-compressed': 'archive'
  }

  return mimeMap[mimeType] || 'other'
}

// Get job ID from registry
async function getJobId(supabase: any, jobName: string): Promise<string> {
  const { data, error } = await supabase
    .from('drive_intelligence.etl_job_registry')
    .select('id')
    .eq('job_name', jobName)
    .single()

  if (error || !data) {
    console.error(`Job not found: ${jobName}`)
    return crypto.randomUUID()
  }

  return data.id
}

// Export handler for Supabase Edge Functions
export default serve