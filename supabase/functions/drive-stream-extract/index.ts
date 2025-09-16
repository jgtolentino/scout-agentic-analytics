// Google Drive Stream Extract - Content Processing Pipeline
// Scout v7 Analytics Platform
// Purpose: Extract and process content from Google Drive files

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ExtractRequest {
  fileId: string
  priority?: 'low' | 'medium' | 'high' | 'critical'
  extractionOptions?: {
    includeText?: boolean
    includeImages?: boolean
    detectPII?: boolean
    performOCR?: boolean
    maxContentLength?: number
  }
}

interface ExtractResponse {
  success: boolean
  fileId: string
  contentExtracted: boolean
  textLength: number
  piiDetected: boolean
  processingTime: number
  errors: string[]
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const startTime = Date.now()

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Parse request
    const { 
      fileId, 
      priority = 'medium',
      extractionOptions = {}
    }: ExtractRequest = await req.json()

    if (!fileId) {
      throw new Error('fileId is required')
    }

    const {
      includeText = true,
      includeImages = false,
      detectPII = true,
      performOCR = false,
      maxContentLength = 1000000 // 1MB text limit
    } = extractionOptions

    console.log(`Processing file extraction: ${fileId}`)

    // Get file metadata from database
    const { data: fileRecord, error: fileError } = await supabase
      .from('drive_intelligence.bronze_files')
      .select('*')
      .eq('file_id', fileId)
      .single()

    if (fileError || !fileRecord) {
      throw new Error(`File not found in database: ${fileId}`)
    }

    // Update processing status
    await supabase
      .from('drive_intelligence.bronze_files')
      .update({
        processing_status: 'processing',
        processed_at: new Date().toISOString()
      })
      .eq('file_id', fileId)

    // Get Google Drive access token
    const accessToken = await getGoogleAccessToken()

    // Download file content
    const fileContent = await downloadFileContent(accessToken, fileId, fileRecord.mime_type)
    
    // Extract text content based on file type
    let extractedText = ''
    let contentSummary = ''
    let keyEntities: any[] = []
    let piiDetected = false
    let piiTypes: string[] = []

    if (includeText) {
      extractedText = await extractTextContent(fileContent, fileRecord.mime_type, performOCR)
      
      if (extractedText.length > maxContentLength) {
        extractedText = extractedText.substring(0, maxContentLength) + '... [truncated]'
      }

      // Generate content summary
      if (extractedText.length > 500) {
        contentSummary = await generateContentSummary(extractedText)
      }

      // Extract key entities
      keyEntities = await extractKeyEntities(extractedText)
    }

    // Detect PII if enabled
    if (detectPII && extractedText) {
      const piiResults = await detectPIIPatterns(supabase, extractedText)
      piiDetected = piiResults.detected
      piiTypes = piiResults.types
    }

    // Calculate quality score
    const qualityScore = calculateQualityScore(fileRecord, extractedText, keyEntities)

    // Update file record with extracted content
    const { error: updateError } = await supabase
      .from('drive_intelligence.bronze_files')
      .update({
        extracted_text: extractedText,
        content_summary: contentSummary,
        key_entities: keyEntities,
        contains_pii: piiDetected,
        pii_types: piiTypes,
        quality_score: qualityScore,
        processing_status: 'completed',
        processed_at: new Date().toISOString()
      })
      .eq('file_id', fileId)

    if (updateError) {
      throw new Error(`Failed to update file record: ${updateError.message}`)
    }

    // Trigger intelligence processing if content is substantial
    if (extractedText.length > 1000) {
      await triggerIntelligenceProcessing(fileId, priority)
    }

    const processingTime = Date.now() - startTime

    const response: ExtractResponse = {
      success: true,
      fileId,
      contentExtracted: extractedText.length > 0,
      textLength: extractedText.length,
      piiDetected,
      processingTime,
      errors: []
    }

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Content extraction error:', error)

    // Update file status to failed
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    await supabase
      .from('drive_intelligence.bronze_files')
      .update({
        processing_status: 'failed',
        error_details: error.message,
        processed_at: new Date().toISOString()
      })
      .eq('file_id', req.json().then(data => data.fileId).catch(() => ''))

    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      processingTime: Date.now() - startTime
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})

// Get Google Access Token (same as drive-mirror)
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

// Download file content from Google Drive
async function downloadFileContent(accessToken: string, fileId: string, mimeType: string): Promise<Uint8Array> {
  let downloadUrl = `https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`

  // For Google Workspace files, export to appropriate format
  if (mimeType.startsWith('application/vnd.google-apps.')) {
    const exportMimeType = getExportMimeType(mimeType)
    downloadUrl = `https://www.googleapis.com/drive/v3/files/${fileId}/export?mimeType=${encodeURIComponent(exportMimeType)}`
  }

  const response = await fetch(downloadUrl, {
    headers: {
      'Authorization': `Bearer ${accessToken}`
    }
  })

  if (!response.ok) {
    throw new Error(`Failed to download file: ${response.status} ${response.statusText}`)
  }

  return new Uint8Array(await response.arrayBuffer())
}

// Get export MIME type for Google Workspace files
function getExportMimeType(mimeType: string): string {
  const exportMap: Record<string, string> = {
    'application/vnd.google-apps.document': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.google-apps.spreadsheet': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.google-apps.presentation': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.google-apps.drawing': 'image/png'
  }

  return exportMap[mimeType] || 'text/plain'
}

// Extract text content based on file type
async function extractTextContent(content: Uint8Array, mimeType: string, performOCR: boolean): Promise<string> {
  try {
    switch (mimeType) {
      case 'text/plain':
      case 'text/csv':
        return new TextDecoder().decode(content)
      
      case 'application/pdf':
        return await extractPDFText(content, performOCR)
      
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return await extractDocxText(content)
      
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return await extractXlsxText(content)
      
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return await extractPptxText(content)
      
      case 'text/html':
        return await extractHTMLText(content)
      
      default:
        // For image files, try OCR if enabled
        if (mimeType.startsWith('image/') && performOCR) {
          return await performOCRExtraction(content)
        }
        
        // For other files, try to decode as text
        try {
          return new TextDecoder().decode(content)
        } catch {
          return `[Binary file: ${mimeType}]`
        }
    }
  } catch (error) {
    console.error(`Text extraction error for ${mimeType}:`, error)
    return `[Text extraction failed: ${error.message}]`
  }
}

// PDF text extraction (simplified - in production use pdf-parse or similar)
async function extractPDFText(content: Uint8Array, performOCR: boolean): Promise<string> {
  // Placeholder for PDF text extraction
  // In production, use libraries like pdf-parse or PDF.js
  
  if (performOCR) {
    // Placeholder for OCR processing
    return '[PDF content - OCR not implemented in this example]'
  }
  
  return '[PDF content - text extraction requires pdf-parse library]'
}

// DOCX text extraction (simplified)
async function extractDocxText(content: Uint8Array): Promise<string> {
  // Placeholder for DOCX text extraction
  // In production, use libraries like mammoth.js or docx-parser
  return '[DOCX content - text extraction requires mammoth.js or similar library]'
}

// XLSX text extraction (simplified)
async function extractXlsxText(content: Uint8Array): Promise<string> {
  // Placeholder for XLSX text extraction
  // In production, use libraries like xlsx or exceljs
  return '[XLSX content - text extraction requires xlsx library]'
}

// PPTX text extraction (simplified)
async function extractPptxText(content: Uint8Array): Promise<string> {
  // Placeholder for PPTX text extraction
  // In production, use libraries that can parse PPTX files
  return '[PPTX content - text extraction requires pptx parser library]'
}

// HTML text extraction
async function extractHTMLText(content: Uint8Array): Promise<string> {
  const html = new TextDecoder().decode(content)
  // Simple HTML tag removal (in production, use proper HTML parser)
  return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
}

// OCR extraction (placeholder)
async function performOCRExtraction(content: Uint8Array): Promise<string> {
  // Placeholder for OCR processing
  // In production, integrate with services like Google Vision API, Tesseract.js, etc.
  return '[OCR extraction - requires integration with OCR service]'
}

// Generate content summary using AI
async function generateContentSummary(text: string): Promise<string> {
  // Placeholder for AI-powered summarization
  // In production, integrate with OpenAI, Anthropic, or other AI services
  
  if (text.length > 1000) {
    // Simple extractive summary - take first few sentences
    const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 10)
    return sentences.slice(0, 3).join('. ').trim() + '.'
  }
  
  return text.substring(0, 500) + (text.length > 500 ? '...' : '')
}

// Extract key entities from text
async function extractKeyEntities(text: string): Promise<any[]> {
  // Placeholder for entity extraction
  // In production, use NLP libraries or AI services
  
  const entities: any[] = []
  
  // Simple regex-based entity extraction (very basic)
  const emailRegex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g
  const phoneRegex = /\b(\+63|09)\d{9,10}\b/g
  const currencyRegex = /₱[\d,]+(?:\.\d{2})?|\bPHP\s*[\d,]+(?:\.\d{2})?/g
  
  // Extract emails
  const emails = text.match(emailRegex) || []
  emails.forEach(email => {
    entities.push({ type: 'email', value: email, confidence: 0.9 })
  })
  
  // Extract phone numbers
  const phones = text.match(phoneRegex) || []
  phones.forEach(phone => {
    entities.push({ type: 'phone', value: phone, confidence: 0.8 })
  })
  
  // Extract currency amounts
  const amounts = text.match(currencyRegex) || []
  amounts.forEach(amount => {
    entities.push({ type: 'currency', value: amount, confidence: 0.7 })
  })
  
  return entities.slice(0, 50) // Limit to 50 entities
}

// Detect PII patterns
async function detectPIIPatterns(supabase: any, text: string): Promise<{ detected: boolean; types: string[] }> {
  // Get PII detection patterns from database
  const { data: patterns, error } = await supabase
    .from('drive_intelligence.pii_detection_patterns')
    .select('*')
    .eq('enabled', true)

  if (error || !patterns) {
    console.error('Failed to load PII patterns:', error)
    return { detected: false, types: [] }
  }

  const detectedTypes: string[] = []

  for (const pattern of patterns) {
    try {
      const regex = new RegExp(pattern.pattern_regex, 'gi')
      if (regex.test(text)) {
        detectedTypes.push(pattern.pii_type)
      }
    } catch (error) {
      console.error(`Invalid regex pattern ${pattern.pattern_name}:`, error)
    }
  }

  return {
    detected: detectedTypes.length > 0,
    types: [...new Set(detectedTypes)] // Remove duplicates
  }
}

// Calculate quality score
function calculateQualityScore(fileRecord: any, extractedText: string, keyEntities: any[]): number {
  let score = 0.5 // Base score

  // Text content score (0.0 - 0.3)
  if (extractedText.length > 0) {
    const textScore = Math.min(extractedText.length / 10000, 1) * 0.3
    score += textScore
  }

  // Entity extraction score (0.0 - 0.2)
  if (keyEntities.length > 0) {
    const entityScore = Math.min(keyEntities.length / 20, 1) * 0.2
    score += entityScore
  }

  // File completeness score (0.0 - 0.2)
  if (fileRecord.file_size_bytes > 0 && fileRecord.md5_checksum) {
    score += 0.2
  }

  return Math.min(score, 1.0)
}

// Trigger intelligence processing for substantial content
async function triggerIntelligenceProcessing(fileId: string, priority: string): Promise<void> {
  try {
    const response = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/drive-intelligence-processor`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        fileId,
        analysisType: 'standard',
        priority
      })
    })

    if (!response.ok) {
      console.error(`Failed to trigger intelligence processing for ${fileId}:`, response.statusText)
    }
  } catch (error) {
    console.error(`Error triggering intelligence processing for ${fileId}:`, error)
  }
}

export default serve