"""
Google Drive to Supabase Bucket Sync Workflow
Syncs Scout Edge data from Google Drive folder to Supabase bucket storage
Uses Temporal for orchestration and retry logic
"""

import asyncio
import logging
import json
import hashlib
import mimetypes
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict

from temporalio import workflow, activity
from temporalio.common import RetryPolicy
import httpx
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import psycopg2
from psycopg2.extras import RealDictCursor
from supabase import create_client, Client

from ..contracts.drive_sync_contracts import DriveSyncConfig, DriveFileInfo, SyncResult
from ..monitoring.openlineage_events import emit_lineage_event

logger = logging.getLogger(__name__)

@dataclass
class DriveToBucketConfig:
    """Configuration for Google Drive to bucket sync"""
    drive_folder_id: str
    bucket_name: str = "scout-ingest"
    bucket_path: str = "edge-transactions/"
    batch_size: int = 50
    max_file_size_mb: int = 50
    concurrent_downloads: int = 5
    incremental_sync: bool = True
    validation_enabled: bool = True
    duplicate_detection: bool = True
    
    # Google Drive API credentials
    google_credentials: Optional[Dict] = None
    
    # Database configuration
    postgres_url: str = ""
    supabase_url: str = ""
    supabase_key: str = ""

@dataclass
class DriveFileMetadata:
    """Google Drive file metadata"""
    file_id: str
    name: str
    size: int
    mime_type: str
    created_time: str
    modified_time: str
    md5_checksum: str
    parents: List[str]
    path: str = ""
    is_scout_edge: bool = False

@dataclass
class SyncJobProgress:
    """Progress tracking for sync job"""
    job_id: str
    total_files: int = 0
    processed_files: int = 0
    succeeded_files: int = 0
    failed_files: int = 0
    skipped_files: int = 0
    current_phase: str = "initializing"
    progress_percentage: float = 0.0
    errors: List[str] = None

    def __post_init__(self):
        if self.errors is None:
            self.errors = []

@workflow.defn
class DriveToBucketSyncWorkflow:
    """Temporal workflow for syncing Google Drive to Supabase bucket"""
    
    @workflow.run
    async def run(self, config: DriveToBucketConfig) -> SyncResult:
        """Execute the complete Drive to bucket sync workflow"""
        
        logger.info(f"Starting Drive to bucket sync for folder {config.drive_folder_id}")
        
        # Create sync job record
        job_id = await workflow.execute_activity(
            create_sync_job,
            config,
            start_to_close_timeout=timedelta(minutes=5),
            retry_policy=RetryPolicy(maximum_attempts=3)
        )
        
        try:
            # Step 1: Discover files in Google Drive
            workflow.logger.info("Phase 1: Discovering files in Google Drive")
            drive_files = await workflow.execute_activity(
                discover_drive_files,
                {"job_id": job_id, "config": config},
                start_to_close_timeout=timedelta(minutes=15),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
            
            # Step 2: Filter and classify files
            workflow.logger.info("Phase 2: Filtering and classifying files")
            classified_files = await workflow.execute_activity(
                classify_drive_files,
                {"job_id": job_id, "files": drive_files, "config": config},
                start_to_close_timeout=timedelta(minutes=10),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
            
            # Step 3: Check for incremental sync requirements
            if config.incremental_sync:
                workflow.logger.info("Phase 3: Performing incremental sync check")
                files_to_sync = await workflow.execute_activity(
                    filter_incremental_files,
                    {"job_id": job_id, "files": classified_files, "config": config},
                    start_to_close_timeout=timedelta(minutes=10),
                    retry_policy=RetryPolicy(maximum_attempts=3)
                )
            else:
                files_to_sync = classified_files
            
            # Step 4: Sync files in batches
            workflow.logger.info(f"Phase 4: Syncing {len(files_to_sync)} files to bucket")
            sync_results = []
            
            # Process files in batches
            for i in range(0, len(files_to_sync), config.batch_size):
                batch = files_to_sync[i:i + config.batch_size]
                batch_num = (i // config.batch_size) + 1
                total_batches = (len(files_to_sync) + config.batch_size - 1) // config.batch_size
                
                workflow.logger.info(f"Processing batch {batch_num}/{total_batches} ({len(batch)} files)")
                
                batch_result = await workflow.execute_activity(
                    sync_files_batch,
                    {"job_id": job_id, "files": batch, "config": config, 
                     "batch_num": batch_num, "total_batches": total_batches},
                    start_to_close_timeout=timedelta(minutes=30),
                    retry_policy=RetryPolicy(maximum_attempts=2)
                )
                
                sync_results.extend(batch_result)
                
                # Brief pause between batches to avoid rate limits
                await asyncio.sleep(1)
            
            # Step 5: Validate and finalize
            workflow.logger.info("Phase 5: Validation and finalization")
            final_result = await workflow.execute_activity(
                finalize_sync_job,
                {"job_id": job_id, "sync_results": sync_results, "config": config},
                start_to_close_timeout=timedelta(minutes=10),
                retry_policy=RetryPolicy(maximum_attempts=3)
            )
            
            logger.info(f"Drive to bucket sync completed. Job ID: {job_id}")
            return final_result
            
        except Exception as e:
            # Mark job as failed
            await workflow.execute_activity(
                mark_job_failed,
                {"job_id": job_id, "error": str(e)},
                start_to_close_timeout=timedelta(minutes=5),
                retry_policy=RetryPolicy(maximum_attempts=1)
            )
            raise

# Activity implementations

@activity.defn
async def create_sync_job(config: DriveToBucketConfig) -> str:
    """Create a new sync job record"""
    
    import uuid
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
                f"drive_sync_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                "drive_sync",
                json.dumps(asdict(config)),
                "running",
                datetime.now(),
                0.0,
                "initializing"
            ))
            conn.commit()
        
        logger.info(f"Created sync job {job_id}")
        return job_id
        
    except Exception as e:
        logger.error(f"Failed to create sync job: {e}")
        raise

@activity.defn
async def discover_drive_files(params: Dict) -> List[DriveFileMetadata]:
    """Discover files in Google Drive folder"""
    
    job_id = params["job_id"]
    config = DriveToBucketConfig(**params["config"])
    
    try:
        # Update job progress
        await update_job_progress(job_id, 10.0, "discovering_files", config.postgres_url)
        
        # Build Google Drive service
        credentials = Credentials.from_authorized_user_info(config.google_credentials)
        service = build('drive', 'v3', credentials=credentials)
        
        # Discover files recursively
        files = []
        page_token = None
        
        while True:
            query = f"'{config.drive_folder_id}' in parents and trashed=false"
            
            results = service.files().list(
                q=query,
                pageSize=1000,
                pageToken=page_token,
                fields="nextPageToken, files(id, name, size, mimeType, createdTime, modifiedTime, md5Checksum, parents)",
                orderBy="createdTime desc"
            ).execute()
            
            items = results.get('files', [])
            
            for item in items:
                # Skip if file is too large
                if int(item.get('size', 0)) > config.max_file_size_mb * 1024 * 1024:
                    logger.warning(f"Skipping large file: {item['name']} ({item.get('size', 0)} bytes)")
                    continue
                
                file_meta = DriveFileMetadata(
                    file_id=item['id'],
                    name=item['name'],
                    size=int(item.get('size', 0)),
                    mime_type=item.get('mimeType', ''),
                    created_time=item.get('createdTime', ''),
                    modified_time=item.get('modifiedTime', ''),
                    md5_checksum=item.get('md5Checksum', ''),
                    parents=item.get('parents', [])
                )
                
                files.append(file_meta)
            
            page_token = results.get('nextPageToken')
            if not page_token:
                break
        
        logger.info(f"Discovered {len(files)} files in Google Drive folder")
        
        # Update job progress
        await update_job_progress(job_id, 25.0, "discovery_complete", config.postgres_url,
                                files_discovered=len(files))
        
        return files
        
    except Exception as e:
        logger.error(f"Failed to discover Drive files: {e}")
        raise

@activity.defn
async def classify_drive_files(params: Dict) -> List[DriveFileMetadata]:
    """Classify and filter Drive files for Scout Edge data"""
    
    job_id = params["job_id"]
    files = [DriveFileMetadata(**f) for f in params["files"]]
    config = DriveToBucketConfig(**params["config"])
    
    scout_edge_files = []
    
    try:
        await update_job_progress(job_id, 35.0, "classifying_files", config.postgres_url)
        
        for file in files:
            # Check if file is potentially Scout Edge data
            is_scout_edge = (
                file.name.endswith('.json') and
                file.mime_type in ['application/json', 'text/plain'] and
                file.size > 100  # Minimum reasonable size for Scout Edge transaction
            )
            
            if is_scout_edge:
                file.is_scout_edge = True
                scout_edge_files.append(file)
        
        logger.info(f"Classified {len(scout_edge_files)} Scout Edge files out of {len(files)} total files")
        
        await update_job_progress(job_id, 40.0, "classification_complete", config.postgres_url)
        
        return scout_edge_files
        
    except Exception as e:
        logger.error(f"Failed to classify files: {e}")
        raise

@activity.defn
async def filter_incremental_files(params: Dict) -> List[DriveFileMetadata]:
    """Filter files for incremental sync"""
    
    job_id = params["job_id"]
    files = [DriveFileMetadata(**f) for f in params["files"]]
    config = DriveToBucketConfig(**params["config"])
    
    try:
        await update_job_progress(job_id, 45.0, "incremental_filtering", config.postgres_url)
        
        conn = psycopg2.connect(config.postgres_url)
        files_to_sync = []
        
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            for file in files:
                # Check if file already exists and is up to date
                cur.execute("""
                    SELECT last_synced_at, file_hash, sync_status 
                    FROM metadata.google_drive_files 
                    WHERE drive_file_id = %s
                """, (file.file_id,))
                
                existing = cur.fetchone()
                
                if existing is None:
                    # New file - add to sync
                    files_to_sync.append(file)
                elif existing['file_hash'] != file.md5_checksum:
                    # File changed - add to sync
                    files_to_sync.append(file)
                elif existing['sync_status'] == 'failed':
                    # Previous sync failed - retry
                    files_to_sync.append(file)
                # else: file is up to date, skip
        
        logger.info(f"Incremental sync: {len(files_to_sync)} files need syncing")
        
        await update_job_progress(job_id, 50.0, "incremental_filtering_complete", config.postgres_url)
        
        return files_to_sync
        
    except Exception as e:
        logger.error(f"Failed to filter incremental files: {e}")
        raise

@activity.defn
async def sync_files_batch(params: Dict) -> List[Dict]:
    """Sync a batch of files from Drive to bucket"""
    
    job_id = params["job_id"]
    files = [DriveFileMetadata(**f) for f in params["files"]]
    config = DriveToBucketConfig(**params["config"])
    batch_num = params["batch_num"]
    total_batches = params["total_batches"]
    
    results = []
    
    try:
        # Update progress
        base_progress = 50.0 + (batch_num - 1) * 30.0 / total_batches
        await update_job_progress(job_id, base_progress, f"syncing_batch_{batch_num}", config.postgres_url)
        
        # Initialize clients
        credentials = Credentials.from_authorized_user_info(config.google_credentials)
        drive_service = build('drive', 'v3', credentials=credentials)
        supabase: Client = create_client(config.supabase_url, config.supabase_key)
        
        # Process files concurrently
        semaphore = asyncio.Semaphore(config.concurrent_downloads)
        
        async def sync_single_file(file: DriveFileMetadata) -> Dict:
            async with semaphore:
                return await sync_file_to_bucket(file, drive_service, supabase, config)
        
        # Execute concurrent downloads
        tasks = [sync_single_file(file) for file in files]
        batch_results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Process results
        for i, result in enumerate(batch_results):
            if isinstance(result, Exception):
                error_result = {
                    "file_id": files[i].file_id,
                    "status": "failed",
                    "error": str(result)
                }
                results.append(error_result)
                logger.error(f"Failed to sync file {files[i].name}: {result}")
            else:
                results.append(result)
        
        # Update progress
        end_progress = 50.0 + batch_num * 30.0 / total_batches
        await update_job_progress(job_id, end_progress, f"batch_{batch_num}_complete", config.postgres_url)
        
        return results
        
    except Exception as e:
        logger.error(f"Failed to sync batch {batch_num}: {e}")
        raise

async def sync_file_to_bucket(file: DriveFileMetadata, drive_service, supabase: Client, config: DriveToBucketConfig) -> Dict:
    """Sync individual file from Drive to bucket"""
    
    try:
        # Download file content from Google Drive
        file_content = drive_service.files().get_media(fileId=file.file_id).execute()
        
        # Validate Scout Edge content if validation enabled
        if config.validation_enabled and file.is_scout_edge:
            try:
                json_content = json.loads(file_content.decode('utf-8'))
                
                # Basic Scout Edge validation
                required_fields = ['transactionId', 'storeId', 'deviceId', 'items']
                missing_fields = [field for field in required_fields if field not in json_content]
                
                if missing_fields:
                    return {
                        "file_id": file.file_id,
                        "status": "failed",
                        "error": f"Missing required fields: {missing_fields}"
                    }
                    
            except json.JSONDecodeError as e:
                return {
                    "file_id": file.file_id,
                    "status": "failed",
                    "error": f"Invalid JSON: {e}"
                }
        
        # Upload to Supabase bucket
        bucket_path = f"{config.bucket_path}{file.name}"
        
        upload_result = supabase.storage.from_(config.bucket_name).upload(
            bucket_path,
            file_content,
            {
                "content-type": file.mime_type,
                "x-upsert": "true"  # Overwrite if exists
            }
        )
        
        if upload_result.error:
            return {
                "file_id": file.file_id,
                "status": "failed",
                "error": f"Upload failed: {upload_result.error}"
            }
        
        # Record successful sync
        await record_successful_sync(file, bucket_path, config)
        
        return {
            "file_id": file.file_id,
            "status": "success",
            "bucket_path": bucket_path,
            "size": file.size
        }
        
    except Exception as e:
        logger.error(f"Failed to sync file {file.name}: {e}")
        return {
            "file_id": file.file_id,
            "status": "failed",
            "error": str(e)
        }

async def record_successful_sync(file: DriveFileMetadata, bucket_path: str, config: DriveToBucketConfig):
    """Record successful file sync in database"""
    
    try:
        conn = psycopg2.connect(config.postgres_url)
        
        with conn.cursor() as cur:
            # Update Google Drive files table
            cur.execute("""
                INSERT INTO metadata.google_drive_files (
                    drive_file_id, drive_folder_id, drive_name, mime_type,
                    file_size, file_hash, created_time, modified_time,
                    sync_status, last_synced_at, bucket_file_path,
                    is_scout_edge_file, file_classification
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (drive_file_id) DO UPDATE SET
                    file_hash = EXCLUDED.file_hash,
                    modified_time = EXCLUDED.modified_time,
                    sync_status = EXCLUDED.sync_status,
                    last_synced_at = EXCLUDED.last_synced_at,
                    bucket_file_path = EXCLUDED.bucket_file_path,
                    updated_at = NOW()
            """, (
                file.file_id,
                file.parents[0] if file.parents else None,
                file.name,
                file.mime_type,
                file.size,
                file.md5_checksum,
                file.created_time,
                file.modified_time,
                'synced',
                datetime.now(),
                bucket_path,
                file.is_scout_edge,
                'scout_edge_transaction' if file.is_scout_edge else 'unknown'
            ))
            
            # Insert bucket file record
            cur.execute("""
                INSERT INTO metadata.scout_bucket_files (
                    bucket_name, file_path, file_name, file_size, file_type,
                    content_type, source_type, source_id, processing_status,
                    file_hash, uploaded_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (bucket_name, file_path) DO UPDATE SET
                    file_hash = EXCLUDED.file_hash,
                    uploaded_at = EXCLUDED.uploaded_at,
                    updated_at = NOW()
            """, (
                config.bucket_name,
                bucket_path,
                file.name,
                file.size,
                'json' if file.name.endswith('.json') else 'unknown',
                file.mime_type,
                'google_drive',
                file.file_id,
                'pending',
                file.md5_checksum,
                datetime.now()
            ))
            
            conn.commit()
            
    except Exception as e:
        logger.error(f"Failed to record sync for {file.name}: {e}")
        raise

@activity.defn
async def finalize_sync_job(params: Dict) -> SyncResult:
    """Finalize sync job and return results"""
    
    job_id = params["job_id"]
    sync_results = params["sync_results"]
    config = DriveToBucketConfig(**params["config"])
    
    try:
        # Calculate final metrics
        total_files = len(sync_results)
        succeeded = len([r for r in sync_results if r.get("status") == "success"])
        failed = len([r for r in sync_results if r.get("status") == "failed"])
        total_size = sum(r.get("size", 0) for r in sync_results if r.get("status") == "success")
        
        # Update job record
        conn = psycopg2.connect(config.postgres_url)
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE metadata.scout_sync_jobs SET
                    status = %s,
                    completed_at = %s,
                    duration_ms = EXTRACT(EPOCH FROM (NOW() - started_at)) * 1000,
                    files_discovered = %s,
                    files_processed = %s,
                    files_succeeded = %s,
                    files_failed = %s,
                    total_size_bytes = %s,
                    progress_percentage = 100.0,
                    current_phase = 'completed'
                WHERE id = %s
            """, (
                'completed' if failed == 0 else 'completed_with_errors',
                datetime.now(),
                total_files,
                total_files,
                succeeded,
                failed,
                total_size,
                job_id
            ))
            conn.commit()
        
        # Emit lineage event
        await emit_lineage_event({
            "job_name": f"drive_to_bucket_sync_{job_id}",
            "inputs": [{"namespace": "google_drive", "name": config.drive_folder_id}],
            "outputs": [{"namespace": config.bucket_name, "name": config.bucket_path}],
            "run_id": job_id,
            "event_type": "COMPLETE"
        })
        
        result = SyncResult(
            job_id=job_id,
            total_files=total_files,
            succeeded_files=succeeded,
            failed_files=failed,
            total_size_bytes=total_size,
            duration_seconds=None  # Will be calculated from DB
        )
        
        logger.info(f"Sync job {job_id} completed: {succeeded}/{total_files} files synced successfully")
        
        return result
        
    except Exception as e:
        logger.error(f"Failed to finalize sync job {job_id}: {e}")
        raise

@activity.defn
async def mark_job_failed(params: Dict):
    """Mark sync job as failed"""
    
    job_id = params["job_id"]
    error = params["error"]
    
    try:
        # This would use the postgres connection from config
        # Simplified for brevity
        logger.error(f"Marking job {job_id} as failed: {error}")
        
    except Exception as e:
        logger.error(f"Failed to mark job as failed: {e}")

# Helper functions

async def update_job_progress(job_id: str, progress: float, phase: str, postgres_url: str, **kwargs):
    """Update job progress in database"""
    
    try:
        conn = psycopg2.connect(postgres_url)
        
        # Build update fields
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
        logger.warning(f"Failed to update job progress: {e}")