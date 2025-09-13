#!/usr/bin/env python3
"""
DataOS Docs Extractor API Server
RESTful API for documentation extraction and diff operations
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.responses import JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, HttpUrl
from typing import Optional, List, Dict, Any
from datetime import datetime
import asyncio
import os
import json
from pathlib import Path
import logging

# Import main extractor components
from main import (
    DataOSDocsExtractor,
    ExtractionConfig,
    ExtractionMethod,
    OutputFormat,
    DiffMode,
    DocumentExtractor,
    DiffEngine,
    ChangeAnalyzer
)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('dataos-api')

# Initialize FastAPI app
app = FastAPI(
    title="DataOS Documentation Extractor API",
    description="Automated extraction, archiving, and version comparison of web-based documentation",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global extractor instance
extractor = DataOSDocsExtractor()

# Pydantic models for API
class ExtractionRequest(BaseModel):
    source_url: HttpUrl = Field(..., description="Documentation homepage URL")
    output_format: str = Field("markdown", description="Output format: html, markdown, pdf, all")
    extraction_method: str = Field("hybrid", description="Method: static, dynamic, hybrid")
    auth: Optional[Dict[str, Any]] = Field(None, description="Authentication credentials")
    max_depth: int = Field(10, description="Maximum crawl depth")
    max_pages: int = Field(10000, description="Maximum pages to extract")
    
    class Config:
        schema_extra = {
            "example": {
                "source_url": "https://dataos.info",
                "output_format": "markdown",
                "extraction_method": "hybrid"
            }
        }

class DiffRequest(BaseModel):
    archive1: str = Field(..., description="Path to first archive")
    archive2: str = Field(..., description="Path to second archive") 
    mode: str = Field("both", description="Diff mode: semantic, visual, both, none")
    
    class Config:
        schema_extra = {
            "example": {
                "archive1": "/dataos-archives/20240807",
                "archive2": "/dataos-archives/20240808",
                "mode": "both"
            }
        }

class ScheduleRequest(BaseModel):
    source_url: HttpUrl = Field(..., description="Documentation URL to monitor")
    cron: str = Field(..., description="Cron expression for scheduling")
    output_format: str = Field("markdown", description="Output format")
    notifications: Optional[List[Dict[str, str]]] = Field(None, description="Notification channels")
    
    class Config:
        schema_extra = {
            "example": {
                "source_url": "https://dataos.info",
                "cron": "0 2 * * *",
                "output_format": "markdown",
                "notifications": [
                    {"type": "webhook", "url": "https://hooks.example.com/docs-update"}
                ]
            }
        }

class ExtractionResponse(BaseModel):
    status: str
    task_id: str
    archive_path: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None
    message: Optional[str] = None

class DiffResponse(BaseModel):
    status: str
    diff_result: Optional[Dict[str, Any]] = None
    analytics: Optional[Dict[str, Any]] = None
    semantic_diff_path: Optional[str] = None
    visual_diff_path: Optional[str] = None

class AnalyticsResponse(BaseModel):
    status: str
    analytics: Dict[str, Any]
    report_path: Optional[str] = None

# In-memory task storage (use Redis in production)
tasks = {}

@app.get("/")
async def root():
    """API root endpoint"""
    return {
        "name": "DataOS Documentation Extractor API",
        "version": "1.0.0",
        "endpoints": {
            "extract": "/api/extract",
            "diff": "/api/diff",
            "analyze": "/api/analyze",
            "schedule": "/api/schedule",
            "archives": "/api/archives",
            "tasks": "/api/tasks/{task_id}"
        }
    }

@app.post("/api/extract", response_model=ExtractionResponse)
async def extract_documentation(
    request: ExtractionRequest,
    background_tasks: BackgroundTasks
):
    """
    Extract documentation from a web source
    
    This endpoint starts an asynchronous extraction task and returns immediately
    with a task ID. Use the task ID to check extraction status.
    """
    # Generate task ID
    task_id = f"extract_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{hash(request.source_url)}"
    
    # Initialize task
    tasks[task_id] = {
        "status": "pending",
        "started_at": datetime.now().isoformat(),
        "request": request.dict()
    }
    
    # Start extraction in background
    background_tasks.add_task(
        run_extraction,
        task_id,
        request
    )
    
    return ExtractionResponse(
        status="accepted",
        task_id=task_id,
        message="Extraction task started. Check /api/tasks/{task_id} for status."
    )

async def run_extraction(task_id: str, request: ExtractionRequest):
    """Background task for extraction"""
    try:
        tasks[task_id]["status"] = "running"
        
        # Create config
        config = ExtractionConfig(
            source_url=str(request.source_url),
            output_format=OutputFormat(request.output_format),
            extraction_method=ExtractionMethod(request.extraction_method),
            auth=request.auth,
            max_depth=request.max_depth,
            max_pages=request.max_pages
        )
        
        # Run extraction
        extractor = DocumentExtractor(config)
        archive_path, metadata = await extractor.extract()
        
        # Update task
        tasks[task_id].update({
            "status": "completed",
            "completed_at": datetime.now().isoformat(),
            "result": {
                "archive_path": archive_path,
                "metadata": metadata.__dict__ if hasattr(metadata, '__dict__') else metadata
            }
        })
        
    except Exception as e:
        tasks[task_id].update({
            "status": "failed",
            "error": str(e),
            "completed_at": datetime.now().isoformat()
        })
        logger.error(f"Extraction task {task_id} failed: {e}")

@app.post("/api/diff", response_model=DiffResponse)
async def compute_diff(request: DiffRequest):
    """
    Compute semantic and/or visual diff between two archives
    """
    try:
        # Validate archives exist
        if not os.path.exists(request.archive1):
            raise HTTPException(404, f"Archive not found: {request.archive1}")
        if not os.path.exists(request.archive2):
            raise HTTPException(404, f"Archive not found: {request.archive2}")
            
        # Run diff
        diff_engine = DiffEngine()
        diff_result = await diff_engine.compute_diff(
            request.archive1,
            request.archive2,
            DiffMode(request.mode)
        )
        
        # Analyze changes
        analyzer = ChangeAnalyzer()
        analytics = analyzer.analyze(diff_result)
        
        return DiffResponse(
            status="success",
            diff_result=diff_result.__dict__ if hasattr(diff_result, '__dict__') else diff_result,
            analytics=analytics,
            semantic_diff_path=diff_result.semantic_diff_path,
            visual_diff_path=diff_result.visual_diff_path
        )
        
    except Exception as e:
        logger.error(f"Diff computation failed: {e}")
        raise HTTPException(500, str(e))

@app.get("/api/archives")
async def list_archives(
    limit: int = 10,
    offset: int = 0,
    source_url: Optional[str] = None
):
    """
    List available documentation archives
    """
    archive_base = "/dataos-archives"
    archives = []
    
    if not os.path.exists(archive_base):
        return {"archives": [], "total": 0}
        
    # Get all archive directories
    for archive_dir in sorted(Path(archive_base).iterdir(), reverse=True):
        if archive_dir.is_dir() and not archive_dir.name.startswith('.'):
            metadata_path = archive_dir / "metadata.json"
            
            if metadata_path.exists():
                with open(metadata_path, 'r') as f:
                    metadata = json.load(f)
                    
                # Filter by source URL if provided
                if source_url and metadata.get('source_url') != source_url:
                    continue
                    
                archives.append({
                    "path": str(archive_dir),
                    "timestamp": metadata.get('timestamp'),
                    "source_url": metadata.get('source_url'),
                    "total_pages": metadata.get('total_pages'),
                    "format": metadata.get('format')
                })
    
    # Apply pagination
    total = len(archives)
    archives = archives[offset:offset + limit]
    
    return {
        "archives": archives,
        "total": total,
        "limit": limit,
        "offset": offset
    }

@app.get("/api/archives/{archive_date}")
async def get_archive_details(archive_date: str):
    """
    Get details about a specific archive
    """
    archive_path = f"/dataos-archives/{archive_date}"
    
    if not os.path.exists(archive_path):
        raise HTTPException(404, "Archive not found")
        
    metadata_path = os.path.join(archive_path, "metadata.json")
    
    if not os.path.exists(metadata_path):
        raise HTTPException(404, "Archive metadata not found")
        
    with open(metadata_path, 'r') as f:
        metadata = json.load(f)
        
    # Get file listing
    files = []
    for file_path in Path(archive_path).rglob('*'):
        if file_path.is_file() and file_path.name != 'metadata.json':
            files.append({
                "path": str(file_path.relative_to(archive_path)),
                "size": file_path.stat().st_size,
                "modified": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat()
            })
    
    return {
        "archive_path": archive_path,
        "metadata": metadata,
        "files": files,
        "file_count": len(files)
    }

@app.get("/api/archives/{archive_date}/download")
async def download_archive(archive_date: str, format: str = "tar.gz"):
    """
    Download archive as compressed file
    """
    archive_path = f"/dataos-archives/{archive_date}"
    
    if not os.path.exists(archive_path):
        raise HTTPException(404, "Archive not found")
        
    # Create compressed archive
    import tarfile
    import tempfile
    
    with tempfile.NamedTemporaryFile(suffix=f'.{format}', delete=False) as tmp:
        with tarfile.open(tmp.name, 'w:gz') as tar:
            tar.add(archive_path, arcname=archive_date)
            
        return FileResponse(
            tmp.name,
            media_type='application/gzip',
            filename=f'dataos_archive_{archive_date}.tar.gz'
        )

@app.post("/api/analyze")
async def analyze_archive(archive_path: str):
    """
    Analyze a documentation archive
    """
    if not os.path.exists(archive_path):
        raise HTTPException(404, "Archive not found")
        
    try:
        # Load metadata
        metadata_path = os.path.join(archive_path, 'metadata.json')
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
            
        # Analyze content
        from main import DataOSDocsExtractor
        extractor = DataOSDocsExtractor()
        analysis = extractor._analyze_content(archive_path)
        
        analytics = {
            'archive': archive_path,
            'timestamp': datetime.now().isoformat(),
            'source_url': metadata['source_url'],
            'extraction_date': metadata['timestamp'],
            'statistics': {
                'total_pages': metadata['total_pages'],
                'extraction_time': metadata['extraction_time'],
                'format': metadata['format']
            },
            'content_analysis': analysis
        }
        
        # Save analytics
        analytics_path = os.path.join(archive_path, 'analytics.json')
        with open(analytics_path, 'w') as f:
            json.dump(analytics, f, indent=2)
            
        return AnalyticsResponse(
            status="success",
            analytics=analytics,
            report_path=analytics_path
        )
        
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        raise HTTPException(500, str(e))

@app.get("/api/tasks/{task_id}")
async def get_task_status(task_id: str):
    """
    Get status of an extraction task
    """
    if task_id not in tasks:
        raise HTTPException(404, "Task not found")
        
    return tasks[task_id]

@app.post("/api/schedule")
async def schedule_extraction(request: ScheduleRequest):
    """
    Schedule regular documentation extraction
    """
    # In production, this would integrate with a job scheduler
    # For now, we'll store the schedule configuration
    
    schedule_id = f"schedule_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    schedule_config = {
        "id": schedule_id,
        "source_url": str(request.source_url),
        "cron": request.cron,
        "output_format": request.output_format,
        "notifications": request.notifications,
        "created_at": datetime.now().isoformat(),
        "active": True
    }
    
    # Save schedule (in production, use database)
    schedules_dir = "/dataos-archives/schedules"
    os.makedirs(schedules_dir, exist_ok=True)
    
    with open(f"{schedules_dir}/{schedule_id}.json", 'w') as f:
        json.dump(schedule_config, f, indent=2)
        
    return {
        "status": "success",
        "schedule_id": schedule_id,
        "message": f"Extraction scheduled for {request.source_url} with cron: {request.cron}"
    }

@app.get("/api/schedules")
async def list_schedules():
    """
    List all scheduled extractions
    """
    schedules_dir = "/dataos-archives/schedules"
    schedules = []
    
    if os.path.exists(schedules_dir):
        for schedule_file in Path(schedules_dir).glob("*.json"):
            with open(schedule_file, 'r') as f:
                schedule = json.load(f)
                schedules.append(schedule)
                
    return {
        "schedules": schedules,
        "total": len(schedules)
    }

@app.delete("/api/schedules/{schedule_id}")
async def delete_schedule(schedule_id: str):
    """
    Delete a scheduled extraction
    """
    schedule_path = f"/dataos-archives/schedules/{schedule_id}.json"
    
    if not os.path.exists(schedule_path):
        raise HTTPException(404, "Schedule not found")
        
    os.remove(schedule_path)
    
    return {
        "status": "success",
        "message": f"Schedule {schedule_id} deleted"
    }

@app.get("/api/diffs")
async def list_diffs(limit: int = 10, offset: int = 0):
    """
    List available diff reports
    """
    diffs_dir = "/dataos-archives/diffs"
    diffs = []
    
    if os.path.exists(diffs_dir):
        for diff_dir in sorted(Path(diffs_dir).iterdir(), reverse=True):
            if diff_dir.is_dir():
                # Parse diff directory name
                parts = diff_dir.name.split('_vs_')
                if len(parts) >= 2:
                    diffs.append({
                        "path": str(diff_dir),
                        "archive1": parts[0],
                        "archive2": parts[1].split('_')[0],
                        "timestamp": diff_dir.stat().st_mtime
                    })
    
    # Apply pagination
    total = len(diffs)
    diffs = diffs[offset:offset + limit]
    
    return {
        "diffs": diffs,
        "total": total,
        "limit": limit,
        "offset": offset
    }

@app.get("/health")
async def health_check():
    """
    Health check endpoint
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Global exception handler
    """
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "message": str(exc),
            "type": type(exc).__name__
        }
    )

# Run server if executed directly
if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )