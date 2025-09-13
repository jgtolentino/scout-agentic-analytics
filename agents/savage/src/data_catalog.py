"""
Data Catalog System - Adapted from UNDP/OCHA best practices for advertising metrics
"""
import os
import json
from typing import Dict, List, Optional, Any
from datetime import datetime
from pydantic import BaseModel, Field
from supabase import create_client
import pandas as pd
from enum import Enum

class MetricCategory(str, Enum):
    REACH = "reach"
    ENGAGEMENT = "engagement"
    CONVERSION = "conversion"
    BRAND_HEALTH = "brand_health"
    CREATIVE_PERFORMANCE = "creative_performance"
    SPEND_EFFICIENCY = "spend_efficiency"

class DataSource(str, Enum):
    GOOGLE_ADS = "google_ads"
    META_ADS = "meta_ads"
    TIKTOK_ADS = "tiktok_ads"
    LINKEDIN_ADS = "linkedin_ads"
    GOOGLE_ANALYTICS = "google_analytics"
    ADOBE_ANALYTICS = "adobe_analytics"
    SALESFORCE = "salesforce"
    CUSTOM_API = "custom_api"

class MetricDefinition(BaseModel):
    """Standardized metric definition following OCHA's indicator registry pattern"""
    metric_id: str
    metric_name: str
    category: MetricCategory
    description: str
    formula: Optional[str] = None
    unit: str = "count"
    data_sources: List[DataSource]
    refresh_frequency: str = "daily"
    aggregation_method: str = "sum"
    visualization_type: List[str] = ["line", "bar"]
    business_rules: Dict[str, Any] = {}
    metadata: Dict[str, Any] = {}

class DataCatalog:
    """
    Centralized data catalog inspired by UNDP's Human Development Data Center
    Adapted for advertising/marketing metrics
    """
    
    def __init__(self):
        self.supabase = create_client(
            os.getenv("SUPABASE_URL"),
            os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        )
        self.metrics_registry = self._load_metrics_registry()
        
    def _load_metrics_registry(self) -> Dict[str, MetricDefinition]:
        """Load standardized advertising metrics definitions"""
        
        base_metrics = {
            # Reach Metrics
            "impressions": MetricDefinition(
                metric_id="reach_001",
                metric_name="Impressions",
                category=MetricCategory.REACH,
                description="Total number of times ads were displayed",
                unit="count",
                data_sources=[DataSource.GOOGLE_ADS, DataSource.META_ADS],
                visualization_type=["line", "area", "number"]
            ),
            "unique_reach": MetricDefinition(
                metric_id="reach_002",
                metric_name="Unique Reach",
                category=MetricCategory.REACH,
                description="Number of unique users who saw the ad",
                unit="users",
                data_sources=[DataSource.META_ADS, DataSource.GOOGLE_ADS],
                visualization_type=["line", "bar", "number"]
            ),
            
            # Engagement Metrics
            "click_through_rate": MetricDefinition(
                metric_id="eng_001",
                metric_name="Click-Through Rate (CTR)",
                category=MetricCategory.ENGAGEMENT,
                description="Percentage of impressions that resulted in clicks",
                formula="(clicks / impressions) * 100",
                unit="percentage",
                data_sources=[DataSource.GOOGLE_ADS, DataSource.META_ADS],
                visualization_type=["line", "gauge", "number"]
            ),
            "engagement_rate": MetricDefinition(
                metric_id="eng_002",
                metric_name="Engagement Rate",
                category=MetricCategory.ENGAGEMENT,
                description="Total engagements divided by impressions",
                formula="(likes + comments + shares) / impressions * 100",
                unit="percentage",
                data_sources=[DataSource.META_ADS, DataSource.TIKTOK_ADS],
                visualization_type=["line", "bar", "gauge"]
            ),
            
            # Conversion Metrics
            "conversion_rate": MetricDefinition(
                metric_id="conv_001",
                metric_name="Conversion Rate",
                category=MetricCategory.CONVERSION,
                description="Percentage of clicks that resulted in conversions",
                formula="(conversions / clicks) * 100",
                unit="percentage",
                data_sources=[DataSource.GOOGLE_ADS, DataSource.GOOGLE_ANALYTICS],
                visualization_type=["funnel", "line", "number"]
            ),
            "roas": MetricDefinition(
                metric_id="conv_002",
                metric_name="Return on Ad Spend (ROAS)",
                category=MetricCategory.CONVERSION,
                description="Revenue generated per dollar spent",
                formula="revenue / ad_spend",
                unit="ratio",
                data_sources=[DataSource.GOOGLE_ADS, DataSource.META_ADS],
                visualization_type=["bar", "line", "number", "gauge"]
            ),
            
            # Brand Health Metrics
            "brand_awareness_lift": MetricDefinition(
                metric_id="brand_001",
                metric_name="Brand Awareness Lift",
                category=MetricCategory.BRAND_HEALTH,
                description="Increase in brand awareness from baseline",
                unit="percentage",
                data_sources=[DataSource.META_ADS, DataSource.CUSTOM_API],
                visualization_type=["bar", "line", "lift_chart"]
            ),
            "sentiment_score": MetricDefinition(
                metric_id="brand_002",
                metric_name="Brand Sentiment Score",
                category=MetricCategory.BRAND_HEALTH,
                description="Average sentiment of brand mentions",
                unit="score",
                data_sources=[DataSource.CUSTOM_API],
                visualization_type=["gauge", "line", "sentiment_cloud"]
            ),
            
            # Creative Performance
            "creative_fatigue_score": MetricDefinition(
                metric_id="creative_001",
                metric_name="Creative Fatigue Score",
                category=MetricCategory.CREATIVE_PERFORMANCE,
                description="Decline in CTR over time for same creative",
                formula="(initial_ctr - current_ctr) / initial_ctr * 100",
                unit="percentage",
                data_sources=[DataSource.META_ADS, DataSource.GOOGLE_ADS],
                visualization_type=["line", "heatmap", "alert"]
            ),
            
            # Spend Efficiency
            "cost_per_acquisition": MetricDefinition(
                metric_id="spend_001",
                metric_name="Cost Per Acquisition (CPA)",
                category=MetricCategory.SPEND_EFFICIENCY,
                description="Average cost to acquire a customer",
                formula="total_spend / conversions",
                unit="currency",
                data_sources=[DataSource.GOOGLE_ADS, DataSource.META_ADS],
                visualization_type=["bar", "line", "number", "target_gauge"]
            )
        }
        
        return base_metrics
    
    def register_custom_metric(self, metric: MetricDefinition) -> str:
        """Register a new metric in the catalog"""
        result = self.supabase.table("metric_definitions").insert({
            "metric_id": metric.metric_id,
            "definition": metric.dict()
        }).execute()
        
        self.metrics_registry[metric.metric_id] = metric
        return metric.metric_id
    
    def get_metric_definition(self, metric_id: str) -> Optional[MetricDefinition]:
        """Retrieve metric definition from catalog"""
        return self.metrics_registry.get(metric_id)
    
    def validate_data_against_schema(self, data: pd.DataFrame, metric_id: str) -> Dict[str, Any]:
        """Validate incoming data against metric schema"""
        metric = self.get_metric_definition(metric_id)
        if not metric:
            return {"valid": False, "errors": ["Metric not found in catalog"]}
        
        validation_results = {
            "valid": True,
            "errors": [],
            "warnings": []
        }
        
        # Check required columns based on formula
        if metric.formula:
            # Extract variables from formula
            import re
            variables = re.findall(r'\b[a-z_]+\b', metric.formula)
            missing_cols = [var for var in variables if var not in data.columns]
            if missing_cols:
                validation_results["valid"] = False
                validation_results["errors"].append(f"Missing columns: {missing_cols}")
        
        # Check data types
        numeric_columns = ["impressions", "clicks", "conversions", "revenue", "ad_spend"]
        for col in data.columns:
            if col in numeric_columns and not pd.api.types.is_numeric_dtype(data[col]):
                validation_results["warnings"].append(f"Column {col} should be numeric")
        
        return validation_results
    
    def generate_data_quality_report(self) -> Dict[str, Any]:
        """Generate data quality report following OCHA's monitoring practices"""
        report = {
            "timestamp": datetime.now().isoformat(),
            "metrics_health": {},
            "data_freshness": {},
            "completeness": {},
            "anomalies": []
        }
        
        # Check each metric's data freshness
        for metric_id, metric in self.metrics_registry.items():
            # Query latest data timestamp
            result = self.supabase.table("metric_data")\
                .select("updated_at")\
                .eq("metric_id", metric_id)\
                .order("updated_at", desc=True)\
                .limit(1)\
                .execute()
            
            if result.data:
                last_update = datetime.fromisoformat(result.data[0]["updated_at"])
                hours_since_update = (datetime.now() - last_update).total_seconds() / 3600
                
                report["data_freshness"][metric_id] = {
                    "last_update": last_update.isoformat(),
                    "hours_since_update": hours_since_update,
                    "status": "healthy" if hours_since_update < 24 else "stale"
                }
        
        return report
    
    def create_metric_lineage(self, derived_metric_id: str, source_metrics: List[str]) -> None:
        """Track metric dependencies for impact analysis"""
        lineage_data = {
            "derived_metric": derived_metric_id,
            "source_metrics": source_metrics,
            "created_at": datetime.now().isoformat()
        }
        
        self.supabase.table("metric_lineage").insert(lineage_data).execute()
    
    def export_catalog_documentation(self) -> str:
        """Export catalog as markdown documentation"""
        doc = "# Advertising Metrics Data Catalog\n\n"
        doc += "## Overview\n"
        doc += f"Total Metrics: {len(self.metrics_registry)}\n\n"
        
        # Group by category
        by_category = {}
        for metric in self.metrics_registry.values():
            if metric.category not in by_category:
                by_category[metric.category] = []
            by_category[metric.category].append(metric)
        
        for category, metrics in by_category.items():
            doc += f"\n## {category.value.replace('_', ' ').title()}\n\n"
            for metric in metrics:
                doc += f"### {metric.metric_name}\n"
                doc += f"- **ID**: {metric.metric_id}\n"
                doc += f"- **Description**: {metric.description}\n"
                doc += f"- **Unit**: {metric.unit}\n"
                if metric.formula:
                    doc += f"- **Formula**: `{metric.formula}`\n"
                doc += f"- **Data Sources**: {', '.join([ds.value for ds in metric.data_sources])}\n"
                doc += f"- **Visualization Types**: {', '.join(metric.visualization_type)}\n\n"
        
        return doc

# Singleton instance
data_catalog = DataCatalog()