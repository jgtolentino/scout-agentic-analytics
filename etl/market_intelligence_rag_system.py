#!/usr/bin/env python3
"""
Market Intelligence RAG System - Scout v7
Production-ready RAG chatbot with OpenAI integration

Features:
- Dual search strategy (semantic + keyword)
- Context-aware response generation
- Currency intelligence (PHP/USD)
- Real-time market insights
- Vector similarity search with pgvector
"""

import os
import json
import asyncio
import logging
from typing import List, Dict, Optional, Tuple
from datetime import datetime, timezone
import asyncpg
import openai
from openai import AsyncOpenAI
import numpy as np
from dataclasses import dataclass

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class SearchResult:
    """Search result from vector or keyword search"""
    content: str
    similarity_score: float
    source_table: str
    source_id: int
    metadata: Dict
    content_type: str

@dataclass
class RAGResponse:
    """RAG system response with context and sources"""
    response: str
    confidence: float
    sources: List[SearchResult]
    query_embedding: Optional[List[float]]
    processing_time_ms: int

class MarketIntelligenceRAG:
    """
    RAG-powered Market Intelligence System
    
    Provides AI-driven insights using semantic search, traditional queries,
    and context-aware response generation with OpenAI GPT models.
    """
    
    def __init__(self, db_url: str, openai_api_key: str):
        """Initialize RAG system with database and OpenAI connections"""
        self.db_url = db_url
        self.db_pool = None
        self.openai_client = AsyncOpenAI(api_key=openai_api_key)
        
        # Configuration
        self.embedding_model = "text-embedding-3-small"
        self.embedding_dimensions = 1536
        self.chat_model = "gpt-4"
        self.max_context_length = 4000
        self.similarity_threshold = 0.7
        
        # Currency conversion rate (PHP to USD)
        self.php_to_usd_rate = 58.0
        
        # Cache for embeddings to reduce API calls
        self.embedding_cache = {}
        
    async def initialize(self):
        """Initialize database connection pool"""
        try:
            self.db_pool = await asyncpg.create_pool(
                self.db_url,
                min_size=2,
                max_size=10,
                command_timeout=30
            )
            logger.info("Database connection pool initialized")
            
            # Test OpenAI connection
            await self._test_openai_connection()
            logger.info("OpenAI connection verified")
            
        except Exception as e:
            logger.error(f"Failed to initialize RAG system: {e}")
            raise

    async def _test_openai_connection(self):
        """Test OpenAI API connectivity"""
        try:
            response = await self.openai_client.embeddings.create(
                model=self.embedding_model,
                input="test connection"
            )
            logger.info(f"OpenAI connection successful, embedding dimensions: {len(response.data[0].embedding)}")
        except Exception as e:
            logger.error(f"OpenAI connection failed: {e}")
            raise

    async def get_embedding(self, text: str) -> List[float]:
        """
        Generate embedding for text using OpenAI
        
        Args:
            text: Input text to embed
            
        Returns:
            List of float values representing the embedding vector
        """
        # Check cache first
        cache_key = hash(text)
        if cache_key in self.embedding_cache:
            return self.embedding_cache[cache_key]
        
        try:
            # Clean and prepare text
            clean_text = text.strip().replace('\n', ' ')[:8000]  # Limit to model max
            
            response = await self.openai_client.embeddings.create(
                model=self.embedding_model,
                input=clean_text
            )
            
            embedding = response.data[0].embedding
            
            # Cache the result
            self.embedding_cache[cache_key] = embedding
            
            return embedding
            
        except Exception as e:
            logger.error(f"Failed to generate embedding: {e}")
            raise

    async def vector_search(self, query_embedding: List[float], limit: int = 5) -> List[SearchResult]:
        """
        Perform semantic vector search using pgvector
        
        Args:
            query_embedding: Query vector embedding
            limit: Maximum number of results to return
            
        Returns:
            List of SearchResult objects ordered by similarity
        """
        try:
            async with self.db_pool.acquire() as conn:
                # Convert embedding to PostgreSQL array format
                embedding_str = str(query_embedding).replace('[', '{').replace(']', '}')
                
                query = """
                SELECT 
                    content,
                    embedding <=> %s::vector as similarity_score,
                    source_table,
                    source_id,
                    metadata,
                    content_type,
                    created_at
                FROM knowledge.vector_embeddings
                WHERE embedding <=> %s::vector < %s
                ORDER BY embedding <=> %s::vector
                LIMIT %s;
                """
                
                rows = await conn.fetch(
                    query, 
                    embedding_str, embedding_str, 
                    1.0 - self.similarity_threshold,  # Convert similarity to distance
                    embedding_str,
                    limit
                )
                
                results = []
                for row in rows:
                    results.append(SearchResult(
                        content=row['content'],
                        similarity_score=1.0 - row['similarity_score'],  # Convert back to similarity
                        source_table=row['source_table'],
                        source_id=row['source_id'],
                        metadata=row['metadata'] or {},
                        content_type=row['content_type']
                    ))
                
                logger.info(f"Vector search returned {len(results)} results")
                return results
                
        except Exception as e:
            logger.error(f"Vector search failed: {e}")
            return []

    async def keyword_search(self, query: str, limit: int = 5) -> List[SearchResult]:
        """
        Perform traditional keyword search for fallback and enhancement
        
        Args:
            query: Search query string
            limit: Maximum number of results to return
            
        Returns:
            List of SearchResult objects from keyword matching
        """
        try:
            async with self.db_pool.acquire() as conn:
                # Multi-table keyword search across relevant tables
                searches = [
                    # Brand intelligence search
                    """
                    SELECT 
                        brand_name || ': ' || COALESCE(description, '') as content,
                        0.8 as similarity_score,
                        'metadata.enhanced_brand_master' as source_table,
                        brand_id as source_id,
                        jsonb_build_object(
                            'brand_name', brand_name,
                            'is_active', is_active,
                            'category', category
                        ) as metadata,
                        'brand' as content_type
                    FROM metadata.enhanced_brand_master
                    WHERE brand_name ILIKE %s OR description ILIKE %s
                    LIMIT %s
                    """,
                    
                    # Market intelligence search
                    """
                    SELECT 
                        title || ': ' || content as content,
                        0.9 as similarity_score,
                        'metadata.market_intelligence' as source_table,
                        insight_id as source_id,
                        jsonb_build_object(
                            'category', category,
                            'confidence_score', confidence_score
                        ) as metadata,
                        'market_insight' as content_type
                    FROM metadata.market_intelligence
                    WHERE title ILIKE %s OR content ILIKE %s
                    LIMIT %s
                    """
                ]
                
                all_results = []
                search_pattern = f"%{query}%"
                
                for search_query in searches:
                    rows = await conn.fetch(
                        search_query,
                        search_pattern, search_pattern, limit
                    )
                    
                    for row in rows:
                        all_results.append(SearchResult(
                            content=row['content'],
                            similarity_score=row['similarity_score'],
                            source_table=row['source_table'],
                            source_id=row['source_id'],
                            metadata=row['metadata'] or {},
                            content_type=row['content_type']
                        ))
                
                # Sort by similarity score and limit results
                all_results.sort(key=lambda x: x.similarity_score, reverse=True)
                
                logger.info(f"Keyword search returned {len(all_results[:limit])} results")
                return all_results[:limit]
                
        except Exception as e:
            logger.error(f"Keyword search failed: {e}")
            return []

    async def get_market_context(self, query: str) -> Dict:
        """
        Get relevant market context for currency, geography, and time period
        
        Args:
            query: User query to analyze for context
            
        Returns:
            Dictionary with market context information
        """
        try:
            async with self.db_pool.acquire() as conn:
                # Get recent market metrics
                market_query = """
                SELECT 
                    COUNT(DISTINCT store_id) as active_stores,
                    COUNT(*) as total_transactions,
                    AVG(total_price_peso) as avg_transaction_value_php,
                    COUNT(DISTINCT brand_name) as active_brands,
                    MAX(transaction_date) as latest_data_date
                FROM silver.transactions_cleaned
                WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days';
                """
                
                market_data = await conn.fetchrow(market_query)
                
                # Currency conversion
                avg_usd = round(market_data['avg_transaction_value_php'] / self.php_to_usd_rate, 2) if market_data['avg_transaction_value_php'] else 0
                
                context = {
                    'market_summary': {
                        'active_stores': market_data['active_stores'],
                        'monthly_transactions': market_data['total_transactions'],
                        'avg_transaction_php': round(market_data['avg_transaction_value_php'] or 0, 2),
                        'avg_transaction_usd': avg_usd,
                        'active_brands': market_data['active_brands'],
                        'data_freshness': market_data['latest_data_date'].isoformat() if market_data['latest_data_date'] else None
                    },
                    'currency_rates': {
                        'php_to_usd': 1 / self.php_to_usd_rate,
                        'usd_to_php': self.php_to_usd_rate
                    }
                }
                
                return context
                
        except Exception as e:
            logger.error(f"Failed to get market context: {e}")
            return {}

    def assemble_context(self, semantic_results: List[SearchResult], 
                        keyword_results: List[SearchResult],
                        market_context: Dict) -> str:
        """
        Assemble search results and context into coherent context for AI
        
        Args:
            semantic_results: Results from vector search
            keyword_results: Results from keyword search
            market_context: Market context information
            
        Returns:
            Formatted context string for AI response generation
        """
        context_parts = []
        
        # Add market context
        if market_context and 'market_summary' in market_context:
            ms = market_context['market_summary']
            context_parts.append(f"""
MARKET OVERVIEW:
- Active Stores: {ms.get('active_stores', 'N/A')}
- Monthly Transactions: {ms.get('monthly_transactions', 'N/A')}
- Average Transaction: ₱{ms.get('avg_transaction_php', 0)} (${ms.get('avg_transaction_usd', 0)} USD)
- Active Brands: {ms.get('active_brands', 'N/A')}
- Data as of: {ms.get('data_freshness', 'N/A')}
            """.strip())
        
        # Add semantic search results
        if semantic_results:
            context_parts.append("\nRELEVANT INSIGHTS (Semantic Search):")
            for i, result in enumerate(semantic_results[:3], 1):
                context_parts.append(f"{i}. [{result.content_type}] {result.content}")
        
        # Add keyword search results
        if keyword_results:
            context_parts.append("\nADDITIONAL CONTEXT (Keyword Search):")
            for i, result in enumerate(keyword_results[:2], 1):
                context_parts.append(f"{i}. [{result.content_type}] {result.content}")
        
        return "\n".join(context_parts)

    async def generate_response(self, question: str, context: str, 
                              market_context: Dict) -> str:
        """
        Generate AI response using OpenAI GPT with market intelligence context
        
        Args:
            question: User's question
            context: Assembled context from search results
            market_context: Market context information
            
        Returns:
            Generated AI response string
        """
        try:
            system_prompt = f"""You are Scout, TBWA's AI Market Intelligence Assistant specializing in Philippine retail market analysis.

CAPABILITIES:
- Market trend analysis and competitive intelligence
- Brand performance insights and recommendations  
- Currency-aware pricing analysis (PHP primary, USD equivalent at ₱58:$1)
- Data-driven business intelligence from 175,344+ transaction records

RESPONSE GUIDELINES:
- Provide specific, actionable insights backed by data
- Include both PHP and USD values for pricing discussions
- Reference the specific data sources and timeframes
- Maintain professional, analytical tone
- Highlight key trends and competitive dynamics

CURRENT MARKET CONTEXT:
Exchange Rate: ₱58 = $1 USD (fixed rate for analysis consistency)
Data Coverage: {market_context.get('market_summary', {}).get('monthly_transactions', 'N/A')} recent transactions
Active Market: {market_context.get('market_summary', {}).get('active_stores', 'N/A')} stores across {market_context.get('market_summary', {}).get('active_brands', 'N/A')} brands
"""

            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"""
Question: {question}

Available Context:
{context}

Please provide a comprehensive response based on the available data and context.
"""}
            ]
            
            response = await self.openai_client.chat.completions.create(
                model=self.chat_model,
                messages=messages,
                temperature=0.3,  # Lower temperature for more factual responses
                max_tokens=1500
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.error(f"Failed to generate AI response: {e}")
            return "I'm sorry, I encountered an issue generating a response. Please try rephrasing your question."

    async def query(self, question: str, context_limit: int = 5) -> RAGResponse:
        """
        Main RAG query interface - combines semantic search, keyword search, and AI generation
        
        Args:
            question: User's question about market intelligence
            context_limit: Maximum number of context results per search method
            
        Returns:
            RAGResponse with generated answer, confidence, and source information
        """
        start_time = datetime.now()
        
        try:
            logger.info(f"Processing RAG query: {question[:100]}...")
            
            # Generate query embedding
            query_embedding = await self.get_embedding(question)
            
            # Run searches in parallel
            semantic_task = self.vector_search(query_embedding, context_limit)
            keyword_task = self.keyword_search(question, context_limit)
            context_task = self.get_market_context(question)
            
            semantic_results, keyword_results, market_context = await asyncio.gather(
                semantic_task, keyword_task, context_task
            )
            
            # Assemble context
            context = self.assemble_context(semantic_results, keyword_results, market_context)
            
            # Generate AI response
            ai_response = await self.generate_response(question, context, market_context)
            
            # Calculate confidence based on search result quality
            confidence = self._calculate_confidence(semantic_results, keyword_results)
            
            # Combine all sources
            all_sources = semantic_results + keyword_results
            
            processing_time = int((datetime.now() - start_time).total_seconds() * 1000)
            
            logger.info(f"RAG query completed in {processing_time}ms with confidence {confidence}")
            
            return RAGResponse(
                response=ai_response,
                confidence=confidence,
                sources=all_sources[:10],  # Limit total sources
                query_embedding=query_embedding,
                processing_time_ms=processing_time
            )
            
        except Exception as e:
            logger.error(f"RAG query failed: {e}")
            processing_time = int((datetime.now() - start_time).total_seconds() * 1000)
            
            return RAGResponse(
                response="I apologize, but I'm unable to process your query at the moment. Please try again later.",
                confidence=0.0,
                sources=[],
                query_embedding=None,
                processing_time_ms=processing_time
            )

    def _calculate_confidence(self, semantic_results: List[SearchResult], 
                            keyword_results: List[SearchResult]) -> float:
        """Calculate confidence score based on search result quality"""
        if not semantic_results and not keyword_results:
            return 0.0
        
        # Weight semantic results more heavily
        semantic_score = sum(r.similarity_score for r in semantic_results) / len(semantic_results) if semantic_results else 0
        keyword_score = sum(r.similarity_score for r in keyword_results) / len(keyword_results) if keyword_results else 0
        
        # Combined confidence with semantic weighting
        confidence = (semantic_score * 0.7) + (keyword_score * 0.3)
        return min(confidence, 1.0)

    async def close(self):
        """Clean up resources"""
        if self.db_pool:
            await self.db_pool.close()
            logger.info("Database connection pool closed")

# Example usage and testing
async def main():
    """Example usage of the RAG system"""
    
    # Initialize from environment variables
    db_url = os.getenv('DATABASE_URL')
    openai_key = os.getenv('OPENAI_API_KEY')
    
    if not db_url or not openai_key:
        logger.error("DATABASE_URL and OPENAI_API_KEY environment variables required")
        return
    
    # Create and initialize RAG system
    rag = MarketIntelligenceRAG(db_url, openai_key)
    await rag.initialize()
    
    try:
        # Example queries
        test_queries = [
            "What are the top performing brands in the Philippines?",
            "Show me pricing trends for beverages in PHP and USD",
            "Which stores have the highest transaction volumes?",
            "What market insights are available for competitive analysis?"
        ]
        
        for query in test_queries:
            print(f"\n{'='*60}")
            print(f"Query: {query}")
            print('='*60)
            
            response = await rag.query(query, context_limit=3)
            
            print(f"Response ({response.confidence:.2f} confidence):")
            print(response.response)
            print(f"\nProcessing time: {response.processing_time_ms}ms")
            print(f"Sources used: {len(response.sources)}")
            
            for i, source in enumerate(response.sources[:2], 1):
                print(f"  {i}. [{source.content_type}] {source.content[:100]}...")
    
    finally:
        await rag.close()

if __name__ == "__main__":
    asyncio.run(main())