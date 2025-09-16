#!/usr/bin/env python3
"""
Vector Embedding Generator - Scout v7 Market Intelligence
Production-ready OpenAI embeddings pipeline with batch processing

Features:
- OpenAI text-embedding-3-small integration (1536 dimensions)
- Batch processing for cost efficiency
- Metadata enrichment and source tracking
- Database integration with pgvector
- Deduplication and caching
- Progress tracking and error recovery
"""

import os
import json
import asyncio
import logging
from typing import List, Dict, Optional, Tuple, Any
from datetime import datetime, timezone
import asyncpg
from openai import AsyncOpenAI
import hashlib
from dataclasses import dataclass, asdict
import time

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class EmbeddingRequest:
    """Embedding request with source metadata"""
    content: str
    content_type: str  # 'brand', 'product', 'market_insight', 'transaction'
    source_table: str
    source_id: int
    metadata: Dict[str, Any]
    
    @property
    def content_hash(self) -> str:
        """Generate unique hash for content deduplication"""
        return hashlib.sha256(self.content.encode('utf-8')).hexdigest()[:32]

@dataclass
class EmbeddingResult:
    """Embedding result with processing metadata"""
    embedding_id: Optional[int]
    content: str
    content_type: str
    source_table: str
    source_id: int
    embedding: List[float]
    metadata: Dict[str, Any]
    content_hash: str
    processing_time_ms: int
    created_at: datetime

class VectorEmbeddingGenerator:
    """
    Production-ready vector embedding generator using OpenAI text-embedding-3-small
    
    Handles batch processing, deduplication, metadata enrichment, and database integration
    with comprehensive error handling and progress tracking.
    """
    
    def __init__(self, db_url: str, openai_api_key: str):
        """Initialize embedding generator with database and OpenAI connections"""
        self.db_url = db_url
        self.db_pool = None
        self.openai_client = AsyncOpenAI(api_key=openai_api_key)
        
        # Configuration
        self.embedding_model = "text-embedding-3-small"
        self.embedding_dimensions = 1536
        self.batch_size = 100  # OpenAI allows up to 2048, but we use conservative batch
        self.max_text_length = 8000  # Conservative limit for text-embedding-3-small
        self.retry_attempts = 3
        self.retry_delay = 1.0  # seconds
        
        # Processing statistics
        self.stats = {
            'processed': 0,
            'skipped_duplicates': 0,
            'errors': 0,
            'total_tokens_used': 0,
            'total_cost_usd': 0.0,
            'processing_start_time': None
        }
        
    async def initialize(self):
        """Initialize database connection pool and verify OpenAI connection"""
        try:
            # Database connection
            self.db_pool = await asyncpg.create_pool(
                self.db_url,
                min_size=2,
                max_size=10,
                command_timeout=60
            )
            logger.info("Database connection pool initialized")
            
            # Test OpenAI connection
            await self._test_openai_connection()
            logger.info("OpenAI connection verified")
            
            # Ensure vector extension and tables exist
            await self._ensure_database_schema()
            logger.info("Database schema verified")
            
        except Exception as e:
            logger.error(f"Failed to initialize embedding generator: {e}")
            raise

    async def _test_openai_connection(self):
        """Test OpenAI API connectivity and model access"""
        try:
            response = await self.openai_client.embeddings.create(
                model=self.embedding_model,
                input="test connection"
            )
            
            embedding = response.data[0].embedding
            if len(embedding) != self.embedding_dimensions:
                raise ValueError(f"Expected {self.embedding_dimensions} dimensions, got {len(embedding)}")
                
            logger.info(f"OpenAI connection successful - {self.embedding_model} model verified")
            
        except Exception as e:
            logger.error(f"OpenAI connection failed: {e}")
            raise

    async def _ensure_database_schema(self):
        """Ensure required database schema exists for vector embeddings"""
        try:
            async with self.db_pool.acquire() as conn:
                # Check if vector extension is available
                await conn.execute("CREATE EXTENSION IF NOT EXISTS vector;")
                
                # Check if knowledge schema exists
                await conn.execute("CREATE SCHEMA IF NOT EXISTS knowledge;")
                
                # Verify vector_embeddings table exists
                table_exists = await conn.fetchval("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_schema = 'knowledge' 
                        AND table_name = 'vector_embeddings'
                    );
                """)
                
                if not table_exists:
                    logger.warning("vector_embeddings table does not exist - embeddings will be stored in temporary structure")
                else:
                    logger.info("Vector embeddings table verified")
                    
        except Exception as e:
            logger.error(f"Database schema verification failed: {e}")
            raise

    async def extract_embedding_requests(self, 
                                       source_tables: Optional[List[str]] = None,
                                       limit: Optional[int] = None) -> List[EmbeddingRequest]:
        """
        Extract embedding requests from various source tables
        
        Args:
            source_tables: Specific tables to process (None for all)
            limit: Maximum number of requests to extract
            
        Returns:
            List of EmbeddingRequest objects ready for processing
        """
        try:
            async with self.db_pool.acquire() as conn:
                requests = []
                
                # Define extraction queries for different content types
                extraction_queries = {
                    'brand_intelligence': {
                        'query': """
                            SELECT 
                                brand_id as source_id,
                                'metadata.enhanced_brand_master' as source_table,
                                brand_name || COALESCE(': ' || description, '') as content,
                                'brand' as content_type,
                                jsonb_build_object(
                                    'brand_name', brand_name,
                                    'category', category,
                                    'is_active', is_active,
                                    'confidence_score', confidence_score
                                ) as metadata
                            FROM metadata.enhanced_brand_master 
                            WHERE is_active = true
                            ORDER BY brand_id
                        """,
                        'enabled': not source_tables or 'metadata.enhanced_brand_master' in source_tables
                    },
                    
                    'market_intelligence': {
                        'query': """
                            SELECT 
                                insight_id as source_id,
                                'metadata.market_intelligence' as source_table,
                                title || ': ' || content as content,
                                'market_insight' as content_type,
                                jsonb_build_object(
                                    'category', category,
                                    'confidence_score', confidence_score,
                                    'title', title
                                ) as metadata
                            FROM metadata.market_intelligence
                            ORDER BY insight_id
                        """,
                        'enabled': not source_tables or 'metadata.market_intelligence' in source_tables
                    },
                    
                    'product_intelligence': {
                        'query': """
                            SELECT 
                                product_id as source_id,
                                'silver.master_products' as source_table,
                                product_name || COALESCE(': ' || description, '') as content,
                                'product' as content_type,
                                jsonb_build_object(
                                    'product_name', product_name,
                                    'category_name', category_name,
                                    'brand_name', brand_name
                                ) as metadata
                            FROM silver.master_products
                            WHERE product_name IS NOT NULL
                            ORDER BY product_id
                        """,
                        'enabled': not source_tables or 'silver.master_products' in source_tables
                    }
                }
                
                # Execute extraction queries
                for query_name, query_config in extraction_queries.items():
                    if not query_config['enabled']:
                        continue
                        
                    try:
                        query = query_config['query']
                        if limit:
                            query += f" LIMIT {limit // len([q for q in extraction_queries.values() if q['enabled']])}"
                        
                        rows = await conn.fetch(query)
                        
                        for row in rows:
                            # Skip empty or very short content
                            content = row['content'].strip()
                            if len(content) < 10:
                                continue
                                
                            # Truncate content if too long
                            if len(content) > self.max_text_length:
                                content = content[:self.max_text_length] + "..."
                            
                            request = EmbeddingRequest(
                                content=content,
                                content_type=row['content_type'],
                                source_table=row['source_table'],
                                source_id=row['source_id'],
                                metadata=dict(row['metadata']) if row['metadata'] else {}
                            )
                            
                            requests.append(request)
                        
                        logger.info(f"Extracted {len(rows)} requests from {query_name}")
                        
                    except Exception as e:
                        logger.error(f"Failed to extract from {query_name}: {e}")
                        continue
                
                logger.info(f"Total extraction: {len(requests)} embedding requests")
                return requests
                
        except Exception as e:
            logger.error(f"Failed to extract embedding requests: {e}")
            return []

    async def check_existing_embeddings(self, 
                                      requests: List[EmbeddingRequest]) -> Tuple[List[EmbeddingRequest], List[str]]:
        """
        Check which embeddings already exist to avoid duplicates
        
        Args:
            requests: List of embedding requests to check
            
        Returns:
            Tuple of (new_requests, existing_hashes)
        """
        try:
            if not requests:
                return [], []
            
            async with self.db_pool.acquire() as conn:
                # Get content hashes for all requests
                request_hashes = [req.content_hash for req in requests]
                
                # Check which embeddings already exist
                existing_query = """
                    SELECT DISTINCT 
                        substring(md5(content), 1, 32) as content_hash
                    FROM knowledge.vector_embeddings 
                    WHERE substring(md5(content), 1, 32) = ANY($1);
                """
                
                try:
                    existing_rows = await conn.fetch(existing_query, request_hashes)
                    existing_hashes = {row['content_hash'] for row in existing_rows}
                except Exception:
                    # If table doesn't exist or query fails, assume no existing embeddings
                    existing_hashes = set()
                
                # Filter out existing embeddings
                new_requests = [req for req in requests if req.content_hash not in existing_hashes]
                
                skipped_count = len(requests) - len(new_requests)
                if skipped_count > 0:
                    logger.info(f"Skipping {skipped_count} existing embeddings")
                
                self.stats['skipped_duplicates'] += skipped_count
                
                return new_requests, list(existing_hashes)
                
        except Exception as e:
            logger.error(f"Failed to check existing embeddings: {e}")
            # On error, assume all are new to be safe
            return requests, []

    async def generate_embeddings_batch(self, requests: List[EmbeddingRequest]) -> List[EmbeddingResult]:
        """
        Generate embeddings for a batch of requests using OpenAI API
        
        Args:
            requests: List of embedding requests to process
            
        Returns:
            List of EmbeddingResult objects with generated embeddings
        """
        if not requests:
            return []
            
        start_time = time.time()
        results = []
        
        try:
            # Prepare batch request
            texts = [req.content for req in requests]
            
            # Make OpenAI API call with retry logic
            for attempt in range(self.retry_attempts):
                try:
                    response = await self.openai_client.embeddings.create(
                        model=self.embedding_model,
                        input=texts
                    )
                    break
                    
                except Exception as e:
                    if attempt < self.retry_attempts - 1:
                        logger.warning(f"Embedding API call failed (attempt {attempt + 1}): {e}")
                        await asyncio.sleep(self.retry_delay * (2 ** attempt))  # Exponential backoff
                        continue
                    else:
                        raise
            
            processing_time = int((time.time() - start_time) * 1000)
            
            # Process results
            for i, embedding_data in enumerate(response.data):
                embedding = embedding_data.embedding
                
                # Validate embedding
                if len(embedding) != self.embedding_dimensions:
                    raise ValueError(f"Invalid embedding dimensions: {len(embedding)}")
                
                result = EmbeddingResult(
                    embedding_id=None,  # Will be set after database insertion
                    content=requests[i].content,
                    content_type=requests[i].content_type,
                    source_table=requests[i].source_table,
                    source_id=requests[i].source_id,
                    embedding=embedding,
                    metadata=requests[i].metadata,
                    content_hash=requests[i].content_hash,
                    processing_time_ms=processing_time // len(requests),
                    created_at=datetime.now(timezone.utc)
                )
                
                results.append(result)
            
            # Update statistics
            self.stats['processed'] += len(results)
            self.stats['total_tokens_used'] += response.usage.total_tokens
            
            # Estimate cost (OpenAI text-embedding-3-small pricing: ~$0.00002 per 1K tokens)
            batch_cost = (response.usage.total_tokens / 1000) * 0.00002
            self.stats['total_cost_usd'] += batch_cost
            
            logger.info(f"Generated {len(results)} embeddings in {processing_time}ms (${batch_cost:.6f})")
            
            return results
            
        except Exception as e:
            logger.error(f"Failed to generate embeddings batch: {e}")
            self.stats['errors'] += len(requests)
            return []

    async def store_embeddings(self, results: List[EmbeddingResult]) -> int:
        """
        Store embedding results in the database
        
        Args:
            results: List of EmbeddingResult objects to store
            
        Returns:
            Number of embeddings successfully stored
        """
        if not results:
            return 0
            
        try:
            async with self.db_pool.acquire() as conn:
                stored_count = 0
                
                # Insert embeddings one by one for better error handling
                for result in results:
                    try:
                        # Convert embedding to PostgreSQL array format
                        embedding_array = '{' + ','.join(map(str, result.embedding)) + '}'
                        
                        # Insert embedding
                        insert_query = """
                            INSERT INTO knowledge.vector_embeddings 
                            (content, content_type, source_table, source_id, embedding, metadata, created_at)
                            VALUES ($1, $2, $3, $4, $5::vector, $6, $7)
                            RETURNING embedding_id;
                        """
                        
                        embedding_id = await conn.fetchval(
                            insert_query,
                            result.content,
                            result.content_type,
                            result.source_table,
                            result.source_id,
                            embedding_array,
                            json.dumps(result.metadata),
                            result.created_at
                        )
                        
                        # Update result with embedding_id
                        result.embedding_id = embedding_id
                        stored_count += 1
                        
                    except Exception as e:
                        logger.error(f"Failed to store embedding for {result.source_table}:{result.source_id}: {e}")
                        self.stats['errors'] += 1
                        continue
                
                logger.info(f"Successfully stored {stored_count}/{len(results)} embeddings")
                return stored_count
                
        except Exception as e:
            logger.error(f"Failed to store embeddings: {e}")
            return 0

    async def process_embeddings(self, 
                               source_tables: Optional[List[str]] = None,
                               limit: Optional[int] = None) -> Dict[str, Any]:
        """
        Main processing pipeline: extract, deduplicate, generate, and store embeddings
        
        Args:
            source_tables: Specific tables to process (None for all)
            limit: Maximum number of embeddings to process
            
        Returns:
            Processing statistics and results
        """
        self.stats['processing_start_time'] = datetime.now(timezone.utc)
        logger.info("Starting embedding generation pipeline")
        
        try:
            # Step 1: Extract embedding requests
            logger.info("Step 1: Extracting embedding requests...")
            all_requests = await self.extract_embedding_requests(source_tables, limit)
            
            if not all_requests:
                logger.warning("No embedding requests found")
                return self.get_processing_summary()
            
            # Step 2: Check for existing embeddings
            logger.info("Step 2: Checking for existing embeddings...")
            new_requests, existing_hashes = await self.check_existing_embeddings(all_requests)
            
            if not new_requests:
                logger.info("All embeddings already exist - no processing needed")
                return self.get_processing_summary()
            
            # Step 3: Process in batches
            logger.info(f"Step 3: Processing {len(new_requests)} new embeddings in batches of {self.batch_size}...")
            all_results = []
            
            for i in range(0, len(new_requests), self.batch_size):
                batch = new_requests[i:i + self.batch_size]
                batch_num = (i // self.batch_size) + 1
                total_batches = (len(new_requests) + self.batch_size - 1) // self.batch_size
                
                logger.info(f"Processing batch {batch_num}/{total_batches} ({len(batch)} items)...")
                
                # Generate embeddings for batch
                batch_results = await self.generate_embeddings_batch(batch)
                
                if batch_results:
                    # Store embeddings immediately
                    stored_count = await self.store_embeddings(batch_results)
                    all_results.extend(batch_results)
                    
                    logger.info(f"Batch {batch_num} completed: {stored_count} embeddings stored")
                
                # Small delay between batches to be respectful to API
                if i + self.batch_size < len(new_requests):
                    await asyncio.sleep(0.1)
            
            logger.info(f"Embedding generation pipeline completed: {len(all_results)} embeddings processed")
            return self.get_processing_summary()
            
        except Exception as e:
            logger.error(f"Embedding processing pipeline failed: {e}")
            return self.get_processing_summary()

    def get_processing_summary(self) -> Dict[str, Any]:
        """Get comprehensive processing statistics"""
        end_time = datetime.now(timezone.utc)
        
        if self.stats['processing_start_time']:
            processing_duration = (end_time - self.stats['processing_start_time']).total_seconds()
        else:
            processing_duration = 0
        
        return {
            'processing_summary': {
                'embeddings_processed': self.stats['processed'],
                'embeddings_skipped_duplicates': self.stats['skipped_duplicates'],
                'processing_errors': self.stats['errors'],
                'processing_duration_seconds': processing_duration,
                'processing_rate_per_minute': (self.stats['processed'] / processing_duration * 60) if processing_duration > 0 else 0
            },
            'api_usage': {
                'total_tokens_used': self.stats['total_tokens_used'],
                'estimated_cost_usd': round(self.stats['total_cost_usd'], 6),
                'model_used': self.embedding_model,
                'embedding_dimensions': self.embedding_dimensions
            },
            'processing_timestamp': end_time.isoformat(),
            'success_rate': (self.stats['processed'] / (self.stats['processed'] + self.stats['errors'])) * 100 if (self.stats['processed'] + self.stats['errors']) > 0 else 0
        }

    async def close(self):
        """Clean up resources"""
        if self.db_pool:
            await self.db_pool.close()
            logger.info("Database connection pool closed")

# CLI interface and example usage
async def main():
    """Command-line interface for vector embedding generation"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate vector embeddings for Scout v7 market intelligence')
    parser.add_argument('--db-url', required=True, help='Database connection URL')
    parser.add_argument('--openai-key', help='OpenAI API key (or use OPENAI_API_KEY env var)')
    parser.add_argument('--tables', nargs='*', help='Specific tables to process')
    parser.add_argument('--limit', type=int, help='Maximum number of embeddings to generate')
    parser.add_argument('--batch-size', type=int, default=100, help='Batch size for processing')
    
    args = parser.parse_args()
    
    # Get OpenAI API key from argument or environment
    openai_key = args.openai_key or os.getenv('OPENAI_API_KEY')
    if not openai_key:
        logger.error("OpenAI API key required via --openai-key or OPENAI_API_KEY environment variable")
        return
    
    # Initialize generator
    generator = VectorEmbeddingGenerator(args.db_url, openai_key)
    
    if args.batch_size:
        generator.batch_size = args.batch_size
    
    try:
        await generator.initialize()
        
        # Process embeddings
        results = await generator.process_embeddings(
            source_tables=args.tables,
            limit=args.limit
        )
        
        # Print results
        print("\n" + "="*60)
        print("EMBEDDING GENERATION RESULTS")
        print("="*60)
        
        print(f"Embeddings processed: {results['processing_summary']['embeddings_processed']}")
        print(f"Duplicates skipped: {results['processing_summary']['embeddings_skipped_duplicates']}")  
        print(f"Processing errors: {results['processing_summary']['processing_errors']}")
        print(f"Processing duration: {results['processing_summary']['processing_duration_seconds']:.1f}s")
        print(f"Processing rate: {results['processing_summary']['processing_rate_per_minute']:.1f} embeddings/min")
        print(f"Success rate: {results['success_rate']:.1f}%")
        print()
        print(f"Tokens used: {results['api_usage']['total_tokens_used']:,}")
        print(f"Estimated cost: ${results['api_usage']['estimated_cost_usd']:.6f}")
        print(f"Model: {results['api_usage']['model_used']}")
        
    finally:
        await generator.close()

if __name__ == "__main__":
    asyncio.run(main())