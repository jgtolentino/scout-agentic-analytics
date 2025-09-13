/**
 * RetrieverAgent - Intelligent Context Retrieval using RAG + Knowledge Graph
 * Scout v7.1 Agentic Analytics Platform
 * 
 * Provides relevant business context and competitive intelligence through
 * hybrid search combining vector similarity, BM25, and knowledge graph traversal.
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import OpenAI from 'https://esm.sh/openai@4.0.0'

// =============================================================================
// TYPES & INTERFACES
// =============================================================================

interface RetrieverAgentRequest {
  query_context: string
  search_scope?: {
    include_domains?: string[]
    exclude_domains?: string[]
    time_range?: {
      start: string
      end: string
    }
  }
  retrieval_depth?: 'shallow' | 'medium' | 'deep'
  user_context: {
    tenant_id: string
    role: 'executive' | 'store_manager' | 'analyst'
  }
}

interface RetrieverAgentResponse {
  retrieved_chunks: RAGChunk[]
  knowledge_graph_paths: KGRelationship[]
  competitive_context: CompetitorInsight[]
  confidence_scores: number[]
  retrieval_metadata: {
    total_chunks_searched: number
    hybrid_ranking_applied: boolean
    vector_similarity_threshold: number
    processing_time_ms: number
    search_strategy: string
  }
}

interface RAGChunk {
  id: string
  chunk_text: string
  relevance_score: number
  source_type: 'business_rule' | 'competitive_intel' | 'historical_insight' | 'market_data'
  metadata: {
    domain: string
    entity_type: string
    confidence: number
    last_updated: string
  }
  vector_similarity: number
  bm25_score: number
  metadata_boost: number
}

interface KGRelationship {
  source_entity: string
  relationship_type: string
  target_entity: string
  strength: number
  context: string
  path_length: number
}

interface CompetitorInsight {
  competitor: string
  insight_type: 'market_share' | 'pricing' | 'product_launch' | 'performance'
  insight_text: string
  confidence: number
  source: string
  relevance_to_query: number
}

// =============================================================================
// HYBRID SEARCH ENGINE
// =============================================================================

class HybridSearchEngine {
  private supabase: any
  private openai: OpenAI

  constructor(supabaseUrl: string, supabaseKey: string, openaiKey: string) {
    this.supabase = createClient(supabaseUrl, supabaseKey)
    this.openai = new OpenAI({ apiKey: openaiKey })
  }

  async search(
    query: string,
    depth: string = 'medium',
    tenantId: string,
    scope?: RetrieverAgentRequest['search_scope']
  ): Promise<RAGChunk[]> {
    
    // 1. Generate query embedding
    const queryEmbedding = await this.generateEmbedding(query)
    
    // 2. Vector similarity search
    const vectorResults = await this.vectorSearch(queryEmbedding, tenantId, scope)
    
    // 3. BM25 full-text search
    const bm25Results = await this.bm25Search(query, tenantId, scope)
    
    // 4. Apply hybrid ranking
    const hybridResults = await this.applyHybridRanking(vectorResults, bm25Results, query)
    
    // 5. Apply depth-based filtering
    const filteredResults = this.applyDepthFiltering(hybridResults, depth)
    
    return filteredResults
  }

  private async generateEmbedding(text: string): Promise<number[]> {
    try {
      const response = await this.openai.embeddings.create({
        model: "text-embedding-ada-002",
        input: text.replace(/\n/g, ' ').trim(),
      })
      
      return response.data[0].embedding
    } catch (error) {
      console.error('Error generating embedding:', error)
      throw new Error('Failed to generate embedding')
    }
  }

  private async vectorSearch(
    embedding: number[],
    tenantId: string,
    scope?: RetrieverAgentRequest['search_scope']
  ): Promise<RAGChunk[]> {
    
    let query = this.supabase
      .from('rag_chunks')
      .select(`
        id,
        chunk_text,
        source_type,
        metadata,
        embedding <-> '[${embedding.join(',')}]' as similarity
      `)
      .eq('tenant_id', tenantId)
      .order('similarity', { ascending: true })
      .limit(50)

    // Apply domain filters
    if (scope?.include_domains?.length) {
      query = query.in('metadata->>domain', scope.include_domains)
    }
    if (scope?.exclude_domains?.length) {
      query = query.not('metadata->>domain', 'in', `(${scope.exclude_domains.join(',')})`)
    }

    // Apply time range filter
    if (scope?.time_range) {
      query = query
        .gte('metadata->>last_updated', scope.time_range.start)
        .lte('metadata->>last_updated', scope.time_range.end)
    }

    const { data, error } = await query

    if (error) {
      console.error('Vector search error:', error)
      return []
    }

    return data?.map((row: any) => ({
      id: row.id,
      chunk_text: row.chunk_text,
      relevance_score: 0, // Will be calculated in hybrid ranking
      source_type: row.source_type,
      metadata: row.metadata,
      vector_similarity: 1 - row.similarity, // Convert distance to similarity
      bm25_score: 0,
      metadata_boost: 0
    })) || []
  }

  private async bm25Search(
    query: string,
    tenantId: string,
    scope?: RetrieverAgentRequest['search_scope']
  ): Promise<RAGChunk[]> {
    
    // Use PostgreSQL full-text search with ranking
    let dbQuery = this.supabase
      .from('rag_chunks')
      .select(`
        id,
        chunk_text,
        source_type,
        metadata,
        ts_rank(to_tsvector('english', chunk_text), plainto_tsquery('english', $1)) as bm25_score
      `)
      .eq('tenant_id', tenantId)
      .textSearch('chunk_text', query, { type: 'websearch' })
      .order('bm25_score', { ascending: false })
      .limit(50)

    // Apply same filters as vector search
    if (scope?.include_domains?.length) {
      dbQuery = dbQuery.in('metadata->>domain', scope.include_domains)
    }
    if (scope?.exclude_domains?.length) {
      dbQuery = dbQuery.not('metadata->>domain', 'in', `(${scope.exclude_domains.join(',')})`)
    }
    if (scope?.time_range) {
      dbQuery = dbQuery
        .gte('metadata->>last_updated', scope.time_range.start)
        .lte('metadata->>last_updated', scope.time_range.end)
    }

    const { data, error } = await dbQuery

    if (error) {
      console.error('BM25 search error:', error)
      return []
    }

    return data?.map((row: any) => ({
      id: row.id,
      chunk_text: row.chunk_text,
      relevance_score: 0,
      source_type: row.source_type,
      metadata: row.metadata,
      vector_similarity: 0,
      bm25_score: row.bm25_score || 0,
      metadata_boost: 0
    })) || []
  }

  private async applyHybridRanking(
    vectorResults: RAGChunk[],
    bm25Results: RAGChunk[],
    query: string
  ): Promise<RAGChunk[]> {
    
    // Combine results by ID
    const combinedResults = new Map<string, RAGChunk>()
    
    // Add vector results
    vectorResults.forEach(chunk => {
      combinedResults.set(chunk.id, chunk)
    })
    
    // Merge BM25 scores
    bm25Results.forEach(chunk => {
      const existing = combinedResults.get(chunk.id)
      if (existing) {
        existing.bm25_score = chunk.bm25_score
      } else {
        combinedResults.set(chunk.id, chunk)
      }
    })
    
    // Calculate metadata boost and final ranking
    const rankedResults = Array.from(combinedResults.values()).map(chunk => {
      const metadataBoost = this.calculateMetadataBoost(chunk, query)
      const hybridScore = this.calculateHybridScore(chunk, metadataBoost)
      
      return {
        ...chunk,
        metadata_boost: metadataBoost,
        relevance_score: hybridScore
      }
    })
    
    // Sort by relevance score and return top results
    return rankedResults
      .sort((a, b) => b.relevance_score - a.relevance_score)
      .slice(0, 30)
  }

  private calculateMetadataBoost(chunk: RAGChunk, query: string): number {
    let boost = 0
    const queryLower = query.toLowerCase()
    const metadata = chunk.metadata

    // Source type boost
    const sourceTypeBoosts = {
      'business_rule': 0.15,
      'competitive_intel': 0.12,
      'historical_insight': 0.10,
      'market_data': 0.08
    }
    boost += sourceTypeBoosts[chunk.source_type as keyof typeof sourceTypeBoosts] || 0

    // Domain relevance boost
    if (metadata.domain && queryLower.includes(metadata.domain.toLowerCase())) {
      boost += 0.1
    }

    // Entity type boost
    if (metadata.entity_type && queryLower.includes(metadata.entity_type.toLowerCase())) {
      boost += 0.08
    }

    // Confidence boost
    boost += (metadata.confidence || 0) * 0.05

    // Recency boost (newer content gets higher score)
    if (metadata.last_updated) {
      const daysSinceUpdate = (Date.now() - new Date(metadata.last_updated).getTime()) / (1000 * 60 * 60 * 24)
      const recencyBoost = Math.max(0, 0.1 * Math.exp(-daysSinceUpdate / 30)) // Decay over 30 days
      boost += recencyBoost
    }

    return Math.min(boost, 0.5) // Cap boost at 0.5
  }

  private calculateHybridScore(chunk: RAGChunk, metadataBoost: number): number {
    // Normalize scores to 0-1 range
    const normalizedVector = Math.min(chunk.vector_similarity, 1)
    const normalizedBM25 = Math.min(chunk.bm25_score / 4, 1) // Assume max BM25 score is 4
    
    // Weighted combination: Vector (60%) + BM25 (30%) + Metadata (10%)
    const hybridScore = (normalizedVector * 0.6) + (normalizedBM25 * 0.3) + (metadataBoost * 0.1)
    
    return Math.min(hybridScore, 1)
  }

  private applyDepthFiltering(results: RAGChunk[], depth: string): RAGChunk[] {
    const depthLimits = {
      'shallow': 5,
      'medium': 15,
      'deep': 30
    }
    
    const limit = depthLimits[depth as keyof typeof depthLimits] || 15
    return results.slice(0, limit)
  }
}

// =============================================================================
// KNOWLEDGE GRAPH TRAVERSAL
// =============================================================================

class KnowledgeGraphTraverser {
  private supabase: any

  constructor(supabase: any) {
    this.supabase = supabase
  }

  async findRelationships(
    entities: string[],
    tenantId: string,
    maxDepth: number = 2
  ): Promise<KGRelationship[]> {
    
    const relationships: KGRelationship[] = []
    
    try {
      // Find direct relationships for each entity
      for (const entity of entities) {
        const directRels = await this.findDirectRelationships(entity, tenantId)
        relationships.push(...directRels)
        
        // Find indirect relationships up to maxDepth
        if (maxDepth > 1) {
          const indirectRels = await this.findIndirectRelationships(entity, tenantId, maxDepth - 1)
          relationships.push(...indirectRels)
        }
      }
      
      // Remove duplicates and sort by strength
      const uniqueRelationships = this.deduplicateRelationships(relationships)
      return uniqueRelationships
        .sort((a, b) => b.strength - a.strength)
        .slice(0, 20) // Limit to top 20 relationships
        
    } catch (error) {
      console.error('Knowledge graph traversal error:', error)
      return []
    }
  }

  private async findDirectRelationships(entity: string, tenantId: string): Promise<KGRelationship[]> {
    const { data, error } = await this.supabase
      .from('knowledge_graph')
      .select('*')
      .eq('tenant_id', tenantId)
      .or(`source_entity.ilike.%${entity}%,target_entity.ilike.%${entity}%`)
      .order('relationship_strength', { ascending: false })
      .limit(10)

    if (error) {
      console.error('Direct relationships query error:', error)
      return []
    }

    return data?.map((row: any) => ({
      source_entity: row.source_entity,
      relationship_type: row.relationship_type,
      target_entity: row.target_entity,
      strength: row.relationship_strength,
      context: row.context || '',
      path_length: 1
    })) || []
  }

  private async findIndirectRelationships(
    entity: string,
    tenantId: string,
    remainingDepth: number
  ): Promise<KGRelationship[]> {
    
    if (remainingDepth <= 0) return []
    
    // Find entities connected to the input entity
    const { data: connectedEntities, error } = await this.supabase
      .from('knowledge_graph')
      .select('target_entity, relationship_strength')
      .eq('tenant_id', tenantId)
      .ilike('source_entity', `%${entity}%`)
      .gt('relationship_strength', 0.3) // Only follow strong relationships
      .limit(5)

    if (error || !connectedEntities) return []

    const indirectRels: KGRelationship[] = []
    
    for (const connected of connectedEntities) {
      const furtherRels = await this.findDirectRelationships(connected.target_entity, tenantId)
      
      // Add path length and adjust strength for indirect relationships
      furtherRels.forEach(rel => {
        rel.path_length = 2
        rel.strength *= 0.7 // Reduce strength for indirect relationships
      })
      
      indirectRels.push(...furtherRels)
    }
    
    return indirectRels
  }

  private deduplicateRelationships(relationships: KGRelationship[]): KGRelationship[] {
    const seen = new Set<string>()
    return relationships.filter(rel => {
      const key = `${rel.source_entity}-${rel.relationship_type}-${rel.target_entity}`
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
  }
}

// =============================================================================
// COMPETITIVE INTELLIGENCE ENGINE
// =============================================================================

class CompetitiveIntelligenceEngine {
  private supabase: any

  constructor(supabase: any) {
    this.supabase = supabase
  }

  async getCompetitiveContext(
    query: string,
    tenantId: string,
    relevantEntities: string[]
  ): Promise<CompetitorInsight[]> {
    
    try {
      // Extract potential competitors and brands from query and entities
      const competitors = await this.identifyRelevantCompetitors(query, relevantEntities)
      
      if (competitors.length === 0) return []
      
      // Fetch competitive insights
      const insights = await this.fetchCompetitiveInsights(competitors, tenantId, query)
      
      return insights
        .sort((a, b) => b.relevance_to_query - a.relevance_to_query)
        .slice(0, 10) // Top 10 most relevant insights
        
    } catch (error) {
      console.error('Competitive intelligence error:', error)
      return []
    }
  }

  private async identifyRelevantCompetitors(query: string, entities: string[]): Promise<string[]> {
    const queryLower = query.toLowerCase()
    const knownCompetitors = [
      'Alaska', 'Nestle', 'Unilever', 'P&G', 'Colgate', 'Johnson', 
      'Coca-Cola', 'Pepsi', 'San Miguel', 'Jollibee', 'McDonalds'
    ]
    
    const relevantCompetitors = new Set<string>()
    
    // Add competitors mentioned in query
    knownCompetitors.forEach(competitor => {
      if (queryLower.includes(competitor.toLowerCase())) {
        relevantCompetitors.add(competitor)
      }
    })
    
    // Add competitors from entities
    entities.forEach(entity => {
      if (knownCompetitors.includes(entity)) {
        relevantCompetitors.add(entity)
      }
    })
    
    // If no specific competitors mentioned, add top competitors
    if (relevantCompetitors.size === 0) {
      ['Alaska', 'Nestle', 'Unilever', 'P&G'].forEach(competitor => {
        relevantCompetitors.add(competitor)
      })
    }
    
    return Array.from(relevantCompetitors)
  }

  private async fetchCompetitiveInsights(
    competitors: string[],
    tenantId: string,
    query: string
  ): Promise<CompetitorInsight[]> {
    
    const { data, error } = await this.supabase
      .from('competitor_analysis')
      .select(`
        competitor_name,
        insight_type,
        insight_description,
        confidence_score,
        data_source,
        analysis_date,
        metadata
      `)
      .eq('tenant_id', tenantId)
      .in('competitor_name', competitors)
      .order('analysis_date', { ascending: false })
      .limit(30)

    if (error) {
      console.error('Competitive insights query error:', error)
      return []
    }

    return data?.map((row: any) => ({
      competitor: row.competitor_name,
      insight_type: row.insight_type,
      insight_text: row.insight_description,
      confidence: row.confidence_score || 0.5,
      source: row.data_source || 'internal',
      relevance_to_query: this.calculateQueryRelevance(row.insight_description, query)
    })) || []
  }

  private calculateQueryRelevance(insightText: string, query: string): number {
    const queryTerms = query.toLowerCase().split(/\s+/)
    const insightLower = insightText.toLowerCase()
    
    let matches = 0
    queryTerms.forEach(term => {
      if (insightLower.includes(term)) {
        matches++
      }
    })
    
    return Math.min(matches / queryTerms.length, 1)
  }
}

// =============================================================================
// MAIN RETRIEVER AGENT
// =============================================================================

class RetrieverAgent {
  private searchEngine: HybridSearchEngine
  private kgTraverser: KnowledgeGraphTraverser
  private competitiveEngine: CompetitiveIntelligenceEngine

  constructor(supabaseUrl: string, supabaseKey: string, openaiKey: string) {
    this.searchEngine = new HybridSearchEngine(supabaseUrl, supabaseKey, openaiKey)
    
    const supabase = createClient(supabaseUrl, supabaseKey)
    this.kgTraverser = new KnowledgeGraphTraverser(supabase)
    this.competitiveEngine = new CompetitiveIntelligenceEngine(supabase)
  }

  static async process(request: RetrieverAgentRequest): Promise<RetrieverAgentResponse> {
    const startTime = Date.now()
    
    try {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
      const openaiKey = Deno.env.get('OPENAI_API_KEY')!
      
      const agent = new RetrieverAgent(supabaseUrl, supabaseKey, openaiKey)
      
      // 1. Perform hybrid search
      const retrievedChunks = await agent.searchEngine.search(
        request.query_context,
        request.retrieval_depth || 'medium',
        request.user_context.tenant_id,
        request.search_scope
      )
      
      // 2. Extract entities from retrieved chunks for KG traversal
      const entities = agent.extractEntitiesFromChunks(retrievedChunks)
      
      // 3. Find knowledge graph relationships
      const kgRelationships = await agent.kgTraverser.findRelationships(
        entities,
        request.user_context.tenant_id,
        request.retrieval_depth === 'deep' ? 3 : 2
      )
      
      // 4. Get competitive intelligence
      const competitiveContext = await agent.competitiveEngine.getCompetitiveContext(
        request.query_context,
        request.user_context.tenant_id,
        entities
      )
      
      return {
        retrieved_chunks: retrievedChunks,
        knowledge_graph_paths: kgRelationships,
        competitive_context: competitiveContext,
        confidence_scores: retrievedChunks.map(chunk => chunk.relevance_score),
        retrieval_metadata: {
          total_chunks_searched: retrievedChunks.length,
          hybrid_ranking_applied: true,
          vector_similarity_threshold: 0.7,
          processing_time_ms: Date.now() - startTime,
          search_strategy: request.retrieval_depth || 'medium'
        }
      }
      
    } catch (error) {
      return {
        retrieved_chunks: [],
        knowledge_graph_paths: [],
        competitive_context: [],
        confidence_scores: [],
        retrieval_metadata: {
          total_chunks_searched: 0,
          hybrid_ranking_applied: false,
          vector_similarity_threshold: 0.7,
          processing_time_ms: Date.now() - startTime,
          search_strategy: 'error'
        }
      }
    }
  }

  private extractEntitiesFromChunks(chunks: RAGChunk[]): string[] {
    const entities = new Set<string>()
    
    chunks.forEach(chunk => {
      // Extract entities from metadata
      if (chunk.metadata.entity_type) {
        entities.add(chunk.metadata.entity_type)
      }
      
      if (chunk.metadata.domain) {
        entities.add(chunk.metadata.domain)
      }
      
      // Simple entity extraction from text (brands, products, etc.)
      const text = chunk.chunk_text.toLowerCase()
      const knownEntities = [
        'Alaska', 'Nestle', 'Unilever', 'P&G', 'Colgate', 'Johnson',
        'Milk', 'Coffee', 'Shampoo', 'Soap', 'Toothpaste', 'Baby Care',
        'NCR', 'Cebu', 'Davao', 'Iloilo', 'Baguio'
      ]
      
      knownEntities.forEach(entity => {
        if (text.includes(entity.toLowerCase())) {
          entities.add(entity)
        }
      })
    })
    
    return Array.from(entities).slice(0, 10) // Limit to top 10 entities
  }
}

// =============================================================================
// EDGE FUNCTION HANDLER
// =============================================================================

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      }
    })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  try {
    const request: RetrieverAgentRequest = await req.json()
    
    // Validate required fields
    if (!request.query_context || !request.user_context?.tenant_id) {
      return new Response(JSON.stringify({ 
        error: 'Missing required fields: query_context, user_context.tenant_id' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }

    const response = await RetrieverAgent.process(request)
    
    return new Response(JSON.stringify(response), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      }
    })
    
  } catch (error) {
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      details: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})