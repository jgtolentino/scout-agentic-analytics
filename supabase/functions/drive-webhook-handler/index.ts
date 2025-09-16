// Google Drive Webhook Handler - Real-time Change Notifications
// Scout v7 Analytics Platform
// Purpose: Handle Google Drive push notifications for real-time file synchronization

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-goog-channel-id, x-goog-resource-id, x-goog-resource-uri, x-goog-resource-state, x-goog-message-number',
}

interface WebhookNotification {
  channelId: string
  resourceId: string
  resourceUri: string
  resourceState: 'sync' | 'add' | 'remove' | 'update' | 'trash' | 'untrash' | 'change'
  messageNumber: string
  eventTime?: string
}

interface ProcessingResponse {
  success: boolean
  webhookId: string
  resourceState: string
  filesProcessed: number
  triggerTime: number
  errors: string[]
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()
  const webhookId = crypto.randomUUID()

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Extract webhook headers
    const channelId = req.headers.get('x-goog-channel-id')
    const resourceId = req.headers.get('x-goog-resource-id')
    const resourceUri = req.headers.get('x-goog-resource-uri')
    const resourceState = req.headers.get('x-goog-resource-state') as WebhookNotification['resourceState']
    const messageNumber = req.headers.get('x-goog-message-number')
    const eventTime = req.headers.get('x-goog-event-time')

    if (!channelId || !resourceId || !resourceState) {
      throw new Error('Missing required webhook headers')
    }

    console.log(`Webhook received: ${resourceState} for resource ${resourceId}`)

    // Validate webhook signature (optional but recommended for production)
    await validateWebhookSignature(req)

    const notification: WebhookNotification = {
      channelId,
      resourceId,
      resourceUri: resourceUri || '',
      resourceState,
      messageNumber: messageNumber || '0',
      eventTime
    }

    // Log webhook event
    const { data: webhookLog, error: logError } = await supabase
      .from('drive_intelligence.webhook_events')
      .insert({
        webhook_id: webhookId,
        channel_id: channelId,
        resource_id: resourceId,
        resource_state: resourceState,
        message_number: parseInt(messageNumber || '0'),
        event_time: eventTime ? new Date(parseInt(eventTime)) : new Date(),
        received_at: new Date(),
        processing_status: 'received',
        headers: Object.fromEntries(req.headers.entries())
      })
      .select()
      .single()

    if (logError) {
      console.error('Failed to log webhook event:', logError)
    }

    // Skip sync events (initial channel setup)
    if (resourceState === 'sync') {
      console.log('Sync event received, skipping processing')
      return new Response(JSON.stringify({
        success: true,
        webhookId,
        resourceState,
        message: 'Sync event acknowledged',
        triggerTime: Date.now() - startTime
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Process the webhook notification
    const processingResult = await processWebhookNotification(supabase, notification)

    // Update webhook log with processing results
    if (webhookLog) {
      await supabase
        .from('drive_intelligence.webhook_events')
        .update({
          processing_status: processingResult.success ? 'completed' : 'failed',
          processed_at: new Date(),
          files_processed: processingResult.filesProcessed,
          error_details: processingResult.errors.length > 0 ? processingResult.errors.join('; ') : null,
          processing_duration_ms: Date.now() - startTime
        })
        .eq('webhook_id', webhookId)
    }

    const response: ProcessingResponse = {
      success: processingResult.success,
      webhookId,
      resourceState,
      filesProcessed: processingResult.filesProcessed,
      triggerTime: Date.now() - startTime,
      errors: processingResult.errors
    }

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Webhook processing error:', error)

    // Log the error
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    await supabase
      .from('drive_intelligence.webhook_events')
      .update({
        processing_status: 'failed',
        processed_at: new Date(),
        error_details: error.message,
        processing_duration_ms: Date.now() - startTime
      })
      .eq('webhook_id', webhookId)

    return new Response(JSON.stringify({
      success: false,
      webhookId,
      error: error.message,
      triggerTime: Date.now() - startTime
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})

// Validate webhook signature for security
async function validateWebhookSignature(req: Request): Promise<void> {
  const webhookSecret = Deno.env.get('DRIVE_WEBHOOK_SECRET')
  
  if (!webhookSecret) {
    console.warn('Webhook secret not configured, skipping signature validation')
    return
  }

  // In production, implement proper HMAC signature validation
  // This is a placeholder for the security check
  const signature = req.headers.get('x-goog-signature')
  if (!signature) {
    console.warn('No webhook signature provided')
  }

  // TODO: Implement actual signature validation
  // Example: verify HMAC-SHA256 signature against request body and secret
}

// Process webhook notification and trigger appropriate actions
async function processWebhookNotification(
  supabase: any,
  notification: WebhookNotification
): Promise<{ success: boolean; filesProcessed: number; errors: string[] }> {
  const errors: string[] = []
  let filesProcessed = 0

  try {
    // Check if we have an active webhook subscription for this channel
    const { data: subscription, error: subError } = await supabase
      .from('drive_intelligence.webhook_subscriptions')
      .select('*')
      .eq('channel_id', notification.channelId)
      .eq('active', true)
      .single()

    if (subError || !subscription) {
      throw new Error(`No active subscription found for channel ${notification.channelId}`)
    }

    console.log(`Processing ${notification.resourceState} event for folder ${subscription.folder_id}`)

    // Handle different resource states
    switch (notification.resourceState) {
      case 'add':
      case 'update':
        // Trigger incremental sync for the folder
        filesProcessed = await triggerIncrementalSync(subscription.folder_id, 'webhook_trigger')
        break

      case 'remove':
      case 'trash':
        // Handle file removal/trash
        await handleFileRemoval(supabase, notification.resourceId)
        filesProcessed = 1
        break

      case 'untrash':
        // Handle file restoration
        await handleFileRestoration(supabase, notification.resourceId)
        filesProcessed = 1
        break

      case 'change':
        // Generic change event - trigger incremental sync
        filesProcessed = await triggerIncrementalSync(subscription.folder_id, 'webhook_change')
        break

      default:
        console.log(`Unhandled resource state: ${notification.resourceState}`)
    }

    // Update subscription last activity
    await supabase
      .from('drive_intelligence.webhook_subscriptions')
      .update({
        last_notification_at: new Date(),
        total_notifications: subscription.total_notifications + 1
      })
      .eq('channel_id', notification.channelId)

    return { success: true, filesProcessed, errors }

  } catch (error) {
    console.error('Error processing webhook notification:', error)
    errors.push(error.message)
    return { success: false, filesProcessed, errors }
  }
}

// Trigger incremental sync via drive-mirror function
async function triggerIncrementalSync(folderId: string, trigger: string): Promise<number> {
  try {
    const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/drive-mirror`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        folderId,
        incremental: true,
        dryRun: false,
        maxFiles: 100,
        trigger
      })
    })

    if (!response.ok) {
      throw new Error(`Sync trigger failed: ${response.status} ${response.statusText}`)
    }

    const result = await response.json()
    console.log(`Incremental sync triggered for ${folderId}: ${result.filesProcessed} files`)
    
    return result.filesProcessed || 0

  } catch (error) {
    console.error(`Failed to trigger incremental sync for ${folderId}:`, error)
    throw error
  }
}

// Handle file removal/trash events
async function handleFileRemoval(supabase: any, resourceId: string): Promise<void> {
  try {
    // Mark file as deleted in our database
    const { error } = await supabase
      .from('drive_intelligence.bronze_files')
      .update({
        processing_status: 'deleted',
        updated_at: new Date().toISOString(),
        metadata: supabase.raw(`metadata || '{"deleted_at": "${new Date().toISOString()}", "deletion_reason": "drive_webhook"}'::jsonb`)
      })
      .eq('file_id', resourceId)

    if (error) {
      throw new Error(`Failed to mark file as deleted: ${error.message}`)
    }

    console.log(`File ${resourceId} marked as deleted`)

  } catch (error) {
    console.error(`Error handling file removal for ${resourceId}:`, error)
    throw error
  }
}

// Handle file restoration events
async function handleFileRestoration(supabase: any, resourceId: string): Promise<void> {
  try {
    // Check if file exists in our database
    const { data: existingFile, error: fileError } = await supabase
      .from('drive_intelligence.bronze_files')
      .select('*')
      .eq('file_id', resourceId)
      .single()

    if (fileError && fileError.code !== 'PGRST116') { // PGRST116 = not found
      throw new Error(`Database error checking file: ${fileError.message}`)
    }

    if (existingFile) {
      // File exists, update status
      await supabase
        .from('drive_intelligence.bronze_files')
        .update({
          processing_status: 'pending',
          updated_at: new Date().toISOString(),
          metadata: supabase.raw(`metadata || '{"restored_at": "${new Date().toISOString()}", "restoration_reason": "drive_webhook"}'::jsonb`)
        })
        .eq('file_id', resourceId)

      console.log(`File ${resourceId} marked for reprocessing`)
    } else {
      // File doesn't exist in our database, trigger sync to discover it
      console.log(`File ${resourceId} not found in database, sync needed`)
    }

  } catch (error) {
    console.error(`Error handling file restoration for ${resourceId}:`, error)
    throw error
  }
}

// Create webhook subscription table if it doesn't exist
async function createWebhookSubscriptionsTable(supabase: any): Promise<void> {
  const createTableSQL = `
    CREATE TABLE IF NOT EXISTS drive_intelligence.webhook_subscriptions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      channel_id TEXT NOT NULL UNIQUE,
      folder_id TEXT NOT NULL,
      webhook_url TEXT NOT NULL,
      expiration_time TIMESTAMPTZ NOT NULL,
      active BOOLEAN DEFAULT true,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      last_notification_at TIMESTAMPTZ,
      total_notifications INTEGER DEFAULT 0,
      metadata JSONB DEFAULT '{}'::jsonb
    );

    CREATE TABLE IF NOT EXISTS drive_intelligence.webhook_events (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      webhook_id TEXT NOT NULL,
      channel_id TEXT NOT NULL,
      resource_id TEXT NOT NULL,
      resource_state TEXT NOT NULL,
      message_number INTEGER DEFAULT 0,
      event_time TIMESTAMPTZ,
      received_at TIMESTAMPTZ DEFAULT NOW(),
      processed_at TIMESTAMPTZ,
      processing_status TEXT DEFAULT 'received' CHECK (processing_status IN ('received', 'processing', 'completed', 'failed')),
      files_processed INTEGER DEFAULT 0,
      error_details TEXT,
      processing_duration_ms INTEGER,
      headers JSONB DEFAULT '{}'::jsonb
    );

    CREATE INDEX IF NOT EXISTS idx_webhook_events_channel_id ON drive_intelligence.webhook_events(channel_id);
    CREATE INDEX IF NOT EXISTS idx_webhook_events_received_at ON drive_intelligence.webhook_events(received_at);
    CREATE INDEX IF NOT EXISTS idx_webhook_events_processing_status ON drive_intelligence.webhook_events(processing_status);
  `

  try {
    await supabase.rpc('exec_sql', { sql: createTableSQL })
    console.log('Webhook tables ensured')
  } catch (error) {
    console.error('Failed to create webhook tables:', error)
  }
}

// Helper function to register webhook with Google Drive
export async function registerWebhook(folderId: string, webhookUrl: string): Promise<string> {
  const accessToken = await getGoogleAccessToken()
  const channelId = `scout-drive-webhook-${Date.now()}`
  
  const response = await fetch('https://www.googleapis.com/drive/v3/files/watch', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      id: channelId,
      type: 'web_hook',
      address: webhookUrl,
      params: {
        ttl: '3600' // 1 hour expiration
      }
    })
  })

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}))
    throw new Error(`Failed to register webhook: ${response.status} ${errorData.error?.message || response.statusText}`)
  }

  const data = await response.json()
  console.log(`Webhook registered: ${channelId}`)
  
  return channelId
}

// Helper function to get Google access token (same as other functions)
async function getGoogleAccessToken(): Promise<string> {
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
}

export default serve