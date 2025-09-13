/**
 * Scout v7.1 RAG Retrieval Edge Function
 * Hybrid semantic search with vector similarity + BM25 + metadata filtering
 * Implements RetrieverAgent with Analyzer persona
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface RAGRequest {
  query: string
  context?: {
    filters?: Record<string, any>
    entities?: string[]
    currentPage?: string
    userRole?: 'executive' | 'analyst' | 'store_manager'
  }
  retrievalParams?: {
    topK?: number
    threshold?: number
    includeMetadata?: boolean
    sourceTypes?: string[]
    maxAge?: number // hours
  }
}

interface RAGResponse {
  retrievedChunks: Array<{
    chunkId: string
    content: string
    similarity: number
    sourceType: string
    metadata: Record<string, any>
    rank: number
  }>
  knowledgeGraphEntities: Array<{
    entityId: string
    entityName: string
    entityType: string
    relationshipPath: string[]
    relevanceScore: number
  }>
  aggregatedContext: {
    summary: string
    keyEntities: string[]
    relevantMetrics: string[]
    suggestions: string[]
  }
  metadata: {
    totalChunksRetrieved: number
    vectorSearchTime: number
    kgTraversalTime: number
    hybridRankingApplied: boolean
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get user context
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      throw new Error('Unauthorized')
    }

    const requestData: RAGRequest = await req.json()
    const { 
      query, 
      context = {}, 
      retrievalParams = {} 
    } = requestData

    const {
      topK = 8,
      threshold = 0.7,
      includeMetadata = true,
      sourceTypes = ['documentation', 'market_intel', 'product_catalog'],
      maxAge = 168 // 7 days
    } = retrievalParams

    console.log('RAG Retrieval Request:', {
      query: query.substring(0, 100) + '...',
      topK,
      threshold,
      user: user.id
    })

    const startTime = Date.now()

    // Step 1: Generate embedding for the query
    const queryEmbedding = await generateEmbedding(query)
    const vectorSearchStart = Date.now()

    // Step 2: Perform hybrid semantic search
    const { data: vectorResults, error: vectorError } = await supabase.rpc('platinum.fn_rag_semantic_search', {
      _query: query,
      _embedding: queryEmbedding,
      _tenant_id: user.app_metadata?.tenant_id || user.user_metadata?.tenant_id,
      _threshold: threshold,
      _limit: topK
    })

    if (vectorError) {
      console.error('Vector search error:', vectorError)
      throw new Error(`Vector search failed: ${vectorError.message}`)
    }

    const vectorSearchTime = Date.now() - vectorSearchStart

    // Step 3: Perform knowledge graph traversal for entity enrichment
    const kgTraversalStart = Date.now()
    const kgEntities = await performKnowledgeGraphTraversal(query, context.entities || [], supabase)
    const kgTraversalTime = Date.now() - kgTraversalStart

    // Step 4: Apply hybrid ranking (combine vector similarity + BM25 + metadata)
    const rankedChunks = await applyHybridRanking(vectorResults || [], query, context)

    // Step 5: Filter by source types and age
    const filteredChunks = rankedChunks.filter(chunk => {
      const isValidSourceType = sourceTypes.includes(chunk.source_type)
      const isWithinAge = !maxAge || isWithinMaxAge(chunk.metadata?.created_at, maxAge)
      return isValidSourceType && isWithinAge
    })

    // Step 6: Generate aggregated context
    const aggregatedContext = generateAggregatedContext(filteredChunks, kgEntities, context)

    const response: RAGResponse = {
      retrievedChunks: filteredChunks.map((chunk, index) => ({
        chunkId: chunk.chunk_id,
        content: chunk.chunk_text,
        similarity: chunk.similarity_score,
        sourceType: chunk.source_type,
        metadata: includeMetadata ? chunk.metadata : {},
        rank: index + 1
      })),
      knowledgeGraphEntities: kgEntities,
      aggregatedContext,
      metadata: {
        totalChunksRetrieved: filteredChunks.length,
        vectorSearchTime,
        kgTraversalTime,
        hybridRankingApplied: true
      }
    }

    const totalTime = Date.now() - startTime
    console.log('RAG Retrieval Success:', {
      chunksRetrieved: filteredChunks.length,
      kgEntities: kgEntities.length,
      totalTime,
      vectorSearchTime,
      kgTraversalTime
    })

    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('RAG Retrieval Error:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message,
        retrievedChunks: [],
        knowledgeGraphEntities: [],
        aggregatedContext: {
          summary: '',
          keyEntities: [],
          relevantMetrics: [],
          suggestions: []
        },
        metadata: {
          totalChunksRetrieved: 0,
          vectorSearchTime: 0,
          kgTraversalTime: 0,
          hybridRankingApplied: false
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})

async function generateEmbedding(text: string): Promise<number[]> {
  // Use OpenAI API for embedding generation
  const openaiApiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiApiKey) {
    throw new Error('OpenAI API key not configured')
  }

  try {
    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        input: text,
        model: 'text-embedding-ada-002'
      })
    })

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`)
    }

    const data = await response.json()
    return data.data[0].embedding
  } catch (error) {
    console.error('Embedding generation failed:', error)
    throw new Error('Failed to generate query embedding')
  }
}

async function performKnowledgeGraphTraversal(
  query: string, 
  entityHints: string[], 
  supabase: any
): Promise<Array<{
  entityId: string
  entityName: string
  entityType: string
  relationshipPath: string[]
  relevanceScore: number
}>> {
  // Extract potential entity references from query
  const queryLower = query.toLowerCase()
  const extractedEntities: string[] = []
  
  // Simple entity extraction (could be enhanced with NER)
  const entityKeywords = {
    brand: ['alaska', 'oishi', 'nestea', 'coke', 'pepsi'],
    category: ['beverage', 'snack', 'cigarette', 'food'],
    location: ['ncr', 'metro manila', 'cebu', 'davao']
  }

  Object.entries(entityKeywords).forEach(([entityType, keywords]) => {
    keywords.forEach(keyword => {
      if (queryLower.includes(keyword)) {
        extractedEntities.push(entityType)
      }
    })
  })

  // Combine with entity hints
  const allEntities = [...new Set([...extractedEntities, ...entityHints])]
  
  if (allEntities.length === 0) {
    return []
  }

  try {
    // Find KG entities matching the extracted entities
    const { data: kgMatches } = await supabase
      .from('platinum.kg_entities')
      .select('id, entity_name, entity_type, entity_attributes')
      .in('entity_type', allEntities)
      .limit(20)

    if (!kgMatches || kgMatches.length === 0) {
      return []
    }

    const results: any[] = []

    // For each matched entity, find related entities
    for (const entity of kgMatches) {
      const { data: relatedEntities } = await supabase.rpc('platinum.fn_kg_find_related_entities', {
        _entity_id: entity.id,
        _relationship_types: ['parent_of', 'child_of', 'substitutes'],
        _max_depth: 2
      })

      if (relatedEntities) {
        relatedEntities.forEach((related: any) => {
          results.push({
            entityId: related.entity_id,
            entityName: related.entity_name,
            entityType: related.entity_type,
            relationshipPath: related.relationship_path,
            relevanceScore: calculateEntityRelevance(related, query, entity)
          })
        })
      }
    }

    // Sort by relevance and return top results
    return results
      .sort((a, b) => b.relevanceScore - a.relevanceScore)
      .slice(0, 10)

  } catch (error) {
    console.error('Knowledge graph traversal error:', error)
    return []
  }
}

function calculateEntityRelevance(entity: any, query: string, sourceEntity: any): number {
  let score = 0.5 // Base relevance
  
  // Increase score based on entity name appearing in query
  if (query.toLowerCase().includes(entity.entity_name.toLowerCase())) {
    score += 0.3
  }
  
  // Increase score for closer relationships
  const pathLength = entity.relationship_path?.length || 0
  score += Math.max(0, (3 - pathLength) * 0.1)
  
  // Boost score for certain entity types
  if (entity.entity_type === 'brand' || entity.entity_type === 'category') {
    score += 0.1
  }
  
  return Math.min(1.0, score)
}

async function applyHybridRanking(
  vectorResults: any[], 
  query: string, 
  context: any
): Promise<any[]> {
  // Implement hybrid ranking combining:
  // 1. Vector similarity (already provided)
  // 2. BM25 text matching
  // 3. Metadata relevance
  
  return vectorResults.map(chunk => {
    const vectorScore = chunk.similarity_score
    const bm25Score = calculateBM25Score(chunk.chunk_text, query)
    const metadataScore = calculateMetadataRelevance(chunk.metadata, context)
    
    // Weighted combination (can be tuned)
    const hybridScore = (vectorScore * 0.6) + (bm25Score * 0.3) + (metadataScore * 0.1)
    
    return {
      ...chunk,
      hybrid_score: hybridScore
    }
  }).sort((a, b) => b.hybrid_score - a.hybrid_score)
}

function calculateBM25Score(text: string, query: string): number {
  // Simplified BM25 implementation
  const k1 = 1.2
  const b = 0.75
  const avgDocLength = 500 // Estimated average chunk length
  
  const queryTerms = query.toLowerCase().split(/\s+/)
  const docTerms = text.toLowerCase().split(/\s+/)
  const docLength = docTerms.length
  
  let score = 0
  
  queryTerms.forEach(term => {
    const termFreq = docTerms.filter(t => t.includes(term)).length
    if (termFreq > 0) {
      const idf = Math.log((1000 + 1) / (100 + 1)) // Simplified IDF
      const tf = (termFreq * (k1 + 1)) / (termFreq + k1 * (1 - b + b * (docLength / avgDocLength)))
      score += idf * tf
    }
  })
  
  // Normalize to 0-1 range
  return Math.min(1.0, score / 10)
}

function calculateMetadataRelevance(metadata: any, context: any): number {
  let score = 0.5 // Base score
  
  // Boost recent content
  if (metadata?.created_at) {
    const ageHours = (Date.now() - new Date(metadata.created_at).getTime()) / (1000 * 60 * 60)
    if (ageHours < 24) score += 0.2
    else if (ageHours < 168) score += 0.1
  }
  
  // Boost content matching current page context
  if (context.currentPage && metadata?.source_page === context.currentPage) {
    score += 0.2
  }
  
  // Boost content matching user role
  if (context.userRole && metadata?.target_role === context.userRole) {
    score += 0.1
  }
  
  return Math.min(1.0, score)
}

function generateAggregatedContext(
  chunks: any[], 
  kgEntities: any[], 
  context: any
): {
  summary: string
  keyEntities: string[]
  relevantMetrics: string[]
  suggestions: string[]
} {
  // Extract key entities from chunks and KG
  const keyEntities = [
    ...new Set([
      ...kgEntities.slice(0, 5).map(e => e.entityName),
      ...chunks.flatMap(c => extractEntitiesFromText(c.chunk_text)).slice(0, 5)
    ])
  ]
  
  // Identify relevant metrics mentioned in chunks
  const metricKeywords = ['revenue', 'sales', 'units', 'quantity', 'transactions', 'basket']
  const relevantMetrics = [
    ...new Set(
      chunks.flatMap(c => 
        metricKeywords.filter(m => 
          c.chunk_text.toLowerCase().includes(m)
        )
      )
    )
  ].slice(0, 3)
  
  // Generate summary
  const summary = generateContextSummary(chunks, keyEntities, relevantMetrics)
  
  // Generate suggestions
  const suggestions = generateSuggestions(chunks, context, keyEntities)
  
  return {
    summary,
    keyEntities,
    relevantMetrics,
    suggestions
  }
}

function extractEntitiesFromText(text: string): string[] {
  // Simple entity extraction from text
  const entities: string[] = []
  const entityPatterns = {
    brands: /\b(alaska|oishi|nestea|coke|pepsi|san miguel|lucky me)\b/gi,
    categories: /\b(beverage|snack|cigarette|tobacco|food|drink)\b/gi,
    locations: /\b(ncr|metro manila|cebu|davao|manila|quezon city)\b/gi
  }
  
  Object.values(entityPatterns).forEach(pattern => {
    const matches = text.match(pattern)
    if (matches) {
      entities.push(...matches.map(m => m.toLowerCase()))
    }
  })
  
  return [...new Set(entities)]
}

function generateContextSummary(chunks: any[], entities: string[], metrics: string[]): string {
  if (chunks.length === 0) {
    return "No relevant context found for this query."
  }
  
  const entityText = entities.length > 0 ? ` Key entities: ${entities.join(', ')}.` : ''
  const metricText = metrics.length > 0 ? ` Relevant metrics: ${metrics.join(', ')}.` : ''
  
  return `Found ${chunks.length} relevant pieces of information.${entityText}${metricText} Context includes market intelligence, product data, and analytical insights.`
}

function generateSuggestions(chunks: any[], context: any, entities: string[]): string[] {
  const suggestions: string[] = []
  
  // Entity-based suggestions
  if (entities.length > 0) {
    suggestions.push(`Analyze ${entities[0]} performance trends`)
    if (entities.length > 1) {
      suggestions.push(`Compare ${entities[0]} vs ${entities[1]}`)
    }
  }
  
  // Context-based suggestions
  if (context.currentPage === 'competitive-analysis') {
    suggestions.push('View market share analysis')
    suggestions.push('Check substitution rates')
  } else if (context.currentPage === 'product-mix') {
    suggestions.push('Explore cross-selling opportunities')
    suggestions.push('Analyze basket composition')
  }
  
  // Default suggestions
  if (suggestions.length === 0) {
    suggestions.push('Show revenue trends')
    suggestions.push('Compare brand performance')
    suggestions.push('Analyze geographic distribution')
  }
  
  return suggestions.slice(0, 3)
}

function isWithinMaxAge(createdAt: string, maxAgeHours: number): boolean {
  if (!createdAt) return true
  const ageHours = (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60)
  return ageHours <= maxAgeHours
}