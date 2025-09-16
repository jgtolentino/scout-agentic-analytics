// Google Drive Intelligence Processor - AI-Powered Document Analysis
// Scout v7 Analytics Platform
// Purpose: Advanced document analysis, categorization, and business intelligence

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AnalysisRequest {
  fileId: string
  analysisType?: 'basic' | 'standard' | 'comprehensive'
  priority?: 'low' | 'medium' | 'high' | 'critical'
  forceReanalysis?: boolean
}

interface AnalysisResponse {
  success: boolean
  fileId: string
  analysisType: string
  insights: {
    documentType?: string
    businessValue?: string
    urgencyLevel?: string
    sentimentScore?: number
    mainTopics?: string[]
    keyThemes?: string[]
    mentionedBrands?: string[]
    financialFigures?: any[]
    actionItems?: string[]
    riskIndicators?: string[]
  }
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
      analysisType = 'standard',
      priority = 'medium',
      forceReanalysis = false
    }: AnalysisRequest = await req.json()

    if (!fileId) {
      throw new Error('fileId is required')
    }

    console.log(`Starting intelligence processing: ${fileId} (${analysisType})`)

    // Get file record with extracted text
    const { data: fileRecord, error: fileError } = await supabase
      .from('drive_intelligence.bronze_files')
      .select('*')
      .eq('file_id', fileId)
      .single()

    if (fileError || !fileRecord) {
      throw new Error(`File not found in database: ${fileId}`)
    }

    if (!fileRecord.extracted_text || fileRecord.extracted_text.trim().length === 0) {
      throw new Error('No extracted text available for analysis')
    }

    // Check if analysis already exists and not forcing reanalysis
    if (!forceReanalysis) {
      const { data: existingAnalysis } = await supabase
        .from('drive_intelligence.silver_document_intelligence')
        .select('*')
        .eq('file_id', fileId)
        .single()

      if (existingAnalysis) {
        console.log(`Analysis already exists for ${fileId}, skipping`)
        return new Response(JSON.stringify({
          success: true,
          fileId,
          analysisType: 'existing',
          message: 'Analysis already exists',
          processingTime: Date.now() - startTime
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        })
      }
    }

    // Perform AI-powered analysis
    const analysisResult = await performDocumentAnalysis(
      fileRecord.extracted_text,
      fileRecord.file_name,
      fileRecord.mime_type,
      analysisType
    )

    // Classify document type based on content and filename
    const documentType = await classifyDocument(
      supabase,
      fileRecord.file_name,
      fileRecord.extracted_text,
      fileRecord.folder_path
    )

    // Calculate business value and urgency
    const businessMetrics = await calculateBusinessMetrics(
      fileRecord.extracted_text,
      analysisResult,
      documentType
    )

    // Insert or update silver layer analysis
    const silverData = {
      file_id: fileId,
      document_title: extractDocumentTitle(fileRecord.file_name, fileRecord.extracted_text),
      author_name: extractAuthorName(fileRecord.extracted_text),
      language_detected: detectLanguage(fileRecord.extracted_text),
      word_count: countWords(fileRecord.extracted_text),
      main_topics: analysisResult.topics || [],
      key_themes: analysisResult.themes || [],
      sentiment_score: analysisResult.sentimentScore || 0,
      urgency_level: businessMetrics.urgencyLevel,
      mentioned_brands: analysisResult.brands || [],
      mentioned_products: analysisResult.products || [],
      mentioned_campaigns: analysisResult.campaigns || [],
      mentioned_competitors: analysisResult.competitors || [],
      financial_figures: analysisResult.financialFigures || [],
      dates_mentioned: analysisResult.dates || [],
      related_documents: [], // To be implemented with vector similarity
      readability_score: calculateReadabilityScore(fileRecord.extracted_text),
      completeness_score: businessMetrics.completenessScore,
      accuracy_confidence: analysisResult.confidenceScore || 0.8,
      relevant_business_units: analysisResult.businessUnits || [],
      action_items_count: analysisResult.actionItems?.length || 0,
      decision_points_count: analysisResult.decisionPoints?.length || 0,
      risk_indicators: analysisResult.riskIndicators || [],
      document_freshness_days: calculateDocumentFreshness(fileRecord.modified_time),
      update_frequency: inferUpdateFrequency(fileRecord.file_name, analysisResult.topics),
      ai_processing_version: 'v1.0',
      extraction_confidence: analysisResult.confidenceScore || 0.7,
      processed_at: new Date().toISOString(),
      last_analyzed: new Date().toISOString()
    }

    const { error: silverError } = await supabase
      .from('drive_intelligence.silver_document_intelligence')
      .upsert(silverData, { onConflict: 'file_id' })

    if (silverError) {
      throw new Error(`Failed to save analysis: ${silverError.message}`)
    }

    // Update bronze file with document type and business value
    await supabase
      .from('drive_intelligence.bronze_files')
      .update({
        document_type: documentType,
        business_value: businessMetrics.businessValue,
        updated_at: new Date().toISOString()
      })
      .eq('file_id', fileId)

    // Create specialized analysis based on document type
    await createSpecializedAnalysis(supabase, fileId, documentType, fileRecord, analysisResult)

    const response: AnalysisResponse = {
      success: true,
      fileId,
      analysisType,
      insights: {
        documentType,
        businessValue: businessMetrics.businessValue,
        urgencyLevel: businessMetrics.urgencyLevel,
        sentimentScore: analysisResult.sentimentScore,
        mainTopics: analysisResult.topics,
        keyThemes: analysisResult.themes,
        mentionedBrands: analysisResult.brands,
        financialFigures: analysisResult.financialFigures,
        actionItems: analysisResult.actionItems,
        riskIndicators: analysisResult.riskIndicators
      },
      processingTime: Date.now() - startTime,
      errors: []
    }

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Intelligence processing error:', error)

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

// Perform AI-powered document analysis
async function performDocumentAnalysis(
  text: string, 
  fileName: string, 
  mimeType: string, 
  analysisType: string
): Promise<any> {
  // This is a simplified analysis. In production, integrate with:
  // - OpenAI GPT-4 for comprehensive analysis
  // - Anthropic Claude for document understanding
  // - Google Cloud Natural Language API
  // - Azure Cognitive Services

  const analysis: any = {
    topics: [],
    themes: [],
    brands: [],
    products: [],
    campaigns: [],
    competitors: [],
    financialFigures: [],
    dates: [],
    businessUnits: [],
    actionItems: [],
    decisionPoints: [],
    riskIndicators: [],
    sentimentScore: 0,
    confidenceScore: 0.7
  }

  // Basic keyword extraction for topics
  analysis.topics = extractTopics(text, fileName)
  
  // Extract themes
  analysis.themes = extractThemes(text)
  
  // Extract brand mentions
  analysis.brands = extractBrandMentions(text)
  
  // Extract financial figures
  analysis.financialFigures = extractFinancialFigures(text)
  
  // Extract dates
  analysis.dates = extractDates(text)
  
  // Extract action items
  analysis.actionItems = extractActionItems(text)
  
  // Calculate sentiment (simplified)
  analysis.sentimentScore = calculateSentiment(text)
  
  // Extract risk indicators
  analysis.riskIndicators = extractRiskIndicators(text)

  // For comprehensive analysis, add more detailed processing
  if (analysisType === 'comprehensive') {
    analysis.businessUnits = extractBusinessUnits(text)
    analysis.decisionPoints = extractDecisionPoints(text)
    analysis.competitors = extractCompetitors(text)
    analysis.campaigns = extractCampaigns(text)
    analysis.products = extractProducts(text)
    analysis.confidenceScore = 0.8
  }

  return analysis
}

// Extract main topics from text
function extractTopics(text: string, fileName: string): string[] {
  const topics: string[] = []
  
  // Common business topics
  const topicKeywords = {
    'marketing': ['marketing', 'campaign', 'advertising', 'promotion', 'brand'],
    'financial': ['budget', 'revenue', 'cost', 'expense', 'profit', 'roi'],
    'strategy': ['strategy', 'strategic', 'planning', 'roadmap', 'vision'],
    'research': ['research', 'analysis', 'survey', 'insights', 'study'],
    'creative': ['creative', 'design', 'concept', 'visual', 'artwork'],
    'digital': ['digital', 'online', 'website', 'social media', 'seo'],
    'performance': ['performance', 'metrics', 'kpi', 'results', 'effectiveness'],
    'client': ['client', 'customer', 'account', 'relationship', 'service']
  }

  const textLower = text.toLowerCase()
  const fileNameLower = fileName.toLowerCase()

  for (const [topic, keywords] of Object.entries(topicKeywords)) {
    const matches = keywords.filter(keyword => 
      textLower.includes(keyword) || fileNameLower.includes(keyword)
    )
    
    if (matches.length >= 2 || (matches.length === 1 && textLower.split(matches[0]).length > 3)) {
      topics.push(topic)
    }
  }

  return topics
}

// Extract themes from text
function extractThemes(text: string): string[] {
  const themes: string[] = []
  
  const themePatterns = {
    'innovation': /innovat(e|ion|ive)|disruption|transformation|digital|technology/gi,
    'growth': /growth|expansion|scale|increase|develop|opportunity/gi,
    'efficiency': /efficiency|optimization|streamline|automation|process/gi,
    'customer_focus': /customer|client|user|experience|satisfaction|engagement/gi,
    'collaboration': /collaboration|teamwork|partnership|cooperation|synergy/gi,
    'quality': /quality|excellence|improvement|enhancement|standards/gi,
    'sustainability': /sustainability|environmental|green|responsible|ethical/gi,
    'agility': /agile|flexible|adaptive|responsive|quick|fast/gi
  }

  for (const [theme, pattern] of Object.entries(themePatterns)) {
    const matches = text.match(pattern)
    if (matches && matches.length >= 2) {
      themes.push(theme)
    }
  }

  return themes
}

// Extract brand mentions
function extractBrandMentions(text: string): string[] {
  // Common TBWA client brands (extend this list)
  const brands = [
    'Absolut', 'Adidas', 'Apple', 'Chanel', 'Gatorade', 'Hennessy',
    'McDonald\'s', 'Michelin', 'Nissan', 'Pedigree', 'Singapore Airlines'
  ]
  
  const mentioned = brands.filter(brand => 
    text.toLowerCase().includes(brand.toLowerCase())
  )
  
  return mentioned
}

// Extract financial figures
function extractFinancialFigures(text: string): any[] {
  const figures: any[] = []
  
  // PHP currency pattern
  const phpPattern = /₱[\d,]+(?:\.\d{2})?|\bPHP\s*[\d,]+(?:\.\d{2})?/g
  const phpMatches = text.match(phpPattern) || []
  
  phpMatches.forEach(match => {
    figures.push({
      type: 'currency',
      value: match,
      currency: 'PHP',
      amount: parseFloat(match.replace(/[₱,PHP\s]/g, ''))
    })
  })
  
  // USD currency pattern
  const usdPattern = /\$[\d,]+(?:\.\d{2})?|\bUSD\s*[\d,]+(?:\.\d{2})?/g
  const usdMatches = text.match(usdPattern) || []
  
  usdMatches.forEach(match => {
    figures.push({
      type: 'currency',
      value: match,
      currency: 'USD',
      amount: parseFloat(match.replace(/[\$,USD\s]/g, ''))
    })
  })
  
  // Percentage pattern
  const percentPattern = /\b\d+(?:\.\d+)?%/g
  const percentMatches = text.match(percentPattern) || []
  
  percentMatches.forEach(match => {
    figures.push({
      type: 'percentage',
      value: match,
      percentage: parseFloat(match.replace('%', ''))
    })
  })
  
  return figures.slice(0, 20) // Limit to 20 figures
}

// Extract dates
function extractDates(text: string): any[] {
  const dates: any[] = []
  
  // Various date patterns
  const datePatterns = [
    /\b\d{1,2}\/\d{1,2}\/\d{4}\b/g,  // MM/DD/YYYY or DD/MM/YYYY
    /\b\d{4}-\d{1,2}-\d{1,2}\b/g,    // YYYY-MM-DD
    /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}\b/gi,
    /\b\d{1,2}\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}\b/gi
  ]
  
  datePatterns.forEach(pattern => {
    const matches = text.match(pattern) || []
    matches.forEach(match => {
      dates.push({
        type: 'date',
        value: match,
        extracted_at: new Date().toISOString()
      })
    })
  })
  
  return dates.slice(0, 10) // Limit to 10 dates
}

// Extract action items
function extractActionItems(text: string): string[] {
  const actionPatterns = [
    /(?:action item|action|todo|task):\s*(.+?)(?:\n|$)/gi,
    /(?:•|\*|-|\d+\.)\s*(.+?)(?:\n|$)/g,
    /(?:need to|must|should|will|shall)\s+(.+?)(?:\.|,|\n|$)/gi
  ]
  
  const actionItems: string[] = []
  
  actionPatterns.forEach(pattern => {
    const matches = text.matchAll(pattern)
    for (const match of matches) {
      if (match[1] && match[1].trim().length > 10 && match[1].trim().length < 200) {
        actionItems.push(match[1].trim())
      }
    }
  })
  
  return actionItems.slice(0, 10) // Limit to 10 action items
}

// Calculate sentiment score (-1 to 1)
function calculateSentiment(text: string): number {
  const positiveWords = ['good', 'great', 'excellent', 'positive', 'success', 'achieve', 'improve', 'effective', 'strong', 'growth']
  const negativeWords = ['bad', 'poor', 'negative', 'fail', 'problem', 'issue', 'concern', 'decline', 'weak', 'challenge']
  
  const textLower = text.toLowerCase()
  
  let positiveCount = 0
  let negativeCount = 0
  
  positiveWords.forEach(word => {
    const matches = textLower.split(word).length - 1
    positiveCount += matches
  })
  
  negativeWords.forEach(word => {
    const matches = textLower.split(word).length - 1
    negativeCount += matches
  })
  
  const totalSentimentWords = positiveCount + negativeCount
  if (totalSentimentWords === 0) return 0
  
  return (positiveCount - negativeCount) / totalSentimentWords
}

// Extract risk indicators
function extractRiskIndicators(text: string): string[] {
  const riskKeywords = [
    'risk', 'threat', 'concern', 'issue', 'problem', 'challenge',
    'delay', 'behind schedule', 'over budget', 'compliance',
    'legal', 'regulatory', 'audit', 'violation'
  ]
  
  const indicators: string[] = []
  const textLower = text.toLowerCase()
  
  riskKeywords.forEach(keyword => {
    if (textLower.includes(keyword)) {
      indicators.push(keyword)
    }
  })
  
  return [...new Set(indicators)] // Remove duplicates
}

// Additional extraction functions for comprehensive analysis
function extractBusinessUnits(text: string): string[] {
  const units = ['creative', 'strategy', 'media', 'digital', 'pr', 'account management', 'production', 'insights']
  return units.filter(unit => text.toLowerCase().includes(unit))
}

function extractDecisionPoints(text: string): string[] {
  const decisionPatterns = [
    /decision:\s*(.+?)(?:\n|$)/gi,
    /(?:decide|choose|select|approve|reject)\s+(.+?)(?:\.|,|\n|$)/gi
  ]
  
  const decisions: string[] = []
  decisionPatterns.forEach(pattern => {
    const matches = text.matchAll(pattern)
    for (const match of matches) {
      if (match[1] && match[1].trim().length > 10) {
        decisions.push(match[1].trim())
      }
    }
  })
  
  return decisions.slice(0, 5)
}

function extractCompetitors(text: string): string[] {
  const competitors = ['competitor', 'rival', 'competition', 'market leader']
  return competitors.filter(comp => text.toLowerCase().includes(comp))
}

function extractCampaigns(text: string): string[] {
  const campaignPatterns = /campaign\s+["']?([^"'\n]+)["']?/gi
  const campaigns: string[] = []
  
  const matches = text.matchAll(campaignPatterns)
  for (const match of matches) {
    if (match[1] && match[1].trim().length > 3) {
      campaigns.push(match[1].trim())
    }
  }
  
  return campaigns.slice(0, 5)
}

function extractProducts(text: string): string[] {
  const productPatterns = /product\s+["']?([^"'\n]+)["']?/gi
  const products: string[] = []
  
  const matches = text.matchAll(productPatterns)
  for (const match of matches) {
    if (match[1] && match[1].trim().length > 3) {
      products.push(match[1].trim())
    }
  }
  
  return products.slice(0, 5)
}

// Classify document using rules and AI
async function classifyDocument(
  supabase: any,
  fileName: string,
  text: string,
  folderPath: string
): Promise<string> {
  // Get classification rules from database
  const { data: rules, error } = await supabase
    .from('drive_intelligence.classification_rules')
    .select('*')
    .eq('enabled', true)
    .order('priority', { ascending: true })

  if (error || !rules) {
    console.error('Failed to load classification rules:', error)
    return 'other'
  }

  // Apply rules in priority order
  for (const rule of rules) {
    try {
      let matches = false

      switch (rule.rule_type) {
        case 'filename_pattern':
          if (rule.pattern_regex) {
            const regex = new RegExp(rule.pattern_regex, 'i')
            matches = regex.test(fileName)
          }
          break
        
        case 'content_keyword':
          if (rule.keywords && Array.isArray(rule.keywords)) {
            matches = rule.keywords.some((keyword: string) => 
              text.toLowerCase().includes(keyword.toLowerCase())
            )
          }
          break
        
        case 'folder_location':
          if (rule.pattern_regex) {
            const regex = new RegExp(rule.pattern_regex, 'i')
            matches = regex.test(folderPath)
          }
          break
      }

      if (matches) {
        return rule.target_classification
      }
    } catch (error) {
      console.error(`Error applying rule ${rule.rule_name}:`, error)
    }
  }

  return 'other'
}

// Calculate business metrics
async function calculateBusinessMetrics(
  text: string,
  analysisResult: any,
  documentType: string
): Promise<any> {
  const metrics = {
    businessValue: 'medium' as 'critical' | 'high' | 'medium' | 'low',
    urgencyLevel: 'medium' as 'low' | 'medium' | 'high' | 'critical',
    completenessScore: 0.8
  }

  // Calculate business value based on document type and content
  if (['strategy_document', 'financial_report', 'campaign_analysis'].includes(documentType)) {
    metrics.businessValue = 'high'
  }

  if (analysisResult.financialFigures?.length > 0 || analysisResult.riskIndicators?.length > 0) {
    metrics.businessValue = 'critical'
  }

  // Calculate urgency based on keywords and sentiment
  const urgentKeywords = ['urgent', 'asap', 'immediate', 'deadline', 'critical']
  const hasUrgentKeywords = urgentKeywords.some(keyword => 
    text.toLowerCase().includes(keyword)
  )

  if (hasUrgentKeywords || analysisResult.sentimentScore < -0.5) {
    metrics.urgencyLevel = 'high'
  }

  if (analysisResult.riskIndicators?.length > 3) {
    metrics.urgencyLevel = 'critical'
  }

  // Calculate completeness score
  let completeness = 0.5
  if (text.length > 1000) completeness += 0.2
  if (analysisResult.topics?.length > 0) completeness += 0.1
  if (analysisResult.financialFigures?.length > 0) completeness += 0.1
  if (analysisResult.actionItems?.length > 0) completeness += 0.1

  metrics.completenessScore = Math.min(completeness, 1.0)

  return metrics
}

// Helper functions
function extractDocumentTitle(fileName: string, text: string): string {
  // Try to extract title from first line of text
  const lines = text.split('\n').filter(line => line.trim().length > 0)
  if (lines.length > 0 && lines[0].length < 100) {
    return lines[0].trim()
  }
  
  // Fallback to filename without extension
  return fileName.replace(/\.[^/.]+$/, '')
}

function extractAuthorName(text: string): string | null {
  const authorPatterns = [
    /author:\s*(.+?)(?:\n|$)/gi,
    /by:\s*(.+?)(?:\n|$)/gi,
    /prepared by:\s*(.+?)(?:\n|$)/gi
  ]
  
  for (const pattern of authorPatterns) {
    const match = text.match(pattern)
    if (match && match[1]) {
      return match[1].trim()
    }
  }
  
  return null
}

function detectLanguage(text: string): string {
  // Simple language detection (in production, use proper language detection library)
  const englishWords = ['the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'is', 'are', 'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'can', 'may', 'might', 'must', 'shall', 'this', 'that', 'these', 'those']
  const filipinoWords = ['ang', 'ng', 'sa', 'at', 'na', 'ay', 'si', 'ni', 'kay', 'para', 'kung', 'kapag', 'dahil', 'kaya', 'pero', 'hindi', 'oo', 'mga', 'ito', 'iyan', 'iyon']
  
  const textLower = text.toLowerCase()
  
  let englishCount = 0
  let filipinoCount = 0
  
  englishWords.forEach(word => {
    if (textLower.includes(` ${word} `)) englishCount++
  })
  
  filipinoWords.forEach(word => {
    if (textLower.includes(` ${word} `)) filipinoCount++
  })
  
  if (filipinoCount > englishCount) return 'tl'
  return 'en'
}

function countWords(text: string): number {
  return text.trim().split(/\s+/).filter(word => word.length > 0).length
}

function calculateReadabilityScore(text: string): number {
  // Simplified Flesch Reading Ease calculation
  const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0).length
  const words = countWords(text)
  const syllables = text.length / 4 // Very rough syllable estimate
  
  if (sentences === 0 || words === 0) return 0
  
  const avgWordsPerSentence = words / sentences
  const avgSyllablesPerWord = syllables / words
  
  const fleschScore = 206.835 - (1.015 * avgWordsPerSentence) - (84.6 * avgSyllablesPerWord)
  
  return Math.max(0, Math.min(100, fleschScore))
}

function calculateDocumentFreshness(modifiedTime: string): number {
  const now = new Date()
  const modified = new Date(modifiedTime)
  const diffTime = Math.abs(now.getTime() - modified.getTime())
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24)) // Days
}

function inferUpdateFrequency(fileName: string, topics: string[]): string {
  const fileName_lower = fileName.toLowerCase()
  
  if (fileName_lower.includes('daily') || topics.includes('performance')) return 'daily'
  if (fileName_lower.includes('weekly')) return 'weekly'
  if (fileName_lower.includes('monthly') || topics.includes('financial')) return 'monthly'
  if (fileName_lower.includes('quarterly')) return 'quarterly'
  if (fileName_lower.includes('annual')) return 'annually'
  
  return 'ad_hoc'
}

// Create specialized analysis based on document type
async function createSpecializedAnalysis(
  supabase: any,
  fileId: string,
  documentType: string,
  fileRecord: any,
  analysisResult: any
): Promise<void> {
  try {
    // Creative asset analysis
    if (['creative_brief', 'campaign_analysis'].includes(documentType)) {
      await supabase
        .from('drive_intelligence.creative_asset_analysis')
        .upsert({
          file_id: fileId,
          creative_type: 'campaign_creative',
          campaign_name: analysisResult.campaigns?.[0] || 'Unknown',
          brand_alignment_score: Math.random() * 0.3 + 0.7, // Placeholder
          engagement_prediction: Math.random() * 0.4 + 0.6, // Placeholder
          brand_safety_score: 1.0,
          accessibility_score: Math.random() * 0.3 + 0.7, // Placeholder
          approval_status: 'pending'
        }, { onConflict: 'file_id' })
    }

    // Financial document analysis
    if (['financial_report', 'budget_planning'].includes(documentType)) {
      const totalAmount = analysisResult.financialFigures?.find((f: any) => f.type === 'currency')?.amount || 0

      await supabase
        .from('drive_intelligence.financial_document_analysis')
        .upsert({
          file_id: fileId,
          financial_type: documentType === 'financial_report' ? 'financial_statement' : 'budget_report',
          total_amount: totalAmount,
          currency_code: 'PHP',
          fiscal_period: extractFiscalPeriod(fileRecord.extracted_text),
          budget_variance_percentage: Math.random() * 20 - 10, // Placeholder
          approval_required: totalAmount > 1000000,
          tax_implications: totalAmount > 500000,
          audit_trail_complete: true
        }, { onConflict: 'file_id' })
    }

    // Research intelligence
    if (['market_research', 'competitive_analysis'].includes(documentType)) {
      await supabase
        .from('drive_intelligence.research_intelligence')
        .upsert({
          file_id: fileId,
          research_type: documentType,
          research_methodology: extractResearchMethodology(fileRecord.extracted_text),
          confidence_level: 0.95, // Placeholder
          margin_of_error: 0.05, // Placeholder
          geographic_scope: 'Philippines',
          primary_insights: analysisResult.actionItems || [],
          actionable_recommendations: analysisResult.actionItems || [],
          risk_factors: analysisResult.riskIndicators || [],
          competitors_analyzed: analysisResult.competitors || [],
          strategic_importance: 'high',
          implementation_priority: 'medium_term'
        }, { onConflict: 'file_id' })
    }
  } catch (error) {
    console.error(`Failed to create specialized analysis for ${fileId}:`, error)
  }
}

function extractFiscalPeriod(text: string): string {
  const periods = ['Q1', 'Q2', 'Q3', 'Q4', '2024', '2025', 'FY24', 'FY25']
  for (const period of periods) {
    if (text.includes(period)) return period
  }
  return 'Unknown'
}

function extractResearchMethodology(text: string): string {
  const methodologies = ['survey', 'interview', 'focus group', 'observation', 'experiment']
  for (const method of methodologies) {
    if (text.toLowerCase().includes(method)) return method
  }
  return 'Mixed methods'
}

export default serve