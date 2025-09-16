#!/usr/bin/env python3
"""
Bruno ETL Executor - Production-grade orchestration for Scout Analytics
Executes deterministic ETL workflows with Temporal, dbt, and Great Expectations
"""

import os
import sys
import asyncio
import logging
import uuid
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
import json
import subprocess
from pathlib import Path

# Third-party imports
import click
from temporalio.client import Client
from temporalio.worker import Worker
import psycopg2
import great_expectations as gx
from opentelemetry import trace, metrics
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/Users/tbwa/scout-v7/etl/logs/bruno_executor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Configure OpenTelemetry
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Prometheus metrics
metric_reader = PrometheusMetricReader()
metrics.set_meter_provider(MeterProvider(metric_readers=[metric_reader]))
meter = metrics.get_meter(__name__)

# ETL Metrics
etl_rows_processed = meter.create_counter(
    "etl_rows_processed_total",
    description="Total number of rows processed by ETL pipeline",
    unit="rows"
)

etl_latency = meter.create_histogram(
    "etl_latency_seconds",
    description="ETL operation latency in seconds",
    unit="s"
)

etl_validation_failures = meter.create_counter(
    "etl_validation_failures_total",
    description="Total number of validation failures",
    unit="failures"
)

etl_job_status = meter.create_counter(
    "etl_job_status_total",
    description="ETL job status by layer and outcome",
    unit="jobs"
)


@dataclass
class BrunoConfig:
    """Bruno executor configuration"""
    postgres_url: str
    temporal_url: str = "localhost:7233"
    dbt_project_dir: str = "/Users/tbwa/scout-v7/dbt-scout"
    ge_config_dir: str = "/Users/tbwa/scout-v7/etl/quality"
    otel_config: str = "/Users/tbwa/scout-v7/etl/monitoring/opentelemetry_config.yml"
    max_parallel_jobs: int = 5
    dry_run: bool = False


class BrunoExecutor:
    """Production-grade ETL orchestration engine"""
    
    def __init__(self, config: BrunoConfig):
        self.config = config
        self.temporal_client: Optional[Client] = None
        self.postgres_conn: Optional[psycopg2.connection] = None
        self.ge_context: Optional[gx.DataContext] = None
        
    async def initialize(self):
        """Initialize all connections and contexts"""
        try:
            # Initialize Temporal client
            self.temporal_client = await Client.connect(self.config.temporal_url)
            logger.info(f"Connected to Temporal at {self.config.temporal_url}")
            
            # Initialize PostgreSQL connection
            self.postgres_conn = psycopg2.connect(self.config.postgres_url)
            logger.info("Connected to PostgreSQL database")
            
            # Initialize Great Expectations context
            os.chdir(self.config.ge_config_dir)
            self.ge_context = gx.get_context()
            logger.info("Initialized Great Expectations context")
            
            # Verify dbt installation and project
            result = subprocess.run(
                ["dbt", "--version"], 
                capture_output=True, 
                text=True, 
                cwd=self.config.dbt_project_dir
            )
            if result.returncode != 0:
                raise RuntimeError(f"dbt not available: {result.stderr}")
            
            logger.info(f"dbt version: {result.stdout.strip()}")
            
        except Exception as e:
            logger.error(f"Failed to initialize Bruno executor: {e}")
            raise
    
    async def run_bronze_ingestion(
        self, 
        source_name: str, 
        target_table: str,
        partition_key: Optional[str] = None
    ) -> Dict[str, Any]:
        """Execute bronze layer ingestion workflow"""
        
        with tracer.start_as_current_span("bronze_ingestion") as span:
            span.set_attributes({
                "etl.layer": "bronze",
                "etl.source_name": source_name,
                "etl.target_table": target_table,
                "etl.partition_key": partition_key or ""
            })
            
            start_time = datetime.utcnow()
            job_run_id = str(uuid.uuid4())
            
            try:
                logger.info(f"Starting bronze ingestion: {source_name} -> {target_table}")
                
                # Step 1: Validate data contracts using Great Expectations
                validation_result = await self._validate_contracts(source_name, partition_key)
                if not validation_result["success"]:
                    etl_validation_failures.add(1, {
                        "layer": "bronze",
                        "source": source_name,
                        "error_type": "contract_validation"
                    })
                    raise RuntimeError(f"Contract validation failed: {validation_result['errors']}")
                
                # Step 2: Execute Temporal workflow for ingestion
                if not self.config.dry_run:
                    from workflows.bronze_ingestion_workflow import BronzeIngestionWorkflow, IngestionConfig
                    
                    workflow_config = IngestionConfig(
                        source_name=source_name,
                        target_table=target_table,
                        contract_validation=True,
                        pii_masking=True
                    )
                    
                    workflow_result = await self.temporal_client.execute_workflow(
                        BronzeIngestionWorkflow.run,
                        workflow_config,
                        partition_key,
                        id=f"bronze_ingestion_{source_name}_{job_run_id}",
                        task_queue="scout-etl-queue"
                    )
                    
                    # Record metrics
                    etl_rows_processed.add(
                        workflow_result.records_processed,
                        {"layer": "bronze", "source": source_name}
                    )
                    
                else:
                    logger.info(f"DRY RUN: Would execute bronze ingestion for {source_name}")
                    workflow_result = type('obj', (object,), {
                        'success': True,
                        'records_processed': 1000,
                        'records_inserted': 950,
                        'job_run_id': job_run_id
                    })()
                
                # Step 3: Record completion metrics
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, {"layer": "bronze", "source": source_name})
                
                etl_job_status.add(1, {
                    "layer": "bronze",
                    "source": source_name,
                    "status": "success" if workflow_result.success else "failed"
                })
                
                span.set_attributes({
                    "etl.records_processed": workflow_result.records_processed,
                    "etl.records_inserted": workflow_result.records_inserted,
                    "etl.duration_seconds": duration,
                    "etl.success": workflow_result.success
                })
                
                logger.info(
                    f"Bronze ingestion completed: {workflow_result.records_processed} processed, "
                    f"{workflow_result.records_inserted} inserted in {duration:.2f}s"
                )
                
                return {
                    "success": workflow_result.success,
                    "job_run_id": workflow_result.job_run_id,
                    "records_processed": workflow_result.records_processed,
                    "records_inserted": workflow_result.records_inserted,
                    "duration_seconds": duration
                }
                
            except Exception as e:
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, {"layer": "bronze", "source": source_name})
                etl_job_status.add(1, {
                    "layer": "bronze", 
                    "source": source_name, 
                    "status": "failed"
                })
                
                span.record_exception(e)
                span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
                
                logger.error(f"Bronze ingestion failed: {e}")
                raise
    
    async def run_dbt_models(
        self, 
        layer: str, 
        models: Optional[List[str]] = None,
        partition_key: Optional[str] = None
    ) -> Dict[str, Any]:
        """Execute dbt transformations for Silver/Gold layers"""
        
        with tracer.start_as_current_span("dbt_transformation") as span:
            span.set_attributes({
                "etl.layer": layer,
                "etl.models": models or [],
                "etl.partition_key": partition_key or ""
            })
            
            start_time = datetime.utcnow()
            job_run_id = str(uuid.uuid4())
            
            try:
                logger.info(f"Starting dbt transformation for {layer} layer")
                
                # Build dbt command
                dbt_cmd = ["dbt", "run"]
                
                if models:
                    dbt_cmd.extend(["--select"] + models)
                else:
                    dbt_cmd.extend(["--select", f"tag:{layer}"])
                
                # Add variables
                dbt_vars = {
                    "job_run_id": job_run_id,
                    "ds": partition_key or datetime.utcnow().strftime("%Y-%m-%d"),
                    "emit_lineage_events": True
                }
                dbt_cmd.extend(["--vars", json.dumps(dbt_vars)])
                
                # Execute dbt run
                if not self.config.dry_run:
                    result = subprocess.run(
                        dbt_cmd,
                        cwd=self.config.dbt_project_dir,
                        capture_output=True,
                        text=True,
                        timeout=3600  # 1 hour timeout
                    )
                    
                    if result.returncode != 0:
                        raise RuntimeError(f"dbt run failed: {result.stderr}")
                    
                    logger.info(f"dbt run output: {result.stdout}")
                    
                    # Run dbt tests
                    test_cmd = ["dbt", "test", "--select", f"tag:{layer}"]
                    test_result = subprocess.run(
                        test_cmd,
                        cwd=self.config.dbt_project_dir,
                        capture_output=True,
                        text=True,
                        timeout=1800  # 30 minutes timeout
                    )
                    
                    if test_result.returncode != 0:
                        logger.warning(f"dbt tests failed: {test_result.stderr}")
                        # Don't fail the entire job for test failures, but log them
                        etl_validation_failures.add(1, {
                            "layer": layer,
                            "source": "dbt_tests",
                            "error_type": "test_failure"
                        })
                    
                else:
                    logger.info(f"DRY RUN: Would execute dbt for {layer} layer with models: {models}")
                    result = type('obj', (object,), {'returncode': 0, 'stdout': 'DRY RUN SUCCESS'})()
                
                # Parse dbt results for metrics
                records_processed = self._parse_dbt_results(result.stdout) if not self.config.dry_run else 1000
                
                # Record metrics
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, {"layer": layer, "source": "dbt"})
                etl_rows_processed.add(records_processed, {"layer": layer, "source": "dbt"})
                etl_job_status.add(1, {"layer": layer, "source": "dbt", "status": "success"})
                
                span.set_attributes({
                    "etl.records_processed": records_processed,
                    "etl.duration_seconds": duration,
                    "etl.success": True
                })
                
                logger.info(f"dbt {layer} transformation completed in {duration:.2f}s")
                
                return {
                    "success": True,
                    "job_run_id": job_run_id,
                    "layer": layer,
                    "models_executed": models or [f"tag:{layer}"],
                    "records_processed": records_processed,
                    "duration_seconds": duration
                }
                
            except Exception as e:
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, {"layer": layer, "source": "dbt"})
                etl_job_status.add(1, {"layer": layer, "source": "dbt", "status": "failed"})
                
                span.record_exception(e)
                span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
                
                logger.error(f"dbt {layer} transformation failed: {e}")
                raise
    
    async def _validate_contracts(self, source_name: str, partition_key: Optional[str]) -> Dict[str, Any]:
        """Validate data contracts using Great Expectations"""
        
        try:
            # Get expectation suite for source
            suite_name = f"{source_name.replace('.', '_')}_bronze"
            
            if not self.config.dry_run:
                # Run Great Expectations validation
                batch_request = {
                    "datasource_name": "scout_postgres",
                    "data_connector_name": "azure_data_connector",
                    "data_asset_name": source_name.split('.')[-1]
                }
                
                validator = self.ge_context.get_validator(
                    batch_request=batch_request,
                    expectation_suite_name=suite_name
                )
                
                validation_result = validator.validate()
                
                success = validation_result.success
                errors = [
                    expectation["expectation_config"]["kwargs"]
                    for expectation in validation_result.results
                    if not expectation["success"]
                ]
                
            else:
                logger.info(f"DRY RUN: Would validate contracts for {source_name}")
                success = True
                errors = []
            
            return {
                "success": success,
                "errors": errors,
                "suite_name": suite_name
            }
            
        except Exception as e:
            logger.error(f"Contract validation failed: {e}")
            return {
                "success": False,
                "errors": [str(e)],
                "suite_name": suite_name
            }
    
    def _parse_dbt_results(self, dbt_output: str) -> int:
        """Parse dbt output to extract metrics"""
        # Simple parsing - in production, would use dbt artifacts
        try:
            lines = dbt_output.split('\n')
            for line in lines:
                if 'rows affected' in line.lower():
                    # Extract number from line like "1234 rows affected"
                    parts = line.split()
                    for part in parts:
                        if part.isdigit():
                            return int(part)
            return 0
        except Exception:
            return 0
    
    async def run_full_pipeline(self, partition_key: Optional[str] = None) -> Dict[str, Any]:
        """Execute full ETL pipeline: Bronze -> Silver -> Gold"""
        
        with tracer.start_as_current_span("full_pipeline") as span:
            span.set_attributes({
                "etl.pipeline": "full",
                "etl.partition_key": partition_key or ""
            })
            
            start_time = datetime.utcnow()
            results = {}
            
            try:
                # Step 1: Bronze ingestion
                bronze_result = await self.run_bronze_ingestion(
                    "azure.interactions",
                    "scout.bronze_transactions",
                    partition_key
                )
                results["bronze"] = bronze_result
                
                if not bronze_result["success"]:
                    raise RuntimeError("Bronze ingestion failed")
                
                # Step 2: Silver transformation
                silver_result = await self.run_dbt_models(
                    "silver",
                    ["silver_interactions"],
                    partition_key
                )
                results["silver"] = silver_result
                
                if not silver_result["success"]:
                    raise RuntimeError("Silver transformation failed")
                
                # Step 3: Gold analytics
                gold_result = await self.run_dbt_models(
                    "gold",
                    ["gold_executive_kpis"],
                    partition_key
                )
                results["gold"] = gold_result
                
                # Calculate total metrics
                total_duration = (datetime.utcnow() - start_time).total_seconds()
                total_records = sum(r.get("records_processed", 0) for r in results.values())
                
                span.set_attributes({
                    "etl.total_duration_seconds": total_duration,
                    "etl.total_records_processed": total_records,
                    "etl.success": True
                })
                
                logger.info(
                    f"Full pipeline completed: {total_records} records processed "
                    f"in {total_duration:.2f}s"
                )
                
                return {
                    "success": True,
                    "total_duration_seconds": total_duration,
                    "total_records_processed": total_records,
                    "layer_results": results
                }
                
            except Exception as e:
                span.record_exception(e)
                span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
                
                logger.error(f"Full pipeline failed: {e}")
                results["error"] = str(e)
                
                return {
                    "success": False,
                    "error": str(e),
                    "layer_results": results
                }
    
    async def run_drive_ingestion(
        self,
        folder_id: str,
        folder_name: str,
        incremental: bool = True
    ) -> Dict[str, Any]:
        """Execute Google Drive ETL ingestion workflow"""
        
        with tracer.start_as_current_span("drive_ingestion") as span:
            span.set_attributes({
                "etl.folder_id": folder_id,
                "etl.folder_name": folder_name,
                "etl.incremental": incremental
            })
            
            start_time = datetime.utcnow()
            
            try:
                logger.info(f"Starting Google Drive ingestion for folder: {folder_name}")
                
                if not self.config.dry_run:
                    from workflows.drive_ingestion_workflow import DriveIngestionWorkflow, DriveIngestionConfig
                    
                    workflow_config = DriveIngestionConfig(
                        folder_id=folder_id,
                        folder_name=folder_name,
                        file_types=['pdf', 'docx', 'xlsx', 'pptx'],
                        include_metadata=True,
                        sync_deleted=True,
                        batch_size=30,
                        quality_validation=True
                    )
                    
                    workflow_result = await self.temporal_client.execute_workflow(
                        DriveIngestionWorkflow.run,
                        workflow_config,
                        incremental,
                        id=f"drive_ingestion_{folder_id}_{start_time.strftime('%Y%m%d_%H%M%S')}",
                        task_queue="scout-etl-queue",
                        execution_timeout=timedelta(hours=2)
                    )
                else:
                    # Dry run simulation
                    logger.info("DRY RUN: Would execute Google Drive ingestion workflow")
                    workflow_result = type('MockResult', (), {
                        'success': True,
                        'files_processed': 50,
                        'files_synced': 45,
                        'files_failed': 5,
                        'bytes_transferred': 1024*1024*100,  # 100MB
                        'job_run_id': 'dry-run-drive-' + str(uuid.uuid4())
                    })()
                
                duration = (datetime.utcnow() - start_time).total_seconds()
                
                # Record metrics
                etl_latency.record(duration, {"layer": "drive", "folder": folder_name})
                etl_rows_processed.add(workflow_result.files_processed, {"layer": "drive"})
                
                etl_job_status.add(1, {
                    "layer": "drive",
                    "source": folder_name,
                    "status": "success" if workflow_result.success else "failed"
                })
                
                span.set_attributes({
                    "etl.files_processed": workflow_result.files_processed,
                    "etl.files_synced": workflow_result.files_synced,
                    "etl.duration_seconds": duration,
                    "etl.success": workflow_result.success
                })
                
                logger.info(
                    f"Google Drive ingestion completed: {workflow_result.files_processed} processed, "
                    f"{workflow_result.files_synced} synced in {duration:.2f}s"
                )
                
                return {
                    "success": workflow_result.success,
                    "job_run_id": workflow_result.job_run_id,
                    "files_processed": workflow_result.files_processed,
                    "files_synced": workflow_result.files_synced,
                    "files_failed": workflow_result.files_failed,
                    "bytes_transferred": workflow_result.bytes_transferred,
                    "duration_seconds": duration
                }
                
            except Exception as e:
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, {"layer": "drive", "folder": folder_name})
                etl_job_status.add(1, {
                    "layer": "drive", 
                    "source": folder_name, 
                    "status": "failed"
                })
                
                span.record_exception(e)
                span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))
                
                logger.error(f"Google Drive ingestion failed: {e}")
                raise
    
    async def run_drive_to_bucket_sync(
        self,
        folder_id: str,
        bucket: str,
        path: str,
        batch_size: int,
        concurrent_downloads: int,
        incremental: bool
    ) -> Dict[str, Any]:
        """Execute Google Drive to bucket sync workflow"""
        
        with tracer.start_as_current_span("drive_to_bucket_sync") as span:
            span.set_attributes({
                "etl.folder_id": folder_id,
                "etl.bucket": bucket,
                "etl.path": path,
                "etl.incremental": incremental
            })
            
            start_time = datetime.utcnow()
            
            try:
                logger.info(f"Starting Drive to bucket sync: {folder_id} → {bucket}/{path}")
                
                if not self.config.dry_run:
                    from workflows.drive_to_bucket_workflow import DriveToBucketSyncWorkflow, DriveToBucketConfig
                    
                    workflow_config = DriveToBucketConfig(
                        drive_folder_id=folder_id,
                        bucket_name=bucket,
                        bucket_path=path,
                        batch_size=batch_size,
                        concurrent_downloads=concurrent_downloads,
                        incremental_sync=incremental,
                        validation_enabled=True,
                        duplicate_detection=True,
                        postgres_url=self.config.postgres_url,
                        supabase_url=os.getenv('SUPABASE_URL', ''),
                        supabase_key=os.getenv('SUPABASE_SERVICE_ROLE_KEY', ''),
                        google_credentials=json.loads(os.getenv('GOOGLE_SERVICE_ACCOUNT_JSON', '{}'))
                    )
                    
                    result = await self.temporal_client.execute_workflow(
                        DriveToBucketSyncWorkflow.run,
                        workflow_config,
                        id=f"drive_to_bucket_{folder_id}_{start_time.strftime('%Y%m%d_%H%M%S')}",
                        task_queue="scout-etl-queue",
                        execution_timeout=timedelta(hours=2)
                    )
                else:
                    logger.info("DRY RUN: Would execute Drive to bucket sync workflow")
                    result = {
                        "job_id": f"dry_run_{start_time.isoformat()}",
                        "total_files": 0,
                        "succeeded_files": 0,
                        "failed_files": 0
                    }
                
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, attributes={"operation": "drive_to_bucket_sync"})
                
                logger.info(f"Drive to bucket sync completed in {duration:.2f}s")
                
                return {
                    "success": True,
                    "job_id": result.get("job_id"),
                    "files_synced": result.get("succeeded_files", 0),
                    "files_failed": result.get("failed_files", 0),
                    "duration_seconds": duration
                }
                
            except Exception as e:
                logger.error(f"Drive to bucket sync failed: {e}")
                raise
    
    async def run_bucket_to_bronze_processing(
        self,
        bucket: str,
        path: str,
        batch_size: int,
        max_workers: int,
        quality_threshold: float,
        enable_validation: bool,
        enable_deduplication: bool
    ) -> Dict[str, Any]:
        """Execute bucket to Bronze processing workflow"""
        
        with tracer.start_as_current_span("bucket_to_bronze_processing") as span:
            span.set_attributes({
                "etl.bucket": bucket,
                "etl.path": path,
                "etl.validation_enabled": enable_validation
            })
            
            start_time = datetime.utcnow()
            
            try:
                logger.info(f"Starting bucket to Bronze processing: {bucket}/{path}")
                
                if not self.config.dry_run:
                    from workflows.bucket_to_bronze_workflow import BucketToBronzeWorkflow, BucketToBronzeConfig
                    
                    workflow_config = BucketToBronzeConfig(
                        bucket_name=bucket,
                        bucket_path=path,
                        batch_size=batch_size,
                        max_parallel_workers=max_workers,
                        validation_enabled=enable_validation,
                        deduplication_enabled=enable_deduplication,
                        quality_threshold=quality_threshold,
                        postgres_url=self.config.postgres_url,
                        supabase_url=os.getenv('SUPABASE_URL', ''),
                        supabase_key=os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')
                    )
                    
                    result = await self.temporal_client.execute_workflow(
                        BucketToBronzeWorkflow.run,
                        workflow_config,
                        id=f"bucket_to_bronze_{bucket}_{start_time.strftime('%Y%m%d_%H%M%S')}",
                        task_queue="scout-etl-queue",
                        execution_timeout=timedelta(hours=3)
                    )
                else:
                    logger.info("DRY RUN: Would execute bucket to Bronze processing workflow")
                    result = {
                        "total_files": 0,
                        "successful_files": 0,
                        "failed_files": 0,
                        "total_transactions": 0
                    }
                
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, attributes={"operation": "bucket_to_bronze"})
                
                # Record metrics
                etl_rows_processed.add(
                    result.get("total_transactions", 0),
                    attributes={"layer": "bronze", "source": "bucket"}
                )
                
                logger.info(f"Bucket to Bronze processing completed in {duration:.2f}s")
                
                return {
                    "success": True,
                    "files_processed": result.get("total_files", 0),
                    "files_successful": result.get("successful_files", 0),
                    "files_failed": result.get("failed_files", 0),
                    "transactions_loaded": result.get("total_transactions", 0),
                    "unique_devices": result.get("unique_devices", 0),
                    "avg_quality_score": result.get("avg_quality_score", 0.0),
                    "duration_seconds": duration
                }
                
            except Exception as e:
                logger.error(f"Bucket to Bronze processing failed: {e}")
                raise
    
    async def run_scout_edge_pipeline(
        self,
        folder_id: str,
        bucket: str,
        incremental: bool,
        skip_bronze: bool,
        skip_silver: bool,
        skip_gold: bool
    ) -> Dict[str, Any]:
        """Execute full Scout Edge pipeline: Drive → Bucket → Bronze → Silver → Gold"""
        
        with tracer.start_as_current_span("scout_edge_pipeline") as span:
            span.set_attributes({
                "etl.folder_id": folder_id,
                "etl.bucket": bucket,
                "etl.incremental": incremental,
                "etl.full_pipeline": True
            })
            
            start_time = datetime.utcnow()
            pipeline_results = {}
            
            try:
                logger.info(f"Starting full Scout Edge pipeline for folder: {folder_id}")
                
                # Step 1: Drive to Bucket Sync
                logger.info("Phase 1: Google Drive to Bucket sync")
                drive_result = await self.run_drive_to_bucket_sync(
                    folder_id=folder_id,
                    bucket=bucket,
                    path="edge-transactions/",
                    batch_size=50,
                    concurrent_downloads=5,
                    incremental=incremental
                )
                pipeline_results["drive_to_bucket"] = drive_result
                
                if not drive_result["success"]:
                    raise Exception("Drive to bucket sync failed")
                
                # Step 2: Bucket to Bronze Processing (unless skipped)
                if not skip_bronze:
                    logger.info("Phase 2: Bucket to Bronze processing")
                    bronze_result = await self.run_bucket_to_bronze_processing(
                        bucket=bucket,
                        path="edge-transactions/",
                        batch_size=100,
                        max_workers=5,
                        quality_threshold=0.7,
                        enable_validation=True,
                        enable_deduplication=True
                    )
                    pipeline_results["bucket_to_bronze"] = bronze_result
                    
                    if not bronze_result["success"]:
                        raise Exception("Bucket to Bronze processing failed")
                else:
                    logger.info("Phase 2: Skipping Bronze processing")
                    pipeline_results["bucket_to_bronze"] = {"skipped": True}
                
                # Step 3: Silver Transformations (unless skipped)
                if not skip_silver:
                    logger.info("Phase 3: Silver layer transformations")
                    silver_result = await self.run_dbt_models(
                        layer="silver",
                        model_list=["silver_scout_edge_unified"],
                        partition_key=None
                    )
                    pipeline_results["silver_transformations"] = silver_result
                else:
                    logger.info("Phase 3: Skipping Silver transformations")
                    pipeline_results["silver_transformations"] = {"skipped": True}
                
                # Step 4: Gold Analytics (unless skipped)
                if not skip_gold:
                    logger.info("Phase 4: Gold layer analytics")
                    gold_result = await self.run_dbt_models(
                        layer="gold",
                        model_list=["gold_scout_edge_analytics", "gold_unified_brand_intelligence"],
                        partition_key=None
                    )
                    pipeline_results["gold_analytics"] = gold_result
                else:
                    logger.info("Phase 4: Skipping Gold analytics")
                    pipeline_results["gold_analytics"] = {"skipped": True}
                
                duration = (datetime.utcnow() - start_time).total_seconds()
                etl_latency.record(duration, attributes={"operation": "scout_edge_pipeline"})
                
                logger.info(f"Scout Edge pipeline completed in {duration:.2f}s")
                
                # Calculate total metrics
                total_files_synced = drive_result.get("files_synced", 0)
                total_transactions = pipeline_results.get("bucket_to_bronze", {}).get("transactions_loaded", 0)
                
                return {
                    "success": True,
                    "pipeline": "scout_edge_full",
                    "total_files_synced": total_files_synced,
                    "total_transactions_loaded": total_transactions,
                    "phases_completed": len([r for r in pipeline_results.values() if not r.get("skipped", False)]),
                    "duration_seconds": duration,
                    "phase_results": pipeline_results
                }
                
            except Exception as e:
                logger.error(f"Scout Edge pipeline failed: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "phase_results": pipeline_results
                }

    async def cleanup(self):
        """Cleanup connections"""
        if self.postgres_conn:
            self.postgres_conn.close()
        if self.temporal_client:
            # Temporal client cleanup is automatic
            pass


# CLI Interface
@click.group()
@click.option('--dry-run', is_flag=True, help='Perform dry run without executing operations')
@click.option('--postgres-url', envvar='POSTGRES_URL', required=True, help='PostgreSQL connection URL')
@click.option('--temporal-url', default='localhost:7233', help='Temporal server URL')
@click.pass_context
def cli(ctx, dry_run, postgres_url, temporal_url):
    """Bruno ETL Executor - Production-grade orchestration for Scout Analytics"""
    config = BrunoConfig(
        postgres_url=postgres_url,
        temporal_url=temporal_url,
        dry_run=dry_run
    )
    ctx.obj = config


@cli.command()
@click.option('--source', required=True, help='Source name (e.g., azure.interactions)')
@click.option('--target', required=True, help='Target table (e.g., scout.bronze_transactions)')
@click.option('--partition', help='Partition key (e.g., 2025-01-16)')
@click.pass_context
def bronze(ctx, source, target, partition):
    """Execute bronze layer ingestion"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            result = await executor.run_bronze_ingestion(source, target, partition)
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


@cli.command()
@click.option('--layer', required=True, type=click.Choice(['silver', 'gold', 'platinum']))
@click.option('--models', help='Comma-separated list of models to run')
@click.option('--partition', help='Partition key (e.g., 2025-01-16)')
@click.pass_context
def dbt(ctx, layer, models, partition):
    """Execute dbt transformations"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            model_list = models.split(',') if models else None
            result = await executor.run_dbt_models(layer, model_list, partition)
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


@cli.command()
@click.option('--partition', help='Partition key (e.g., 2025-01-16)')
@click.pass_context
def pipeline(ctx, partition):
    """Execute full ETL pipeline"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            result = await executor.run_full_pipeline(partition)
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


@cli.command()
@click.option('--folder-id', required=True, help='Google Drive folder ID')
@click.option('--folder-name', required=True, help='Google Drive folder name')
@click.option('--incremental/--full', default=True, help='Incremental sync (default) or full sync')
@click.pass_context
def drive(ctx, folder_id, folder_name, incremental):
    """Execute Google Drive ETL ingestion"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            result = await executor.run_drive_ingestion(folder_id, folder_name, incremental)
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


@cli.command()
@click.option('--folder-id', default='1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA', help='Google Drive folder ID')
@click.option('--bucket', default='scout-ingest', help='Supabase bucket name')
@click.option('--path', default='edge-transactions/', help='Bucket path prefix')
@click.option('--batch-size', default=50, help='Number of files to process per batch')
@click.option('--concurrent-downloads', default=5, help='Number of concurrent downloads')
@click.option('--incremental/--full', default=True, help='Incremental sync (default) or full sync')
@click.pass_context
def drive_to_bucket(ctx, folder_id, bucket, path, batch_size, concurrent_downloads, incremental):
    """Sync Google Drive folder to Supabase bucket storage"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            result = await executor.run_drive_to_bucket_sync(
                folder_id, bucket, path, batch_size, concurrent_downloads, incremental
            )
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


@cli.command()
@click.option('--bucket', default='scout-ingest', help='Supabase bucket name')
@click.option('--path', default='edge-transactions/', help='Bucket path to process')
@click.option('--batch-size', default=100, help='Number of files to process per batch')
@click.option('--max-workers', default=5, help='Maximum parallel workers')
@click.option('--quality-threshold', default=0.7, help='Minimum quality threshold for processing')
@click.option('--enable-validation/--disable-validation', default=True, help='Enable file validation')
@click.option('--enable-deduplication/--disable-deduplication', default=True, help='Enable duplicate detection')
@click.pass_context
def bucket_to_bronze(ctx, bucket, path, batch_size, max_workers, quality_threshold, enable_validation, enable_deduplication):
    """Process bucket files to Bronze layer"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            result = await executor.run_bucket_to_bronze_processing(
                bucket, path, batch_size, max_workers, quality_threshold, 
                enable_validation, enable_deduplication
            )
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


@cli.command()
@click.option('--folder-id', default='1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA', help='Google Drive folder ID')
@click.option('--bucket', default='scout-ingest', help='Supabase bucket name')
@click.option('--incremental/--full', default=True, help='Incremental processing')
@click.option('--skip-bronze', is_flag=True, help='Skip Bronze processing')
@click.option('--skip-silver', is_flag=True, help='Skip Silver transformations')
@click.option('--skip-gold', is_flag=True, help='Skip Gold transformations')
@click.pass_context
def scout_pipeline(ctx, folder_id, bucket, incremental, skip_bronze, skip_silver, skip_gold):
    """Execute full Scout Edge pipeline: Drive → Bucket → Bronze → Silver → Gold"""
    async def run():
        executor = BrunoExecutor(ctx.obj)
        await executor.initialize()
        try:
            result = await executor.run_scout_edge_pipeline(
                folder_id, bucket, incremental, skip_bronze, skip_silver, skip_gold
            )
            click.echo(json.dumps(result, indent=2))
        finally:
            await executor.cleanup()
    
    asyncio.run(run())


if __name__ == '__main__':
    cli()