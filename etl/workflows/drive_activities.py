"""
Google Drive ETL Activities - Production Implementation
Temporal activities for Google Drive file synchronization and processing
"""

import os
import hashlib
import uuid
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass

import psycopg2
import psycopg2.extras
from temporalio import activity
from googleapiclient.discovery import build
from google.oauth2.service_account import Credentials
from google.api_core.exceptions import GoogleAPIError
import magic
import aiofiles
import aiohttp

from .drive_ingestion_workflow import (
    InitializeDriveJobRunInput,
    EmitDriveLineageInput,
    GetLastDriveSyncInput, GetLastDriveSyncResult,
    ScanDriveFolderInput, ScanDriveFolderResult,
    DriveFileInfo,
    DownloadDriveFilesInput, DownloadDriveFilesResult,
    DownloadedFile,
    ValidateDriveFilesInput, ValidateDriveFilesResult,
    LoadDriveBronzeInput, LoadDriveBronzeResult,
    UpdateDriveSyncLogInput,
    RecordDriveQualityMetricsInput,
    CompleteDriveJobRunInput,
    EmitDriveLineageCompleteInput,
    EmitDriveLineageFailInput
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
DRIVE_SCOPES = ['https://www.googleapis.com/auth/drive.readonly']
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
PII_PATTERNS = [
    r'\b\d{3}-\d{2}-\d{4}\b',  # SSN
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',  # Email
    r'\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b',  # Credit card
    r'\b\d{10,15}\b'  # Phone numbers
]


def get_database_connection() -> psycopg2.extensions.connection:
    """Get database connection using environment variables"""
    return psycopg2.connect(
        host=os.environ.get('POSTGRES_HOST', 'localhost'),
        port=os.environ.get('POSTGRES_PORT', '6543'),
        database=os.environ.get('POSTGRES_DATABASE', 'postgres'),
        user=os.environ.get('POSTGRES_USER', 'postgres'),
        password=os.environ['POSTGRES_PASSWORD']
    )


def get_drive_service():
    """Initialize Google Drive API service"""
    try:
        # Use service account credentials from environment
        creds_json = os.environ.get('GOOGLE_SERVICE_ACCOUNT_JSON')
        if creds_json:
            creds_dict = json.loads(creds_json)
            credentials = Credentials.from_service_account_info(
                creds_dict, scopes=DRIVE_SCOPES
            )
        else:
            # Fallback to service account file
            creds_file = os.environ.get('GOOGLE_SERVICE_ACCOUNT_FILE')
            credentials = Credentials.from_service_account_file(
                creds_file, scopes=DRIVE_SCOPES
            )
        
        return build('drive', 'v3', credentials=credentials)
    except Exception as e:
        logger.error(f"Failed to initialize Drive service: {e}")
        raise


def detect_pii_content(content: bytes, filename: str) -> bool:
    """Detect PII in file content using deterministic patterns"""
    try:
        # Check filename for PII indicators
        pii_filename_patterns = ['confidential', 'private', 'personal', 'ssn', 'tax', 'financial']
        if any(pattern in filename.lower() for pattern in pii_filename_patterns):
            return True
        
        # Check content if it's text-readable
        try:
            text_content = content.decode('utf-8', errors='ignore')[:10000]  # First 10KB
            
            import re
            for pattern in PII_PATTERNS:
                if re.search(pattern, text_content, re.IGNORECASE):
                    return True
                    
        except UnicodeDecodeError:
            # Binary file, skip content analysis
            pass
            
        return False
    except Exception as e:
        logger.warning(f"PII detection failed for {filename}: {e}")
        return True  # Err on side of caution


@activity.defn
async def initialize_drive_job_run(input: InitializeDriveJobRunInput) -> None:
    """Initialize Google Drive job run tracking"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO metadata.job_runs (
                id, job_name, run_id, status, started_at, 
                source_system, source_name, job_type, metadata
            ) VALUES (
                %s, %s, %s, 'running', %s, 
                'google_drive', %s, 'drive_ingestion', %s
            )
        """, (
            input.job_run_id,
            input.job_name,
            input.job_run_id,
            datetime.utcnow(),
            input.folder_name,
            json.dumps({
                'folder_id': input.folder_id,
                'folder_name': input.folder_name,
                'sync_type': input.sync_type
            })
        ))
        
        conn.commit()
        logger.info(f"Initialized Drive job run: {input.job_run_id}")
        
    except Exception as e:
        logger.error(f"Failed to initialize Drive job run: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def emit_drive_lineage_start(input: EmitDriveLineageInput) -> None:
    """Emit OpenLineage START event for Drive ingestion"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        lineage_event = {
            "eventType": "START",
            "eventTime": datetime.utcnow().isoformat() + "Z",
            "run": {
                "runId": input.run_id,
                "facets": {}
            },
            "job": {
                "namespace": "scout.etl.drive",
                "name": input.job_name,
                "facets": {
                    "documentation": {
                        "_producer": "scout-etl",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/DocumentationJobFacet.json",
                        "description": f"Google Drive ingestion for folder: {input.folder_name}"
                    }
                }
            },
            "inputs": [{
                "namespace": "google_drive",
                "name": f"folder.{input.folder_id}",
                "facets": {
                    "dataSource": {
                        "_producer": "scout-etl",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/DatasourceDatasetFacet.json",
                        "name": "google_drive",
                        "uri": f"https://drive.google.com/drive/folders/{input.folder_id}"
                    }
                }
            }],
            "outputs": [{
                "namespace": "scout.bronze",
                "name": "bronze_drive_files",
                "facets": {}
            }],
            "producer": "https://github.com/scout-etl/v7"
        }
        
        cursor.execute("""
            INSERT INTO metadata.openlineage_events (
                event_id, job_name, run_id, event_type, event_data, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            str(uuid.uuid4()),
            input.job_name,
            input.run_id,
            "START",
            json.dumps(lineage_event),
            datetime.utcnow()
        ))
        
        conn.commit()
        logger.info(f"Emitted START lineage event for {input.job_name}")
        
    except Exception as e:
        logger.error(f"Failed to emit lineage start event: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def get_last_drive_sync(input: GetLastDriveSyncInput) -> GetLastDriveSyncResult:
    """Get timestamp of last successful Drive sync"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT MAX(synced_at) 
            FROM drive_sync_log 
            WHERE folder_id = %s AND status = 'success'
        """, (input.folder_id,))
        
        result = cursor.fetchone()
        last_sync_time = result[0] if result and result[0] else None
        
        logger.info(f"Last sync time for folder {input.folder_id}: {last_sync_time}")
        return GetLastDriveSyncResult(last_sync_time=last_sync_time)
        
    except Exception as e:
        logger.error(f"Failed to get last sync time: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def scan_drive_folder(input: ScanDriveFolderInput) -> ScanDriveFolderResult:
    """Scan Google Drive folder for new/changed files"""
    try:
        service = get_drive_service()
        
        # Build query for files in folder
        query_parts = [f"'{input.folder_id}' in parents", "trashed=false"]
        
        # Add file type filters
        if input.file_types:
            mime_types = []
            for file_type in input.file_types:
                if file_type == 'pdf':
                    mime_types.append("mimeType='application/pdf'")
                elif file_type == 'docx':
                    mime_types.append("mimeType='application/vnd.openxmlformats-officedocument.wordprocessingml.document'")
                elif file_type == 'xlsx':
                    mime_types.append("mimeType='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'")
            
            if mime_types:
                query_parts.append(f"({' or '.join(mime_types)})")
        
        # Add time filter for incremental sync
        if input.since_time:
            time_str = input.since_time.strftime('%Y-%m-%dT%H:%M:%S')
            query_parts.append(f"modifiedTime > '{time_str}'")
        
        query = ' and '.join(query_parts)
        
        # Execute Drive API call
        files = []
        page_token = None
        
        while True:
            try:
                results = service.files().list(
                    q=query,
                    fields='nextPageToken, files(id, name, size, md5Checksum, modifiedTime, mimeType)',
                    pageSize=100,
                    pageToken=page_token
                ).execute()
                
                for file in results.get('files', []):
                    # Skip files without size or checksum (e.g., Google Docs)
                    if not file.get('size') or not file.get('md5Checksum'):
                        continue
                    
                    files.append(DriveFileInfo(
                        file_id=file['id'],
                        name=file['name'],
                        size=int(file['size']),
                        md5_checksum=file['md5Checksum'],
                        modified_time=datetime.fromisoformat(
                            file['modifiedTime'].replace('Z', '+00:00')
                        ),
                        mime_type=file['mimeType']
                    ))
                
                page_token = results.get('nextPageToken')
                if not page_token:
                    break
                    
            except GoogleAPIError as e:
                logger.error(f"Drive API error: {e}")
                raise
        
        logger.info(f"Scanned Drive folder {input.folder_id}: found {len(files)} files")
        return ScanDriveFolderResult(files=files, file_count=len(files))
        
    except Exception as e:
        logger.error(f"Failed to scan Drive folder: {e}")
        raise


@activity.defn
async def download_drive_files(input: DownloadDriveFilesInput) -> DownloadDriveFilesResult:
    """Download files from Google Drive"""
    try:
        service = get_drive_service()
        downloaded_files = []
        total_bytes = 0
        
        for file_info in input.files:
            try:
                # Skip large files
                if file_info.size > MAX_FILE_SIZE:
                    logger.warning(f"Skipping large file {file_info.name}: {file_info.size} bytes")
                    continue
                
                # Download file content
                file_content = service.files().get_media(fileId=file_info.file_id).execute()
                
                # Extract metadata if requested
                metadata = {}
                if input.include_metadata:
                    file_metadata = service.files().get(
                        fileId=file_info.file_id,
                        fields='createdTime,modifiedTime,owners,permissions,parents,webViewLink'
                    ).execute()
                    
                    metadata = {
                        'createdTime': file_metadata.get('createdTime'),
                        'modifiedTime': file_metadata.get('modifiedTime'),
                        'owners': file_metadata.get('owners', []),
                        'webViewLink': file_metadata.get('webViewLink'),
                        'fileId': file_info.file_id,
                        'originalSize': file_info.size
                    }
                
                downloaded_files.append(DownloadedFile(
                    file_info=file_info,
                    content=file_content,
                    metadata=metadata
                ))
                
                total_bytes += len(file_content)
                logger.debug(f"Downloaded {file_info.name}: {len(file_content)} bytes")
                
            except Exception as e:
                logger.error(f"Failed to download file {file_info.name}: {e}")
                # Continue with other files
                continue
        
        logger.info(f"Downloaded {len(downloaded_files)} files, {total_bytes} bytes total")
        return DownloadDriveFilesResult(
            downloaded_files=downloaded_files,
            bytes_downloaded=total_bytes
        )
        
    except Exception as e:
        logger.error(f"Failed to download Drive files: {e}")
        raise


@activity.defn
async def validate_drive_files(input: ValidateDriveFilesInput) -> ValidateDriveFilesResult:
    """Validate downloaded files (virus scan, integrity check)"""
    try:
        validated_files = []
        failed_files = []
        
        for downloaded_file in input.downloaded_files:
            try:
                file_info = downloaded_file.file_info
                content = downloaded_file.content
                
                # Integrity check - verify MD5 checksum
                calculated_md5 = hashlib.md5(content).hexdigest()
                if calculated_md5 != file_info.md5_checksum:
                    logger.warning(f"MD5 mismatch for {file_info.name}")
                    failed_files.append(file_info.file_id)
                    continue
                
                # File type validation
                try:
                    detected_mime = magic.from_buffer(content, mime=True)
                    if detected_mime != file_info.mime_type:
                        logger.warning(f"MIME type mismatch for {file_info.name}: {detected_mime} vs {file_info.mime_type}")
                except:
                    # magic library may not be available
                    pass
                
                # Basic malware check - scan for suspicious patterns
                try:
                    content_str = content[:1024].decode('utf-8', errors='ignore')
                    suspicious_patterns = ['<script>', 'javascript:', 'vbscript:', 'eval(']
                    if any(pattern in content_str.lower() for pattern in suspicious_patterns):
                        logger.warning(f"Suspicious content detected in {file_info.name}")
                        failed_files.append(file_info.file_id)
                        continue
                except:
                    pass
                
                validated_files.append(downloaded_file)
                
            except Exception as e:
                logger.error(f"Validation failed for file {downloaded_file.file_info.name}: {e}")
                failed_files.append(downloaded_file.file_info.file_id)
        
        logger.info(f"Validated {len(validated_files)} files, {len(failed_files)} failed")
        return ValidateDriveFilesResult(
            validated_files=validated_files,
            failed_files=failed_files
        )
        
    except Exception as e:
        logger.error(f"File validation failed: {e}")
        raise


@activity.defn
async def load_drive_bronze_table(input: LoadDriveBronzeInput) -> LoadDriveBronzeResult:
    """Load Drive files to Bronze table"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        files_inserted = 0
        files_failed = 0
        total_size = 0
        
        for downloaded_file in input.files:
            try:
                file_info = downloaded_file.file_info
                content = downloaded_file.content
                metadata = downloaded_file.metadata or {}
                
                # Detect PII
                contains_pii = detect_pii_content(content, file_info.name)
                
                # Mask content if PII detected
                final_content = b'[CONTENT MASKED - PII DETECTED]' if contains_pii else content
                
                # Determine file category
                if file_info.mime_type.startswith('image/'):
                    file_category = 'image'
                elif file_info.mime_type.startswith('video/'):
                    file_category = 'video'
                elif file_info.mime_type == 'application/pdf':
                    file_category = 'document'
                elif 'office' in file_info.mime_type:
                    file_category = 'document'
                elif 'google-apps' in file_info.mime_type:
                    file_category = 'google_workspace'
                else:
                    file_category = 'other'
                
                # Calculate quality score
                quality_score = 1.0
                if contains_pii:
                    quality_score *= 0.8
                if file_info.size == 0:
                    quality_score *= 0.5
                if not file_info.md5_checksum:
                    quality_score *= 0.7
                
                # Insert into bronze table
                cursor.execute("""
                    INSERT INTO edge.bronze_drive_imports (
                        file_id, file_name, folder_id, folder_name, mime_type,
                        file_size_bytes, md5_checksum, file_content, file_metadata,
                        created_time, modified_time, synced_at, job_run_id
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    ) ON CONFLICT (file_id) DO UPDATE SET
                        file_content = EXCLUDED.file_content,
                        file_metadata = EXCLUDED.file_metadata,
                        modified_time = EXCLUDED.modified_time,
                        synced_at = EXCLUDED.synced_at,
                        job_run_id = EXCLUDED.job_run_id
                """, (
                    file_info.file_id,
                    file_info.name,
                    input.folder_id,
                    input.folder_name,
                    file_info.mime_type,
                    file_info.size,
                    file_info.md5_checksum,
                    final_content,
                    json.dumps(metadata),
                    metadata.get('createdTime'),
                    file_info.modified_time,
                    datetime.utcnow(),
                    input.job_run_id
                ))
                
                files_inserted += 1
                total_size += file_info.size
                
            except Exception as e:
                logger.error(f"Failed to insert file {downloaded_file.file_info.name}: {e}")
                files_failed += 1
                continue
        
        conn.commit()
        logger.info(f"Loaded {files_inserted} files to Bronze table, {files_failed} failed")
        
        return LoadDriveBronzeResult(
            files_inserted=files_inserted,
            files_failed=files_failed,
            total_size_bytes=total_size
        )
        
    except Exception as e:
        logger.error(f"Failed to load Drive Bronze table: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def update_drive_sync_log(input: UpdateDriveSyncLogInput) -> None:
    """Update Drive sync log with processed files"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        for file_info in input.files:
            cursor.execute("""
                INSERT INTO drive_sync_log (
                    file_id, file_name, folder_id, file_size_bytes, 
                    md5_checksum, synced_at, status, job_run_id
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (file_id) DO UPDATE SET
                    synced_at = EXCLUDED.synced_at,
                    status = EXCLUDED.status,
                    job_run_id = EXCLUDED.job_run_id
            """, (
                file_info.file_id,
                file_info.name,
                input.folder_id,
                file_info.size,
                file_info.md5_checksum,
                input.sync_timestamp,
                'success',
                input.job_run_id
            ))
        
        conn.commit()
        logger.info(f"Updated sync log for {len(input.files)} files")
        
    except Exception as e:
        logger.error(f"Failed to update sync log: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def record_drive_quality_metrics(input: RecordDriveQualityMetricsInput) -> None:
    """Record Drive ingestion quality metrics"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO metadata.quality_metrics (
                id, job_run_id, layer, table_name, metric_name, 
                metric_value, threshold, status, measured_at
            ) VALUES 
            (%s, %s, 'bronze', 'bronze_drive_files', 'files_processed', %s, %s, %s, %s),
            (%s, %s, 'bronze', 'bronze_drive_files', 'files_synced', %s, %s, %s, %s),
            (%s, %s, 'bronze', 'bronze_drive_files', 'bytes_transferred', %s, %s, %s, %s),
            (%s, %s, 'bronze', 'bronze_drive_files', 'quality_score', %s, %s, %s, %s)
        """, (
            str(uuid.uuid4()), input.job_run_id, input.files_processed, input.files_processed, 'passed', datetime.utcnow(),
            str(uuid.uuid4()), input.job_run_id, input.files_synced, input.files_processed, 'passed', datetime.utcnow(),
            str(uuid.uuid4()), input.job_run_id, input.bytes_transferred, 1000000, 'passed', datetime.utcnow(),
            str(uuid.uuid4()), input.job_run_id, input.quality_score, 0.8, 
            'passed' if input.quality_score >= 0.8 else 'failed', datetime.utcnow()
        ))
        
        conn.commit()
        logger.info(f"Recorded quality metrics for job {input.job_run_id}")
        
    except Exception as e:
        logger.error(f"Failed to record quality metrics: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def complete_drive_job_run(input: CompleteDriveJobRunInput) -> None:
    """Complete Drive job run tracking"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE metadata.job_runs 
            SET status = %s, completed_at = %s, 
                records_processed = %s, error_message = %s,
                metadata = metadata || %s
            WHERE id = %s
        """, (
            input.status,
            datetime.utcnow(),
            input.files_processed,
            input.error_message,
            json.dumps({
                'files_synced': input.files_synced,
                'files_failed': input.files_failed,
                'bytes_transferred': input.bytes_transferred
            }),
            input.job_run_id
        ))
        
        conn.commit()
        logger.info(f"Completed Drive job run {input.job_run_id}: {input.status}")
        
    except Exception as e:
        logger.error(f"Failed to complete job run: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def emit_drive_lineage_complete(input: EmitDriveLineageCompleteInput) -> None:
    """Emit OpenLineage COMPLETE event for Drive ingestion"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        lineage_event = {
            "eventType": "COMPLETE",
            "eventTime": datetime.utcnow().isoformat() + "Z",
            "run": {
                "runId": input.run_id,
                "facets": {
                    "stats": {
                        "_producer": "scout-etl",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/StatsRunFacet.json",
                        "files_synced": input.files_synced,
                        "bytes_transferred": input.bytes_transferred
                    }
                }
            },
            "job": {
                "namespace": "scout.etl.drive",
                "name": input.job_name,
                "facets": {}
            },
            "inputs": [{
                "namespace": "google_drive",
                "name": f"folder.{input.folder_id}",
                "facets": {}
            }],
            "outputs": [{
                "namespace": "scout.bronze",
                "name": "bronze_drive_files",
                "facets": {
                    "stats": {
                        "_producer": "scout-etl",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/StatsDatasetFacet.json",
                        "rowCount": input.files_synced,
                        "size": input.bytes_transferred
                    }
                }
            }],
            "producer": "https://github.com/scout-etl/v7"
        }
        
        cursor.execute("""
            INSERT INTO metadata.openlineage_events (
                event_id, job_name, run_id, event_type, event_data, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            str(uuid.uuid4()),
            input.job_name,
            input.run_id,
            "COMPLETE",
            json.dumps(lineage_event),
            datetime.utcnow()
        ))
        
        conn.commit()
        logger.info(f"Emitted COMPLETE lineage event for {input.job_name}")
        
    except Exception as e:
        logger.error(f"Failed to emit lineage complete event: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()


@activity.defn
async def emit_drive_lineage_fail(input: EmitDriveLineageFailInput) -> None:
    """Emit OpenLineage FAIL event for Drive ingestion"""
    try:
        conn = get_database_connection()
        cursor = conn.cursor()
        
        lineage_event = {
            "eventType": "FAIL",
            "eventTime": datetime.utcnow().isoformat() + "Z",
            "run": {
                "runId": input.run_id,
                "facets": {
                    "errorMessage": {
                        "_producer": "scout-etl",
                        "_schemaURL": "https://openlineage.io/spec/facets/1-0-0/ErrorMessageRunFacet.json",
                        "message": input.error_message,
                        "programmingLanguage": "python"
                    }
                }
            },
            "job": {
                "namespace": "scout.etl.drive",
                "name": input.job_name,
                "facets": {}
            },
            "producer": "https://github.com/scout-etl/v7"
        }
        
        cursor.execute("""
            INSERT INTO metadata.openlineage_events (
                event_id, job_name, run_id, event_type, event_data, created_at
            ) VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            str(uuid.uuid4()),
            input.job_name,
            input.run_id,
            "FAIL",
            json.dumps(lineage_event),
            datetime.utcnow()
        ))
        
        conn.commit()
        logger.info(f"Emitted FAIL lineage event for {input.job_name}")
        
    except Exception as e:
        logger.error(f"Failed to emit lineage fail event: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()