#!/usr/bin/env python3
"""
Agent Savage - Brand-Aligned Pattern & Visualization Generator
FastAPI service for creating luxury-grade SVG/GIF patterns
"""
import os
import json
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any
from fastapi import FastAPI, HTTPException, Depends, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from supabase import create_client, Client
import svgwrite
from PIL import Image, ImageDraw
import numpy as np
from io import BytesIO
import base64

# Environment setup
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

# Initialize FastAPI
app = FastAPI(
    title="Agent Savage",
    description="Brand-aligned pattern generation API",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Supabase client
def get_supabase() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

# Pydantic models
class BrandConfig(BaseModel):
    primary_color: str = "#000000"
    secondary_color: str = "#FFFFFF"
    accent_color: Optional[str] = "#FF0000"
    font_family: Optional[str] = "Arial"
    logo_url: Optional[str] = None
    
class PatternParams(BaseModel):
    spacing: float = Field(10, ge=5, le=50)
    rotation: float = Field(0, ge=0, le=360)
    scale: float = Field(1, ge=0.5, le=3)
    strokeWidth: float = Field(2, ge=1, le=10)
    opacity: float = Field(1, ge=0.1, le=1)

class CreatePatternRequest(BaseModel):
    project_id: str
    template_id: str
    pattern_name: str
    params: PatternParams
    data_map: Optional[Dict[str, Any]] = None

class ProjectRequest(BaseModel):
    project_name: str
    org_type: str
    brand_json: BrandConfig

# Pattern generation engine
class PatternGenerator:
    """Core pattern generation logic"""
    
    @staticmethod
    def generate_grid_stripes(params: PatternParams, brand: BrandConfig, width: int = 800, height: int = 600) -> str:
        """Generate grid stripes pattern"""
        dwg = svgwrite.Drawing(size=(width, height))
        
        # Create pattern definition
        pattern = dwg.pattern(
            id="gridStripes",
            size=(params.spacing * 2, params.spacing * 2),
            patternUnits="userSpaceOnUse"
        )
        
        # Add stripes
        pattern.add(dwg.line(
            start=(0, 0),
            end=(params.spacing * 2, params.spacing * 2),
            stroke=brand.primary_color,
            stroke_width=params.strokeWidth
        ))
        
        pattern.add(dwg.line(
            start=(params.spacing * 2, 0),
            end=(0, params.spacing * 2),
            stroke=brand.secondary_color,
            stroke_width=params.strokeWidth
        ))
        
        dwg.defs.add(pattern)
        
        # Apply pattern to background
        dwg.add(dwg.rect(
            insert=(0, 0),
            size=(width, height),
            fill="url(#gridStripes)",
            transform=f"rotate({params.rotation} {width/2} {height/2})"
        ))
        
        return dwg.tostring()
    
    @staticmethod
    def generate_dot_matrix(params: PatternParams, brand: BrandConfig, width: int = 800, height: int = 600) -> str:
        """Generate dot matrix pattern"""
        dwg = svgwrite.Drawing(size=(width, height))
        
        # Create pattern
        pattern = dwg.pattern(
            id="dotMatrix",
            size=(params.spacing, params.spacing),
            patternUnits="userSpaceOnUse"
        )
        
        # Add dot
        pattern.add(dwg.circle(
            center=(params.spacing / 2, params.spacing / 2),
            r=params.spacing / 4,
            fill=brand.primary_color,
            opacity=params.opacity
        ))
        
        dwg.defs.add(pattern)
        
        # Apply pattern
        dwg.add(dwg.rect(
            insert=(0, 0),
            size=(width, height),
            fill="url(#dotMatrix)"
        ))
        
        return dwg.tostring()
    
    @staticmethod
    def generate_wave_flow(params: PatternParams, brand: BrandConfig, width: int = 800, height: int = 600) -> str:
        """Generate organic wave pattern"""
        dwg = svgwrite.Drawing(size=(width, height))
        
        # Create wave path
        amplitude = params.spacing * 2
        frequency = 0.02
        
        points = []
        for x in range(0, width + 10, 10):
            y = height / 2 + amplitude * np.sin(frequency * x + params.rotation * np.pi / 180)
            points.append((x, y))
        
        # Draw multiple waves
        for i in range(5):
            offset = i * params.spacing
            wave_points = [(x, y + offset - 2 * params.spacing) for x, y in points]
            
            path = dwg.path(
                d=f"M {wave_points[0][0]} {wave_points[0][1]}",
                stroke=brand.primary_color if i % 2 == 0 else brand.secondary_color,
                stroke_width=params.strokeWidth,
                fill="none",
                opacity=params.opacity
            )
            
            for point in wave_points[1:]:
                path.push(f"L {point[0]} {point[1]}")
            
            dwg.add(path)
        
        return dwg.tostring()
    
    @staticmethod
    def svg_to_gif(svg_content: str, duration: int = 2000) -> bytes:
        """Convert SVG to animated GIF (placeholder - would use cairosvg/imageio in production)"""
        # For now, return a simple animated GIF
        images = []
        for i in range(10):
            img = Image.new('RGB', (800, 600), color=(255, 255, 255))
            draw = ImageDraw.Draw(img)
            # Simple animation
            offset = i * 10
            draw.rectangle([offset, offset, 100 + offset, 100 + offset], fill=(0, 0, 255))
            images.append(img)
        
        # Save as GIF
        output = BytesIO()
        images[0].save(
            output,
            format='GIF',
            save_all=True,
            append_images=images[1:],
            duration=duration // len(images),
            loop=0
        )
        return output.getvalue()

# API Endpoints
@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "Agent Savage", "version": "1.0.0"}

@app.post("/projects")
async def create_project(request: ProjectRequest):
    """Create a new project with brand configuration"""
    supabase = get_supabase()
    
    project_data = {
        "project_name": request.project_name,
        "org_type": request.org_type,
        "brand_json": request.brand_json.dict(),
        "owner_id": str(uuid.uuid4())  # In production, get from auth
    }
    
    result = supabase.table("projects").insert(project_data).execute()
    return {"project": result.data[0]}

@app.get("/templates")
async def list_templates():
    """List all available pattern templates"""
    supabase = get_supabase()
    result = supabase.table("pattern_templates").select("*").eq("is_active", True).execute()
    return {"templates": result.data}

@app.post("/patterns/generate")
async def generate_pattern(request: CreatePatternRequest, background_tasks: BackgroundTasks):
    """Generate a new pattern"""
    supabase = get_supabase()
    
    # Get project details
    project = supabase.table("projects").select("*").eq("id", request.project_id).single().execute()
    if not project.data:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Get template
    template = supabase.table("pattern_templates").select("*").eq("template_id", request.template_id).single().execute()
    if not template.data:
        raise HTTPException(status_code=404, detail="Template not found")
    
    # Generate pattern based on template
    brand_config = BrandConfig(**project.data["brand_json"])
    generator = PatternGenerator()
    
    if request.template_id == "grid-stripes":
        svg_content = generator.generate_grid_stripes(request.params, brand_config)
    elif request.template_id == "dot-matrix":
        svg_content = generator.generate_dot_matrix(request.params, brand_config)
    elif request.template_id == "wave-flow":
        svg_content = generator.generate_wave_flow(request.params, brand_config)
    else:
        svg_content = generator.generate_grid_stripes(request.params, brand_config)  # Default
    
    # Save pattern
    pattern_data = {
        "project_id": request.project_id,
        "template_id": request.template_id,
        "pattern_name": request.pattern_name,
        "params": request.params.dict(),
        "data_map": request.data_map,
        "svg_content": svg_content
    }
    
    result = supabase.table("patterns").insert(pattern_data).execute()
    pattern_id = result.data[0]["id"]
    
    # Generate GIF in background
    background_tasks.add_task(generate_gif_version, pattern_id, svg_content)
    
    return {
        "pattern": result.data[0],
        "preview_svg": svg_content
    }

@app.get("/patterns/{pattern_id}")
async def get_pattern(pattern_id: str):
    """Get a specific pattern"""
    supabase = get_supabase()
    result = supabase.table("patterns").select("*").eq("id", pattern_id).single().execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Pattern not found")
    
    return {"pattern": result.data}

@app.post("/patterns/{pattern_id}/export")
async def export_pattern(pattern_id: str, format: str = "svg"):
    """Export pattern in various formats"""
    supabase = get_supabase()
    
    # Get pattern
    pattern = supabase.table("patterns").select("*").eq("id", pattern_id).single().execute()
    if not pattern.data:
        raise HTTPException(status_code=404, detail="Pattern not found")
    
    # Track export
    analytics_data = {
        "pattern_id": pattern_id,
        "event_type": "download",
        "metadata": {"format": format}
    }
    supabase.table("pattern_analytics").insert(analytics_data).execute()
    
    # Return appropriate format
    if format == "svg":
        return {
            "format": "svg",
            "content": pattern.data["svg_content"],
            "filename": f"{pattern.data['pattern_name']}.svg"
        }
    elif format == "gif":
        # Generate GIF if not cached
        gif_data = PatternGenerator.svg_to_gif(pattern.data["svg_content"])
        gif_base64 = base64.b64encode(gif_data).decode()
        return {
            "format": "gif",
            "content": gif_base64,
            "filename": f"{pattern.data['pattern_name']}.gif"
        }
    else:
        raise HTTPException(status_code=400, detail="Unsupported format")

@app.post("/patterns/{pattern_id}/comments")
async def add_comment(pattern_id: str, body: str, author_name: str):
    """Add a comment to a pattern"""
    supabase = get_supabase()
    
    comment_data = {
        "pattern_id": pattern_id,
        "body": body,
        "author_name": author_name,
        "author_id": str(uuid.uuid4())  # In production, get from auth
    }
    
    result = supabase.table("comments").insert(comment_data).execute()
    return {"comment": result.data[0]}

@app.get("/patterns/{pattern_id}/comments")
async def get_comments(pattern_id: str):
    """Get all comments for a pattern"""
    supabase = get_supabase()
    result = supabase.table("comments").select("*").eq("pattern_id", pattern_id).order("created_at").execute()
    return {"comments": result.data}

@app.get("/stats")
async def get_statistics(project_id: Optional[str] = None):
    """Get pattern generation statistics"""
    supabase = get_supabase()
    
    # Use the SQL function we created
    if project_id:
        result = supabase.rpc("get_pattern_stats", {"p_project_id": project_id}).execute()
    else:
        result = supabase.rpc("get_pattern_stats").execute()
    
    return {"stats": result.data[0] if result.data else {}}

# Background tasks
async def generate_gif_version(pattern_id: str, svg_content: str):
    """Background task to generate GIF version"""
    try:
        gif_data = PatternGenerator.svg_to_gif(svg_content)
        # In production, upload to storage and update pattern record
        print(f"Generated GIF for pattern {pattern_id}")
    except Exception as e:
        print(f"Error generating GIF: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)