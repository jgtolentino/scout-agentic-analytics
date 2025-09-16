"""
Bucket to Bronze Processor Workflow
Processes Scout Edge JSON files from Supabase bucket storage to Bronze layer
Validates against schema from local reference files
"""

import asyncio
import logging
import json
import hashlib
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, asdict
from decimal import Decimal
import uuid

from temporalio import workflow, activity
from temporalio.common import RetryPolicy
import psycopg2
from psycopg2.extras import RealDictCursor, Json
from supabase import create_client, Client

from ..contracts.scout_contracts import ScoutTransactionSchema, ProcessingResult
from ..monitoring.openlineage_events import emit_lineage_event

logger = logging.getLogger(__name__)

@dataclass
class BucketToBronzeConfig:
    """Configuration for bucket to Bronze processing"""
    bucket_name: str = "scout-ingest"
    bucket_path: str = "edge-transactions/"
    batch_size: int = 100
    max_parallel_workers: int = 5
    validation_enabled: bool = True
    deduplication_enabled: bool = True
    quality_threshold: float = 0.7
    
    # Database configuration
    postgres_url: str = ""
    supabase_url: str = ""
    supabase_key: str = ""
    
    # Processing options
    auto_retry_failed: bool = True
    max_retry_attempts: int = 3

@dataclass
class BucketFileRecord:
    """Bucket file record for processing"""
    file_id: str
    bucket_name: str
    file_path: str
    file_name: str
    file_size: int
    source_type: str
    source_id: str
    file_hash: str
    uploaded_at: datetime
    processing_status: str = "pending"

@dataclass
class ProcessingStats:
    """Processing statistics"""
    total_files: int = 0
    processed_files: int = 0
    successful_files: int = 0
    failed_files: int = 0
    skipped_files: int = 0
    duplicate_files: int = 0
    invalid_files: int = 0
    total_transactions: int = 0
    unique_devices: int = 0
    avg_quality_score: float = 0.0

@workflow.defn
class BucketToBronzeWorkflow:
    """Temporal workflow for processing bucket files to Bronze layer"""
    
    @workflow.run
    async def run(self, config: BucketToBronzeConfig) -> ProcessingStats:
        """Execute the complete bucket to Bronze processing workflow"""
        
        logger.info(f"Starting bucket to Bronze processing for {config.bucket_name}/{config.bucket_path}")
        
        # Create processing job record
        job_id = await workflow.execute_activity(
            create_processing_job,
            config,
            start_to_close_timeout=timedelta(minutes=5),
            retry_policy=RetryPolicy(maximum_attempts=3)
        )
        
        try:
            # Step 1: Discover pending files in bucket
            workflow.logger.info("Phase 1: Discovering pending files in bucket")
            pending_files = await workflow.execute_activity(
                discover_pending_files,
                {"job_id": job_id, "config": config},
                start_to_close_timeout=timedelta(minutes=10),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
            
            if not pending_files:
                workflow.logger.info("No pending files found for processing")
                return ProcessingStats()
            
            # Step 2: Process files in batches
            workflow.logger.info(f"Phase 2: Processing {len(pending_files)} files")
            processing_results = []
            
            # Process files in batches
            for i in range(0, len(pending_files), config.batch_size):
                batch = pending_files[i:i + config.batch_size]
                batch_num = (i // config.batch_size) + 1
                total_batches = (len(pending_files) + config.batch_size - 1) // config.batch_size
                
                workflow.logger.info(f"Processing batch {batch_num}/{total_batches} ({len(batch)} files)")
                
                batch_result = await workflow.execute_activity(
                    process_files_batch,
                    {"job_id": job_id, "files": batch, "config": config,
                     "batch_num": batch_num, "total_batches": total_batches},
                    start_to_close_timeout=timedelta(minutes=45),
                    retry_policy=RetryPolicy(maximum_attempts=2)
                )
                
                processing_results.extend(batch_result)
                
                # Brief pause between batches
                await asyncio.sleep(0.5)
            
            # Step 3: Update file statuses and generate final stats
            workflow.logger.info("Phase 3: Finalizing processing results")
            final_stats = await workflow.execute_activity(
                finalize_processing,
                {"job_id": job_id, "results": processing_results, "config": config},
                start_to_close_timeout=timedelta(minutes=15),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
            
            logger.info(f"Bucket to Bronze processing completed. Job ID: {job_id}")
            return final_stats
            
        except Exception as e:
            # Mark job as failed
            await workflow.execute_activity(
                mark_processing_job_failed,
                {"job_id": job_id, "error": str(e)},
                start_to_close_timeout=timedelta(minutes=5),
                retry_policy=RetryPolicy(maximum_attempts=1)
            )
            raise

# Activity implementations

@activity.defn
async def create_processing_job(config: BucketToBronzeConfig) -> str:
    """Create a new processing job record"""
    
    job_id = str(uuid.uuid4())
    
    try:
        conn = psycopg2.connect(config.postgres_url)
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO metadata.scout_sync_jobs (
                    id, job_name, job_type, source_config, status,
                    started_at, progress_percentage, current_phase
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                job_id,
                f"bucket_to_bronze_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                "bucket_process",
                json.dumps(asdict(config)),
                "running",
                datetime.now(),
                0.0,
                "initializing"
            ))
            conn.commit()
        
        logger.info(f"Created processing job {job_id}")
        return job_id
        
    except Exception as e:
        logger.error(f"Failed to create processing job: {e}")
        raise

@activity.defn
async def discover_pending_files(params: Dict) -> List[BucketFileRecord]:
    """Discover pending files in bucket for processing"""
    
    job_id = params["job_id"]
    config = BucketToBronzeConfig(**params["config"])
    
    try:
        await update_processing_progress(job_id, 10.0, "discovering_files", config.postgres_url)
        
        conn = psycopg2.connect(config.postgres_url)
        files = []
        
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Get files that need processing
            cur.execute("""
                SELECT 
                    id as file_id, bucket_name, file_path, file_name, 
                    file_size, source_type, source_id, file_hash,
                    uploaded_at, processing_status
                FROM metadata.scout_bucket_files
                WHERE bucket_name = %s 
                    AND file_path LIKE %s
                    AND processing_status IN ('pending', 'failed')
                    AND (retry_count < %s OR retry_count IS NULL)
                ORDER BY uploaded_at ASC
                LIMIT 10000
            """, (
                config.bucket_name,
                f"{config.bucket_path}%",
                config.max_retry_attempts
            ))
            
            for row in cur.fetchall():
                file_record = BucketFileRecord(
                    file_id=row['file_id'],
                    bucket_name=row['bucket_name'],
                    file_path=row['file_path'],
                    file_name=row['file_name'],
                    file_size=row['file_size'],
                    source_type=row['source_type'],
                    source_id=row['source_id'],
                    file_hash=row['file_hash'],
                    uploaded_at=row['uploaded_at'],
                    processing_status=row['processing_status']
                )
                files.append(file_record)
        
        logger.info(f"Discovered {len(files)} pending files for processing")
        
        await update_processing_progress(job_id, 20.0, "discovery_complete", config.postgres_url,
                                       files_discovered=len(files))
        
        return files
        
    except Exception as e:
        logger.error(f"Failed to discover pending files: {e}")
        raise

@activity.defn
async def process_files_batch(params: Dict) -> List[Dict]:
    """Process a batch of files from bucket to Bronze"""
    
    job_id = params["job_id"]
    files = [BucketFileRecord(**f) for f in params["files"]]
    config = BucketToBronzeConfig(**params["config"])
    batch_num = params["batch_num"]
    total_batches = params["total_batches"]
    
    results = []
    
    try:
        # Update progress
        base_progress = 20.0 + (batch_num - 1) * 60.0 / total_batches
        await update_processing_progress(job_id, base_progress, f"processing_batch_{batch_num}", 
                                       config.postgres_url)
        
        # Initialize Supabase client
        supabase: Client = create_client(config.supabase_url, config.supabase_key)
        
        # Process files with controlled concurrency
        semaphore = asyncio.Semaphore(config.max_parallel_workers)
        
        async def process_single_file(file: BucketFileRecord) -> Dict:
            async with semaphore:
                return await process_file_to_bronze(file, supabase, config)
        
        # Execute concurrent processing
        tasks = [process_single_file(file) for file in files]
        batch_results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Process results
        for i, result in enumerate(batch_results):
            if isinstance(result, Exception):
                error_result = {
                    "file_id": files[i].file_id,
                    "status": "failed",
                    "error": str(result),
                    "transactions_processed": 0
                }
                results.append(error_result)
                logger.error(f"Failed to process file {files[i].file_name}: {result}")
            else:
                results.append(result)
        
        # Update progress
        end_progress = 20.0 + batch_num * 60.0 / total_batches
        await update_processing_progress(job_id, end_progress, f"batch_{batch_num}_complete", 
                                       config.postgres_url)
        
        return results
        
    except Exception as e:
        logger.error(f"Failed to process batch {batch_num}: {e}")
        raise

async def process_file_to_bronze(file: BucketFileRecord, supabase: Client, config: BucketToBronzeConfig) -> Dict:
    """Process individual file from bucket to Bronze layer"""
    
    try:
        # Mark file as processing
        await mark_file_processing(file.file_id, config.postgres_url)
        
        # Download file content from bucket
        download_result = supabase.storage.from_(file.bucket_name).download(file.file_path)
        
        if download_result.error:
            raise Exception(f"Failed to download file: {download_result.error}")
        
        file_content = download_result.data
        
        # Parse JSON content
        try:
            json_data = json.loads(file_content.decode('utf-8'))
        except json.JSONDecodeError as e:
            raise Exception(f"Invalid JSON format: {e}")
        
        # Validate Scout Edge structure if validation enabled
        validation_result = None
        if config.validation_enabled:
            validation_result = await validate_scout_edge_structure(json_data)
            if not validation_result['is_valid'] and validation_result['quality_score'] < config.quality_threshold:
                raise Exception(f"Validation failed: {validation_result['issues']}")
        
        # Check for duplicates if deduplication enabled
        if config.deduplication_enabled:
            transaction_id = json_data.get('transactionId')
            if transaction_id and await check_transaction_exists(transaction_id, config.postgres_url):
                await mark_file_duplicate(file.file_id, transaction_id, config.postgres_url)
                return {
                    "file_id": file.file_id,
                    "status": "duplicate",
                    "transaction_id": transaction_id,
                    "transactions_processed": 0
                }
        
        # Extract Scout metadata
        scout_metadata = await extract_scout_metadata(json_data)
        
        # Transform and load to Bronze
        bronze_record = await transform_to_bronze_schema(json_data, file, scout_metadata)
        transaction_id = await load_to_bronze_table(bronze_record, config.postgres_url)
        
        # Update file processing status
        await mark_file_completed(file.file_id, scout_metadata, validation_result, config.postgres_url)
        
        return {
            "file_id": file.file_id,
            "status": "success",
            "transaction_id": transaction_id,
            "transactions_processed": 1,
            "quality_score": validation_result['quality_score'] if validation_result else 1.0,
            "device_id": scout_metadata.get('device_id'),
            "store_id": scout_metadata.get('store_id'),
            "total_amount": float(scout_metadata.get('total_amount', 0))
        }
        
    except Exception as e:
        # Mark file as failed
        await mark_file_failed(file.file_id, str(e), config.postgres_url)
        
        logger.error(f"Failed to process file {file.file_name}: {e}")
        return {
            "file_id": file.file_id,
            "status": "failed",
            "error": str(e),
            "transactions_processed": 0
        }

async def validate_scout_edge_structure(json_data: Dict) -> Dict:
    """Validate Scout Edge JSON structure against schema"""
    
    validation_issues = []
    quality_score = 1.0
    
    # Required fields check
    required_fields = ['transactionId', 'storeId', 'deviceId', 'items', 'totals']
    for field in required_fields:
        if field not in json_data:
            validation_issues.append(f"Missing required field: {field}")
            quality_score -= 0.2
    
    # Validate transaction ID format
    transaction_id = json_data.get('transactionId')
    if transaction_id:
        try:
            uuid.UUID(transaction_id)
        except ValueError:
            validation_issues.append("Invalid transactionId format")
            quality_score -= 0.1
    
    # Validate device ID format
    device_id = json_data.get('deviceId')
    if device_id and not device_id.startswith('SCOUTPI-'):
        validation_issues.append("Invalid deviceId format - should start with SCOUTPI-")
        quality_score -= 0.1
    
    # Validate items array
    items = json_data.get('items', [])
    if not isinstance(items, list):
        validation_issues.append("Items field must be an array")
        quality_score -= 0.2
    elif len(items) == 0:
        validation_issues.append("Items array is empty")
        quality_score -= 0.1
    else:
        # Validate items structure
        for i, item in enumerate(items):
            if not isinstance(item, dict):
                validation_issues.append(f"Item {i} is not an object")
                quality_score -= 0.05
                continue
            
            required_item_fields = ['brandName', 'productName', 'quantity', 'unitPrice', 'totalPrice']
            for field in required_item_fields:
                if field not in item:
                    validation_issues.append(f"Item {i} missing field: {field}")
                    quality_score -= 0.02
    
    # Validate totals structure
    totals = json_data.get('totals', {})
    if not isinstance(totals, dict):
        validation_issues.append("Totals field must be an object")
        quality_score -= 0.1
    else:
        required_total_fields = ['totalAmount', 'totalItems']
        for field in required_total_fields:
            if field not in totals:
                validation_issues.append(f"Totals missing field: {field}")
                quality_score -= 0.05
    
    # Validate brand detection structure
    brand_detection = json_data.get('brandDetection', {})
    if brand_detection and not isinstance(brand_detection, dict):
        validation_issues.append("Brand detection must be an object")
        quality_score -= 0.05
    
    return {
        'is_valid': len(validation_issues) == 0,
        'quality_score': max(quality_score, 0.0),
        'issues': validation_issues,
        'validated_at': datetime.now().isoformat()
    }

async def extract_scout_metadata(json_data: Dict) -> Dict:
    """Extract Scout-specific metadata from JSON"""
    
    items = json_data.get('items', [])
    totals = json_data.get('totals', {})
    brand_detection = json_data.get('brandDetection', {})
    
    metadata = {
        'transaction_id': json_data.get('transactionId'),
        'store_id': json_data.get('storeId'),
        'device_id': json_data.get('deviceId'),
        'items_count': len(items),
        'total_amount': Decimal(str(totals.get('totalAmount', 0))),
        'branded_amount': Decimal(str(totals.get('brandedAmount', 0))),
        'unbranded_amount': Decimal(str(totals.get('unbrandedAmount', 0))),
        'unique_brands_count': totals.get('uniqueBrandsCount', 0),
        'has_brand_detection': bool(brand_detection),
        'detected_brands_count': len(brand_detection.get('detectedBrands', {})),
        'has_audio_transcript': bool(json_data.get('transactionContext', {}).get('audioTranscript')),
        'processing_methods': json_data.get('transactionContext', {}).get('processingMethods', []),
        'edge_version': json_data.get('edgeVersion'),
        'privacy_compliant': json_data.get('privacy', {}).get('audioStored', True) == False,
        'extracted_at': datetime.now()
    }
    
    return metadata

async def transform_to_bronze_schema(json_data: Dict, file: BucketFileRecord, metadata: Dict) -> Dict:
    """Transform Scout Edge JSON to Bronze table schema"""
    
    # Build the Bronze record based on the schema we created
    bronze_record = {
        'transaction_id': metadata['transaction_id'],
        'store_id': metadata['store_id'],
        'device_id': metadata['device_id'],
        'transaction_timestamp': json_data.get('timestamp') or datetime.now(),
        
        # Brand detection intelligence
        'detected_brands': json_data.get('brandDetection', {}).get('detectedBrands'),
        'explicit_mentions': json_data.get('brandDetection', {}).get('explicitMentions'),
        'implicit_signals': json_data.get('brandDetection', {}).get('implicitSignals'),
        'detection_methods': json_data.get('brandDetection', {}).get('detectionMethods', []),
        'category_brand_mapping': json_data.get('brandDetection', {}).get('categoryBrandMapping'),
        
        # Transaction items
        'items': json_data.get('items', []),
        
        # Totals and metrics
        'total_amount': metadata['total_amount'],
        'total_items': json_data.get('totals', {}).get('totalItems'),
        'branded_amount': metadata['branded_amount'],
        'unbranded_amount': metadata['unbranded_amount'],
        'branded_count': json_data.get('totals', {}).get('brandedCount'),
        'unbranded_count': json_data.get('totals', {}).get('unbrandedCount'),
        'unique_brands_count': metadata['unique_brands_count'],
        
        # Transaction context
        'transaction_context': json_data.get('transactionContext'),
        'duration_seconds': json_data.get('transactionContext', {}).get('duration'),
        'payment_method': json_data.get('transactionContext', {}).get('paymentMethod'),
        'time_of_day': json_data.get('transactionContext', {}).get('timeOfDay'),
        'day_type': json_data.get('transactionContext', {}).get('dayType'),
        'audio_transcript': json_data.get('transactionContext', {}).get('audioTranscript'),
        'processing_methods': json_data.get('transactionContext', {}).get('processingMethods', []),
        
        # Privacy and compliance
        'privacy_settings': json_data.get('privacy'),
        'audio_stored': json_data.get('privacy', {}).get('audioStored', False),
        'brand_analysis_only': json_data.get('privacy', {}).get('brandAnalysisOnly', True),
        'no_facial_recognition': json_data.get('privacy', {}).get('noFacialRecognition', True),
        'no_image_processing': json_data.get('privacy', {}).get('noImageProcessing', True),
        'data_retention_days': json_data.get('privacy', {}).get('dataRetentionDays', 30),
        'anonymization_level': json_data.get('privacy', {}).get('anonymizationLevel', 'high'),
        'consent_timestamp': json_data.get('privacy', {}).get('consentTimestamp'),
        
        # Processing metadata
        'processing_time_seconds': json_data.get('processingTime'),
        'edge_version': json_data.get('edgeVersion', 'v2.0.0-stt-only'),
        'source_file': file.file_path,
        
        # ETL metadata
        'ingested_at': datetime.now(),
        'ingested_by': 'bucket_to_bronze_workflow',
        'processing_version': 'v1.0.0'
    }
    
    return bronze_record

async def load_to_bronze_table(bronze_record: Dict, postgres_url: str) -> str:
    """Load transformed record to Bronze table"""
    
    try:
        conn = psycopg2.connect(postgres_url)
        
        with conn.cursor() as cur:
            # Insert into bronze.scout_edge_transactions
            cur.execute("""
                INSERT INTO bronze.scout_edge_transactions (
                    transaction_id, store_id, device_id, transaction_timestamp,
                    detected_brands, explicit_mentions, implicit_signals, 
                    detection_methods, category_brand_mapping,
                    items, total_amount, total_items, branded_amount, 
                    unbranded_amount, branded_count, unbranded_count, 
                    unique_brands_count, transaction_context, duration_seconds,
                    payment_method, time_of_day, day_type, audio_transcript,
                    processing_methods, privacy_settings, audio_stored,
                    brand_analysis_only, no_facial_recognition, no_image_processing,
                    data_retention_days, anonymization_level, consent_timestamp,
                    processing_time_seconds, edge_version, source_file,
                    ingested_at, ingested_by, processing_version
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                ON CONFLICT (transaction_id) DO NOTHING
                RETURNING transaction_id
            """, (
                bronze_record['transaction_id'],
                bronze_record['store_id'],
                bronze_record['device_id'],
                bronze_record['transaction_timestamp'],
                Json(bronze_record['detected_brands']),
                Json(bronze_record['explicit_mentions']),
                Json(bronze_record['implicit_signals']),
                bronze_record['detection_methods'],
                Json(bronze_record['category_brand_mapping']),
                Json(bronze_record['items']),
                bronze_record['total_amount'],
                bronze_record['total_items'],
                bronze_record['branded_amount'],
                bronze_record['unbranded_amount'],
                bronze_record['branded_count'],
                bronze_record['unbranded_count'],
                bronze_record['unique_brands_count'],
                Json(bronze_record['transaction_context']),
                bronze_record['duration_seconds'],
                bronze_record['payment_method'],
                bronze_record['time_of_day'],
                bronze_record['day_type'],
                bronze_record['audio_transcript'],
                bronze_record['processing_methods'],
                Json(bronze_record['privacy_settings']),
                bronze_record['audio_stored'],
                bronze_record['brand_analysis_only'],
                bronze_record['no_facial_recognition'],
                bronze_record['no_image_processing'],
                bronze_record['data_retention_days'],
                bronze_record['anonymization_level'],
                bronze_record['consent_timestamp'],
                bronze_record['processing_time_seconds'],
                bronze_record['edge_version'],
                bronze_record['source_file'],
                bronze_record['ingested_at'],
                bronze_record['ingested_by'],
                bronze_record['processing_version']
            ))
            
            result = cur.fetchone()
            transaction_id = result[0] if result else bronze_record['transaction_id']
            conn.commit()
            
            return transaction_id
            
    except Exception as e:
        logger.error(f"Failed to load to Bronze table: {e}")
        raise

# Helper functions for file status tracking

async def mark_file_processing(file_id: str, postgres_url: str):
    """Mark file as currently processing"""
    conn = psycopg2.connect(postgres_url)
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE metadata.scout_bucket_files 
            SET processing_status = 'processing', updated_at = NOW()
            WHERE id = %s
        """, (file_id,))
        conn.commit()

async def mark_file_completed(file_id: str, metadata: Dict, validation_result: Dict, postgres_url: str):
    """Mark file as successfully processed"""
    conn = psycopg2.connect(postgres_url)
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE metadata.scout_bucket_files 
            SET 
                processing_status = 'completed',
                processed_at = NOW(),
                scout_metadata = %s,
                transaction_count = %s,
                device_id = %s,
                store_id = %s,
                validation_status = 'valid',
                quality_score = %s,
                updated_at = NOW()
            WHERE id = %s
        """, (
            Json(metadata),
            metadata.get('items_count', 1),
            metadata.get('device_id'),
            metadata.get('store_id'),
            validation_result['quality_score'] if validation_result else 1.0,
            file_id
        ))
        conn.commit()

async def mark_file_failed(file_id: str, error: str, postgres_url: str):
    """Mark file as failed processing"""
    conn = psycopg2.connect(postgres_url)
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE metadata.scout_bucket_files 
            SET 
                processing_status = 'failed',
                error_message = %s,
                retry_count = COALESCE(retry_count, 0) + 1,
                updated_at = NOW()
            WHERE id = %s
        """, (error, file_id))
        conn.commit()

async def mark_file_duplicate(file_id: str, transaction_id: str, postgres_url: str):
    """Mark file as duplicate"""
    conn = psycopg2.connect(postgres_url)
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE metadata.scout_bucket_files 
            SET 
                processing_status = 'skipped',
                is_duplicate = true,
                scout_metadata = jsonb_build_object('duplicate_transaction_id', %s),
                updated_at = NOW()
            WHERE id = %s
        """, (transaction_id, file_id))
        conn.commit()

async def check_transaction_exists(transaction_id: str, postgres_url: str) -> bool:
    """Check if transaction already exists in Bronze table"""
    conn = psycopg2.connect(postgres_url)
    with conn.cursor() as cur:
        cur.execute("""
            SELECT 1 FROM bronze.scout_edge_transactions 
            WHERE transaction_id = %s
        """, (transaction_id,))
        return cur.fetchone() is not None

@activity.defn
async def finalize_processing(params: Dict) -> ProcessingStats:
    """Finalize processing and calculate statistics"""
    
    job_id = params["job_id"]
    results = params["results"]
    config = BucketToBronzeConfig(**params["config"])
    
    try:
        # Calculate statistics
        stats = ProcessingStats()
        stats.total_files = len(results)
        
        device_ids = set()
        quality_scores = []
        
        for result in results:
            if result.get("status") == "success":
                stats.successful_files += 1
                stats.total_transactions += result.get("transactions_processed", 0)
                if result.get("device_id"):
                    device_ids.add(result["device_id"])
                if result.get("quality_score"):
                    quality_scores.append(result["quality_score"])
            elif result.get("status") == "failed":
                stats.failed_files += 1
            elif result.get("status") == "duplicate":
                stats.duplicate_files += 1
                stats.skipped_files += 1
            else:
                stats.skipped_files += 1
        
        stats.processed_files = stats.successful_files + stats.failed_files + stats.skipped_files
        stats.unique_devices = len(device_ids)
        stats.avg_quality_score = sum(quality_scores) / len(quality_scores) if quality_scores else 0.0
        
        # Update job record
        conn = psycopg2.connect(config.postgres_url)
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE metadata.scout_sync_jobs SET
                    status = %s,
                    completed_at = %s,
                    duration_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000,
                    files_processed = %s,
                    files_succeeded = %s,
                    files_failed = %s,
                    files_skipped = %s,
                    progress_percentage = 100.0,
                    current_phase = 'completed'
                WHERE id = %s
            """, (
                'completed' if stats.failed_files == 0 else 'completed_with_errors',
                datetime.now(),
                stats.processed_files,
                stats.successful_files,
                stats.failed_files,
                stats.skipped_files,
                job_id
            ))
            conn.commit()
        
        logger.info(f"Processing completed: {stats.successful_files}/{stats.total_files} files successful")
        
        return stats
        
    except Exception as e:
        logger.error(f"Failed to finalize processing: {e}")
        raise

@activity.defn
async def mark_processing_job_failed(params: Dict):
    """Mark processing job as failed"""
    
    job_id = params["job_id"]
    error = params["error"]
    
    logger.error(f"Marking processing job {job_id} as failed: {error}")

async def update_processing_progress(job_id: str, progress: float, phase: str, postgres_url: str, **kwargs):
    """Update processing job progress"""
    
    try:
        conn = psycopg2.connect(postgres_url)
        
        update_fields = ["progress_percentage = %s", "current_phase = %s", "updated_at = NOW()"]
        values = [progress, phase]
        
        for key, value in kwargs.items():
            update_fields.append(f"{key} = %s")
            values.append(value)
        
        with conn.cursor() as cur:
            query = f"""
                UPDATE metadata.scout_sync_jobs 
                SET {', '.join(update_fields)}
                WHERE id = %s
            """
            values.append(job_id)
            cur.execute(query, values)
            conn.commit()
            
    except Exception as e:
        logger.warning(f"Failed to update processing progress: {e}")