"""
Automated Infographic Generation Pipeline
Implements UNDP/OCHA best practices adapted for advertising
"""
import os
import json
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import svgwrite
import cairosvg
from PIL import Image, ImageDraw, ImageFont
import pandas as pd
import numpy as np
from .data_catalog import data_catalog, MetricDefinition
from .main import PatternGenerator

class InfographicTemplate:
    """Base class for infographic templates"""
    
    def __init__(self, width: int = 1200, height: int = 1600):
        self.width = width
        self.height = height
        self.dwg = svgwrite.Drawing(size=(width, height))
        self.y_offset = 0
        
    def add_header(self, title: str, subtitle: str, brand_config: Dict[str, Any]):
        """Add branded header section"""
        # Background
        self.dwg.add(self.dwg.rect(
            insert=(0, 0),
            size=(self.width, 200),
            fill=brand_config.get("primary_color", "#000000")
        ))
        
        # Title
        self.dwg.add(self.dwg.text(
            title,
            insert=(60, 80),
            font_family=brand_config.get("font_family", "Arial"),
            font_size="48px",
            font_weight="bold",
            fill=brand_config.get("secondary_color", "#FFFFFF")
        ))
        
        # Subtitle
        self.dwg.add(self.dwg.text(
            subtitle,
            insert=(60, 120),
            font_family=brand_config.get("font_family", "Arial"),
            font_size="24px",
            fill=brand_config.get("secondary_color", "#FFFFFF"),
            opacity="0.8"
        ))
        
        self.y_offset = 240
    
    def add_kpi_section(self, kpis: List[Dict[str, Any]], brand_config: Dict[str, Any]):
        """Add key performance indicators section"""
        kpi_width = (self.width - 120) / len(kpis)
        
        for i, kpi in enumerate(kpis):
            x = 60 + (i * kpi_width)
            
            # KPI value
            self.dwg.add(self.dwg.text(
                str(kpi["value"]),
                insert=(x, self.y_offset + 60),
                font_family=brand_config.get("font_family", "Arial"),
                font_size="64px",
                font_weight="bold",
                fill=brand_config.get("primary_color", "#000000")
            ))
            
            # KPI label
            self.dwg.add(self.dwg.text(
                kpi["label"],
                insert=(x, self.y_offset + 90),
                font_family=brand_config.get("font_family", "Arial"),
                font_size="18px",
                fill="#666666"
            ))
            
            # Trend indicator
            if "trend" in kpi:
                trend_color = "#22C55E" if kpi["trend"] > 0 else "#EF4444"
                trend_symbol = "↑" if kpi["trend"] > 0 else "↓"
                
                self.dwg.add(self.dwg.text(
                    f"{trend_symbol} {abs(kpi['trend'])}%",
                    insert=(x, self.y_offset + 115),
                    font_family=brand_config.get("font_family", "Arial"),
                    font_size="16px",
                    fill=trend_color
                ))
        
        self.y_offset += 160
    
    def add_chart_section(self, chart_type: str, data: pd.DataFrame, 
                         title: str, brand_config: Dict[str, Any]):
        """Add data visualization section"""
        
        # Section title
        self.dwg.add(self.dwg.text(
            title,
            insert=(60, self.y_offset + 30),
            font_family=brand_config.get("font_family", "Arial"),
            font_size="28px",
            font_weight="bold",
            fill="#333333"
        ))
        
        chart_y = self.y_offset + 60
        chart_width = self.width - 120
        chart_height = 300
        
        if chart_type == "bar":
            self._draw_bar_chart(data, 60, chart_y, chart_width, chart_height, brand_config)
        elif chart_type == "line":
            self._draw_line_chart(data, 60, chart_y, chart_width, chart_height, brand_config)
        elif chart_type == "donut":
            self._draw_donut_chart(data, 60, chart_y, chart_width, chart_height, brand_config)
        
        self.y_offset += chart_height + 80
    
    def _draw_bar_chart(self, data: pd.DataFrame, x: int, y: int, 
                       width: int, height: int, brand_config: Dict[str, Any]):
        """Draw bar chart visualization"""
        
        if data.empty:
            return
            
        max_value = data['value'].max()
        bar_width = width / len(data)
        
        for i, (_, row) in enumerate(data.iterrows()):
            bar_height = (row['value'] / max_value) * height
            bar_x = x + (i * bar_width) + (bar_width * 0.1)
            bar_y = y + height - bar_height
            
            # Bar
            self.dwg.add(self.dwg.rect(
                insert=(bar_x, bar_y),
                size=(bar_width * 0.8, bar_height),
                fill=brand_config.get("primary_color", "#000000"),
                rx=4
            ))
            
            # Value label
            self.dwg.add(self.dwg.text(
                f"{row['value']:,.0f}",
                insert=(bar_x + bar_width * 0.4, bar_y - 10),
                font_family=brand_config.get("font_family", "Arial"),
                font_size="14px",
                text_anchor="middle",
                fill="#333333"
            ))
            
            # Category label
            self.dwg.add(self.dwg.text(
                str(row.get('category', '')),
                insert=(bar_x + bar_width * 0.4, y + height + 20),
                font_family=brand_config.get("font_family", "Arial"),
                font_size="12px",
                text_anchor="middle",
                fill="#666666"
            ))
    
    def add_insights_section(self, insights: List[str], brand_config: Dict[str, Any]):
        """Add key insights section"""
        
        # Section header
        self.dwg.add(self.dwg.text(
            "Key Insights",
            insert=(60, self.y_offset + 30),
            font_family=brand_config.get("font_family", "Arial"),
            font_size="28px",
            font_weight="bold",
            fill="#333333"
        ))
        
        # Insights list
        for i, insight in enumerate(insights):
            bullet_y = self.y_offset + 70 + (i * 40)
            
            # Bullet point
            self.dwg.add(self.dwg.circle(
                center=(80, bullet_y),
                r=4,
                fill=brand_config.get("primary_color", "#000000")
            ))
            
            # Insight text
            self.dwg.add(self.dwg.text(
                insight,
                insert=(100, bullet_y + 5),
                font_family=brand_config.get("font_family", "Arial"),
                font_size="16px",
                fill="#333333"
            ))
        
        self.y_offset += 70 + (len(insights) * 40) + 40
    
    def add_footer(self, brand_config: Dict[str, Any]):
        """Add branded footer"""
        footer_y = self.height - 100
        
        # Footer background
        self.dwg.add(self.dwg.rect(
            insert=(0, footer_y),
            size=(self.width, 100),
            fill="#F5F5F5"
        ))
        
        # Attribution
        self.dwg.add(self.dwg.text(
            f"Generated by {brand_config.get('brand_name', 'Agent Savage')} | {datetime.now().strftime('%B %Y')}",
            insert=(60, footer_y + 50),
            font_family=brand_config.get("font_family", "Arial"),
            font_size="14px",
            fill="#666666"
        ))
        
        # Data source
        self.dwg.add(self.dwg.text(
            "Data sources: Google Ads, Meta Ads, Google Analytics",
            insert=(self.width - 400, footer_y + 50),
            font_family=brand_config.get("font_family", "Arial"),
            font_size="12px",
            fill="#999999"
        ))
    
    def render(self) -> str:
        """Render infographic to SVG string"""
        return self.dwg.tostring()


class InfographicPipeline:
    """
    Automated infographic generation pipeline
    Implements best practices from humanitarian agencies
    """
    
    def __init__(self):
        self.templates = self._load_templates()
        self.export_presets = self._load_export_presets()
    
    def _load_templates(self) -> Dict[str, Any]:
        """Load infographic templates"""
        return {
            "campaign_summary": {
                "name": "Campaign Summary",
                "sections": ["header", "kpis", "performance_chart", "channel_breakdown", "insights", "footer"],
                "dimensions": {"width": 1200, "height": 1600}
            },
            "monthly_report": {
                "name": "Monthly Performance Report",
                "sections": ["header", "executive_summary", "kpis", "trend_charts", "recommendations", "footer"],
                "dimensions": {"width": 1200, "height": 2000}
            },
            "social_media_card": {
                "name": "Social Media Card",
                "sections": ["mini_header", "hero_metric", "comparison", "branding"],
                "dimensions": {"width": 1080, "height": 1080}
            }
        }
    
    def _load_export_presets(self) -> Dict[str, Any]:
        """Load export format presets"""
        return {
            "print": {
                "dpi": 300,
                "color_mode": "CMYK",
                "bleed": 3,
                "format": "PDF"
            },
            "web": {
                "dpi": 72,
                "color_mode": "RGB",
                "format": "PNG",
                "optimize": True
            },
            "social": {
                "dpi": 144,
                "color_mode": "RGB",
                "format": "JPG",
                "quality": 85
            }
        }
    
    def generate_infographic(self, 
                           template_id: str,
                           data_config: Dict[str, Any],
                           brand_config: Dict[str, Any],
                           export_format: str = "web") -> Tuple[str, bytes]:
        """
        Generate complete infographic from template and data
        Returns (filename, file_content)
        """
        
        template = self.templates.get(template_id)
        if not template:
            raise ValueError(f"Template {template_id} not found")
        
        # Initialize template
        dimensions = template["dimensions"]
        infographic = InfographicTemplate(dimensions["width"], dimensions["height"])
        
        # Fetch and prepare data
        data = self._prepare_data(data_config)
        
        # Build sections
        for section in template["sections"]:
            self._build_section(infographic, section, data, brand_config)
        
        # Render SVG
        svg_content = infographic.render()
        
        # Export to desired format
        export_preset = self.export_presets.get(export_format, self.export_presets["web"])
        output_content = self._export(svg_content, export_preset)
        
        # Generate filename
        filename = f"{template_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.{export_preset['format'].lower()}"
        
        return filename, output_content
    
    def _prepare_data(self, data_config: Dict[str, Any]) -> Dict[str, Any]:
        """Fetch and prepare data for infographic"""
        
        prepared_data = {
            "kpis": [],
            "charts": {},
            "insights": []
        }
        
        # Fetch KPI data
        for kpi_config in data_config.get("kpis", []):
            metric = data_catalog.get_metric_definition(kpi_config["metric_id"])
            if metric:
                # Simulate data fetch (in production, query actual data)
                value = np.random.randint(1000, 100000)
                trend = np.random.uniform(-20, 20)
                
                prepared_data["kpis"].append({
                    "label": metric.metric_name,
                    "value": f"{value:,}",
                    "trend": round(trend, 1),
                    "unit": metric.unit
                })
        
        # Prepare chart data
        for chart_config in data_config.get("charts", []):
            # Simulate chart data
            chart_data = pd.DataFrame({
                "category": ["Channel A", "Channel B", "Channel C", "Channel D"],
                "value": np.random.randint(1000, 50000, 4)
            })
            prepared_data["charts"][chart_config["id"]] = chart_data
        
        # Generate insights
        prepared_data["insights"] = [
            "Campaign performance increased 23% month-over-month",
            "Mobile traffic now accounts for 67% of all conversions",
            "Video creative outperformed static by 2.4x on engagement",
            "Cost per acquisition decreased 15% through optimization"
        ]
        
        return prepared_data
    
    def _build_section(self, infographic: InfographicTemplate, 
                      section: str, data: Dict[str, Any], 
                      brand_config: Dict[str, Any]):
        """Build individual infographic section"""
        
        if section == "header":
            infographic.add_header(
                "Campaign Performance Report",
                "Q4 2024 Summary",
                brand_config
            )
        
        elif section == "kpis":
            infographic.add_kpi_section(data["kpis"], brand_config)
        
        elif section == "performance_chart":
            if "performance" in data["charts"]:
                infographic.add_chart_section(
                    "bar",
                    data["charts"]["performance"],
                    "Performance by Channel",
                    brand_config
                )
        
        elif section == "insights":
            infographic.add_insights_section(data["insights"], brand_config)
        
        elif section == "footer":
            infographic.add_footer(brand_config)
    
    def _export(self, svg_content: str, export_preset: Dict[str, Any]) -> bytes:
        """Export SVG to desired format"""
        
        if export_preset["format"] == "SVG":
            return svg_content.encode('utf-8')
        
        elif export_preset["format"] == "PNG":
            png_data = cairosvg.svg2png(
                bytestring=svg_content.encode('utf-8'),
                dpi=export_preset["dpi"]
            )
            return png_data
        
        elif export_preset["format"] == "PDF":
            pdf_data = cairosvg.svg2pdf(
                bytestring=svg_content.encode('utf-8'),
                dpi=export_preset["dpi"]
            )
            return pdf_data
        
        else:
            # Default to PNG
            return cairosvg.svg2png(bytestring=svg_content.encode('utf-8'))
    
    def create_batch_infographics(self, 
                                configs: List[Dict[str, Any]],
                                brand_config: Dict[str, Any]) -> List[Tuple[str, bytes]]:
        """Generate multiple infographics in batch"""
        
        results = []
        
        for config in configs:
            try:
                filename, content = self.generate_infographic(
                    config["template_id"],
                    config["data_config"],
                    brand_config,
                    config.get("export_format", "web")
                )
                results.append((filename, content))
            except Exception as e:
                print(f"Error generating infographic: {e}")
                continue
        
        return results

# Singleton instance
infographic_pipeline = InfographicPipeline()