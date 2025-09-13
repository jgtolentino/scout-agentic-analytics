"""
Automated Dashboard Generation System
Adapts UNDP/OCHA's modular approach for advertising dashboards
"""
import json
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
import numpy as np
from pydantic import BaseModel
from .data_catalog import data_catalog, MetricCategory

class DashboardTemplate(BaseModel):
    """Dashboard template following OCHA's component-based architecture"""
    template_id: str
    template_name: str
    description: str
    layout: Dict[str, Any]  # Grid layout configuration
    components: List[Dict[str, Any]]  # Component specifications
    refresh_schedule: str = "hourly"
    access_level: str = "public"

class DashboardComponent(BaseModel):
    """Individual dashboard component"""
    component_id: str
    component_type: str  # kpi_card, line_chart, bar_chart, funnel, map, etc.
    metric_ids: List[str]
    config: Dict[str, Any]
    position: Dict[str, int]  # grid position
    size: Dict[str, int]  # grid size

class DashboardGenerator:
    """
    Generates dashboards using best practices from humanitarian data viz:
    - Modular components
    - Accessibility-first design
    - Real-time data binding
    - Multi-format export
    """
    
    def __init__(self):
        self.templates = self._load_dashboard_templates()
        self.component_library = self._initialize_component_library()
    
    def _load_dashboard_templates(self) -> Dict[str, DashboardTemplate]:
        """Load pre-configured dashboard templates"""
        
        templates = {
            "campaign_performance": DashboardTemplate(
                template_id="campaign_perf_001",
                template_name="Campaign Performance Dashboard",
                description="Real-time campaign performance monitoring",
                layout={
                    "type": "grid",
                    "columns": 12,
                    "rows": 8,
                    "gap": 16
                },
                components=[
                    {
                        "component_id": "kpi_impressions",
                        "component_type": "kpi_card",
                        "metric_ids": ["reach_001"],
                        "position": {"x": 0, "y": 0},
                        "size": {"w": 3, "h": 2}
                    },
                    {
                        "component_id": "kpi_ctr",
                        "component_type": "kpi_card",
                        "metric_ids": ["eng_001"],
                        "position": {"x": 3, "y": 0},
                        "size": {"w": 3, "h": 2}
                    },
                    {
                        "component_id": "kpi_conversions",
                        "component_type": "kpi_card",
                        "metric_ids": ["conv_001"],
                        "position": {"x": 6, "y": 0},
                        "size": {"w": 3, "h": 2}
                    },
                    {
                        "component_id": "kpi_roas",
                        "component_type": "kpi_card",
                        "metric_ids": ["conv_002"],
                        "position": {"x": 9, "y": 0},
                        "size": {"w": 3, "h": 2}
                    },
                    {
                        "component_id": "trend_chart",
                        "component_type": "line_chart",
                        "metric_ids": ["reach_001", "eng_001"],
                        "position": {"x": 0, "y": 2},
                        "size": {"w": 8, "h": 4}
                    },
                    {
                        "component_id": "channel_breakdown",
                        "component_type": "bar_chart",
                        "metric_ids": ["conv_002"],
                        "position": {"x": 8, "y": 2},
                        "size": {"w": 4, "h": 4}
                    },
                    {
                        "component_id": "conversion_funnel",
                        "component_type": "funnel_chart",
                        "metric_ids": ["reach_001", "eng_001", "conv_001"],
                        "position": {"x": 0, "y": 6},
                        "size": {"w": 6, "h": 2}
                    },
                    {
                        "component_id": "creative_heatmap",
                        "component_type": "heatmap",
                        "metric_ids": ["creative_001"],
                        "position": {"x": 6, "y": 6},
                        "size": {"w": 6, "h": 2}
                    }
                ]
            ),
            
            "executive_summary": DashboardTemplate(
                template_id="exec_summary_001",
                template_name="Executive Summary Dashboard",
                description="High-level KPIs and trends for C-suite",
                layout={
                    "type": "grid",
                    "columns": 12,
                    "rows": 6,
                    "gap": 20
                },
                components=[
                    {
                        "component_id": "hero_metrics",
                        "component_type": "hero_kpi_group",
                        "metric_ids": ["conv_002", "spend_001", "brand_001"],
                        "position": {"x": 0, "y": 0},
                        "size": {"w": 12, "h": 2}
                    },
                    {
                        "component_id": "performance_trend",
                        "component_type": "area_chart",
                        "metric_ids": ["conv_002"],
                        "position": {"x": 0, "y": 2},
                        "size": {"w": 6, "h": 4}
                    },
                    {
                        "component_id": "channel_mix",
                        "component_type": "donut_chart",
                        "metric_ids": ["spend_001"],
                        "position": {"x": 6, "y": 2},
                        "size": {"w": 6, "h": 4}
                    }
                ]
            ),
            
            "creative_performance": DashboardTemplate(
                template_id="creative_perf_001",
                template_name="Creative Performance Dashboard",
                description="Creative asset performance and optimization",
                layout={
                    "type": "masonry",
                    "columns": 4,
                    "gap": 16
                },
                components=[
                    {
                        "component_id": "creative_grid",
                        "component_type": "creative_gallery",
                        "metric_ids": ["eng_001", "conv_001", "creative_001"],
                        "position": {"x": 0, "y": 0},
                        "size": {"w": 4, "h": 3}
                    },
                    {
                        "component_id": "fatigue_alerts",
                        "component_type": "alert_list",
                        "metric_ids": ["creative_001"],
                        "position": {"x": 0, "y": 3},
                        "size": {"w": 2, "h": 2}
                    },
                    {
                        "component_id": "ab_test_results",
                        "component_type": "comparison_chart",
                        "metric_ids": ["eng_001", "conv_001"],
                        "position": {"x": 2, "y": 3},
                        "size": {"w": 2, "h": 2}
                    }
                ]
            )
        }
        
        return templates
    
    def _initialize_component_library(self) -> Dict[str, Any]:
        """Initialize reusable component configurations"""
        
        return {
            "kpi_card": {
                "default_config": {
                    "show_trend": True,
                    "trend_period": "7d",
                    "comparison": "previous_period",
                    "number_format": "compact",
                    "accessibility": {
                        "aria_label": "Key performance indicator",
                        "color_contrast_ratio": 7.1
                    }
                }
            },
            "line_chart": {
                "default_config": {
                    "x_axis": "date",
                    "y_axis": "value",
                    "interpolation": "smooth",
                    "show_points": False,
                    "show_grid": True,
                    "legend_position": "bottom",
                    "responsive": True,
                    "accessibility": {
                        "description": "Time series chart",
                        "keyboard_navigation": True
                    }
                }
            },
            "bar_chart": {
                "default_config": {
                    "orientation": "vertical",
                    "sort_order": "descending",
                    "show_values": True,
                    "color_scheme": "categorical",
                    "accessibility": {
                        "pattern_fills": True,
                        "alt_text_template": "{category}: {value}"
                    }
                }
            },
            "funnel_chart": {
                "default_config": {
                    "show_percentages": True,
                    "show_dropoff": True,
                    "color_gradient": True,
                    "accessibility": {
                        "description": "Conversion funnel visualization"
                    }
                }
            },
            "heatmap": {
                "default_config": {
                    "color_scale": "sequential",
                    "show_values": True,
                    "cell_border": True,
                    "accessibility": {
                        "color_blind_safe": True,
                        "table_fallback": True
                    }
                }
            }
        }
    
    def generate_dashboard(self, template_id: str, 
                         brand_config: Dict[str, Any],
                         date_range: Optional[Dict[str, datetime]] = None) -> Dict[str, Any]:
        """Generate a complete dashboard specification"""
        
        template = self.templates.get(template_id)
        if not template:
            raise ValueError(f"Template {template_id} not found")
        
        # Default date range
        if not date_range:
            date_range = {
                "start": datetime.now() - timedelta(days=30),
                "end": datetime.now()
            }
        
        dashboard_spec = {
            "id": f"dashboard_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            "template": template.template_name,
            "created_at": datetime.now().isoformat(),
            "date_range": {
                "start": date_range["start"].isoformat(),
                "end": date_range["end"].isoformat()
            },
            "brand": brand_config,
            "layout": template.layout,
            "components": []
        }
        
        # Process each component
        for component_spec in template.components:
            component = self._generate_component(
                component_spec,
                brand_config,
                date_range
            )
            dashboard_spec["components"].append(component)
        
        # Add accessibility metadata
        dashboard_spec["accessibility"] = {
            "title": f"{template.template_name} - {brand_config.get('brand_name', 'Brand')}",
            "description": template.description,
            "keyboard_shortcuts": {
                "next_component": "Tab",
                "previous_component": "Shift+Tab",
                "refresh_data": "Ctrl+R",
                "export": "Ctrl+E"
            },
            "screen_reader_hints": True,
            "high_contrast_mode": "available"
        }
        
        return dashboard_spec
    
    def _generate_component(self, spec: Dict[str, Any], 
                          brand_config: Dict[str, Any],
                          date_range: Dict[str, datetime]) -> Dict[str, Any]:
        """Generate individual component with data bindings"""
        
        component_type = spec["component_type"]
        base_config = self.component_library.get(component_type, {}).get("default_config", {})
        
        # Merge with custom config
        config = {**base_config, **spec.get("config", {})}
        
        # Apply brand theming
        config["theme"] = {
            "primary_color": brand_config.get("primary_color", "#000000"),
            "secondary_color": brand_config.get("secondary_color", "#FFFFFF"),
            "font_family": brand_config.get("font_family", "Arial"),
            "border_radius": brand_config.get("border_radius", 4)
        }
        
        # Generate data query
        data_query = self._generate_data_query(
            spec["metric_ids"],
            date_range,
            config
        )
        
        return {
            "id": spec["component_id"],
            "type": component_type,
            "position": spec["position"],
            "size": spec["size"],
            "config": config,
            "data_query": data_query,
            "refresh_interval": 300,  # 5 minutes
            "error_fallback": {
                "show_message": True,
                "message": "Data temporarily unavailable"
            }
        }
    
    def _generate_data_query(self, metric_ids: List[str], 
                           date_range: Dict[str, datetime],
                           config: Dict[str, Any]) -> Dict[str, Any]:
        """Generate data query specification for component"""
        
        queries = []
        
        for metric_id in metric_ids:
            metric = data_catalog.get_metric_definition(metric_id)
            if not metric:
                continue
            
            query = {
                "metric_id": metric_id,
                "metric_name": metric.metric_name,
                "aggregation": metric.aggregation_method,
                "filters": {
                    "date_range": {
                        "start": date_range["start"].isoformat(),
                        "end": date_range["end"].isoformat()
                    }
                },
                "group_by": config.get("group_by", ["date"]),
                "sort": config.get("sort", {"field": "date", "order": "asc"})
            }
            
            queries.append(query)
        
        return {
            "queries": queries,
            "join_on": config.get("join_on", "date"),
            "post_processing": config.get("post_processing", [])
        }
    
    def export_dashboard_config(self, dashboard_spec: Dict[str, Any], 
                               format: str = "json") -> str:
        """Export dashboard configuration for various platforms"""
        
        if format == "json":
            return json.dumps(dashboard_spec, indent=2)
        
        elif format == "tableau":
            # Convert to Tableau workbook XML format
            return self._convert_to_tableau(dashboard_spec)
        
        elif format == "power_bi":
            # Convert to Power BI template format
            return self._convert_to_power_bi(dashboard_spec)
        
        elif format == "react":
            # Generate React component code
            return self._generate_react_code(dashboard_spec)
        
        else:
            raise ValueError(f"Unsupported export format: {format}")
    
    def _generate_react_code(self, dashboard_spec: Dict[str, Any]) -> str:
        """Generate React component code for dashboard"""
        
        code = f"""
import React from 'react'
import {{ Dashboard, DashboardGrid }} from '@savage/dashboard'
import {{ useMetricData }} from '@savage/hooks'

export const {dashboard_spec['id'].replace('-', '')} = () => {{
  const dateRange = {{
    start: new Date('{dashboard_spec['date_range']['start']}'),
    end: new Date('{dashboard_spec['date_range']['end']}')
  }}
  
  return (
    <Dashboard title="{dashboard_spec['template']}">
      <DashboardGrid layout={{{json.dumps(dashboard_spec['layout'])}}}>
"""
        
        for component in dashboard_spec['components']:
            code += f"""
        <DashboardComponent
          id="{component['id']}"
          type="{component['type']}"
          position={{{json.dumps(component['position'])}}}
          size={{{json.dumps(component['size'])}}}
          config={{{json.dumps(component['config'])}}}
          dataQuery={{{json.dumps(component['data_query'])}}}
        />
"""
        
        code += """
      </DashboardGrid>
    </Dashboard>
  )
}
"""
        return code

# Singleton instance
dashboard_generator = DashboardGenerator()