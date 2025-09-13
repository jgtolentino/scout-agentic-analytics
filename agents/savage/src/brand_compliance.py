"""
Brand Compliance Scoring System
Ensures all generated assets meet brand guidelines
"""
import json
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import colorsys
from PIL import Image
import numpy as np
from pydantic import BaseModel
import re

class BrandGuidelines(BaseModel):
    """Brand guidelines specification"""
    brand_id: str
    brand_name: str
    colors: Dict[str, str]  # primary, secondary, accent, etc.
    color_ratios: Dict[str, float]  # Expected usage ratios
    typography: Dict[str, Any]
    spacing: Dict[str, int]
    logo_rules: Dict[str, Any]
    forbidden_elements: List[str]
    accessibility_requirements: Dict[str, Any]

class BrandComplianceChecker:
    """
    Automated brand compliance checking
    Inspired by OCHA's visual identity guidelines system
    """
    
    def __init__(self):
        self.brand_guidelines = self._load_brand_guidelines()
        self.compliance_rules = self._initialize_compliance_rules()
    
    def _load_brand_guidelines(self) -> Dict[str, BrandGuidelines]:
        """Load brand guidelines for major clients"""
        
        guidelines = {
            "tbwa": BrandGuidelines(
                brand_id="tbwa_001",
                brand_name="TBWA",
                colors={
                    "primary": "#000000",  # Black
                    "secondary": "#FBBF24",  # Yellow
                    "white": "#FFFFFF",
                    "gray": "#6B7280"
                },
                color_ratios={
                    "primary": 0.4,
                    "secondary": 0.3,
                    "white": 0.25,
                    "gray": 0.05
                },
                typography={
                    "primary_font": "Helvetica Neue",
                    "secondary_font": "Arial",
                    "min_font_size": 12,
                    "heading_weight": "bold",
                    "body_weight": "regular"
                },
                spacing={
                    "min_padding": 16,
                    "element_gap": 8,
                    "section_gap": 32
                },
                logo_rules={
                    "min_size": 80,
                    "clear_space": 20,
                    "positions": ["top-left", "bottom-right"],
                    "background_contrast": 4.5
                },
                forbidden_elements=[
                    "gradients on logo",
                    "rotated text",
                    "low contrast combinations"
                ],
                accessibility_requirements={
                    "min_contrast_ratio": 4.5,
                    "large_text_contrast": 3.0,
                    "color_blind_safe": True
                }
            ),
            
            "nike": BrandGuidelines(
                brand_id="nike_001",
                brand_name="Nike",
                colors={
                    "primary": "#111111",
                    "secondary": "#FFFFFF",
                    "accent": "#FF6900"
                },
                color_ratios={
                    "primary": 0.5,
                    "secondary": 0.4,
                    "accent": 0.1
                },
                typography={
                    "primary_font": "Futura",
                    "secondary_font": "Helvetica",
                    "min_font_size": 14,
                    "heading_weight": "bold",
                    "body_weight": "medium"
                },
                spacing={
                    "min_padding": 24,
                    "element_gap": 12,
                    "section_gap": 48
                },
                logo_rules={
                    "min_size": 100,
                    "clear_space": 30,
                    "positions": ["center", "bottom-center"],
                    "background_contrast": 5.0
                },
                forbidden_elements=[
                    "competing logos",
                    "busy backgrounds",
                    "distorted proportions"
                ],
                accessibility_requirements={
                    "min_contrast_ratio": 4.5,
                    "large_text_contrast": 3.0,
                    "color_blind_safe": True
                }
            )
        }
        
        return guidelines
    
    def _initialize_compliance_rules(self) -> Dict[str, Any]:
        """Initialize compliance checking rules"""
        
        return {
            "color_compliance": {
                "tolerance": 0.05,  # 5% deviation allowed
                "weight": 0.25
            },
            "typography_compliance": {
                "weight": 0.20
            },
            "spacing_compliance": {
                "weight": 0.15
            },
            "logo_compliance": {
                "weight": 0.20
            },
            "accessibility_compliance": {
                "weight": 0.20
            }
        }
    
    def check_compliance(self, 
                        asset_data: Dict[str, Any],
                        brand_id: str) -> Dict[str, Any]:
        """
        Check asset compliance against brand guidelines
        Returns compliance score and detailed report
        """
        
        guidelines = self.brand_guidelines.get(brand_id)
        if not guidelines:
            raise ValueError(f"Brand guidelines not found for {brand_id}")
        
        compliance_report = {
            "brand_id": brand_id,
            "timestamp": datetime.now().isoformat(),
            "overall_score": 0.0,
            "details": {},
            "violations": [],
            "warnings": [],
            "passed_checks": []
        }
        
        # Run compliance checks
        color_score = self._check_color_compliance(asset_data, guidelines)
        typography_score = self._check_typography_compliance(asset_data, guidelines)
        spacing_score = self._check_spacing_compliance(asset_data, guidelines)
        logo_score = self._check_logo_compliance(asset_data, guidelines)
        accessibility_score = self._check_accessibility_compliance(asset_data, guidelines)
        
        # Calculate weighted overall score
        scores = {
            "color": color_score,
            "typography": typography_score,
            "spacing": spacing_score,
            "logo": logo_score,
            "accessibility": accessibility_score
        }
        
        weights = {
            "color": self.compliance_rules["color_compliance"]["weight"],
            "typography": self.compliance_rules["typography_compliance"]["weight"],
            "spacing": self.compliance_rules["spacing_compliance"]["weight"],
            "logo": self.compliance_rules["logo_compliance"]["weight"],
            "accessibility": self.compliance_rules["accessibility_compliance"]["weight"]
        }
        
        overall_score = sum(scores[k] * weights[k] for k in scores) / sum(weights.values())
        
        compliance_report["overall_score"] = round(overall_score * 100, 2)
        compliance_report["details"] = {k: round(v * 100, 2) for k, v in scores.items()}
        
        # Generate recommendations
        compliance_report["recommendations"] = self._generate_recommendations(
            scores, 
            guidelines
        )
        
        return compliance_report
    
    def _check_color_compliance(self, 
                               asset_data: Dict[str, Any],
                               guidelines: BrandGuidelines) -> float:
        """Check color usage compliance"""
        
        score = 1.0
        used_colors = asset_data.get("colors", {})
        
        # Check if brand colors are used
        for color_name, color_value in guidelines.colors.items():
            if color_name in ["white", "gray"]:  # Skip neutral colors
                continue
                
            if not self._color_is_present(color_value, used_colors):
                score -= 0.2
                
        # Check color ratios
        if "color_histogram" in asset_data:
            histogram = asset_data["color_histogram"]
            expected_ratios = guidelines.color_ratios
            
            for color_name, expected_ratio in expected_ratios.items():
                if color_name in histogram:
                    actual_ratio = histogram[color_name]
                    deviation = abs(actual_ratio - expected_ratio)
                    if deviation > self.compliance_rules["color_compliance"]["tolerance"]:
                        score -= deviation * 0.5
        
        return max(0, score)
    
    def _check_typography_compliance(self, 
                                   asset_data: Dict[str, Any],
                                   guidelines: BrandGuidelines) -> float:
        """Check typography compliance"""
        
        score = 1.0
        used_fonts = asset_data.get("fonts", [])
        
        # Check if approved fonts are used
        approved_fonts = [
            guidelines.typography["primary_font"],
            guidelines.typography["secondary_font"]
        ]
        
        for font in used_fonts:
            if font not in approved_fonts:
                score -= 0.3
        
        # Check minimum font size
        min_font_size = asset_data.get("min_font_size", 12)
        if min_font_size < guidelines.typography["min_font_size"]:
            score -= 0.2
        
        return max(0, score)
    
    def _check_spacing_compliance(self, 
                                asset_data: Dict[str, Any],
                                guidelines: BrandGuidelines) -> float:
        """Check spacing and layout compliance"""
        
        score = 1.0
        
        # Check minimum padding
        if "padding" in asset_data:
            if any(p < guidelines.spacing["min_padding"] for p in asset_data["padding"]):
                score -= 0.2
        
        # Check element gaps
        if "element_gaps" in asset_data:
            min_gap = min(asset_data["element_gaps"])
            if min_gap < guidelines.spacing["element_gap"]:
                score -= 0.1
        
        return max(0, score)
    
    def _check_logo_compliance(self, 
                              asset_data: Dict[str, Any],
                              guidelines: BrandGuidelines) -> float:
        """Check logo usage compliance"""
        
        score = 1.0
        
        if "logo" not in asset_data:
            return 0.0  # Logo required but missing
        
        logo_data = asset_data["logo"]
        
        # Check minimum size
        if logo_data.get("size", 0) < guidelines.logo_rules["min_size"]:
            score -= 0.3
        
        # Check clear space
        if logo_data.get("clear_space", 0) < guidelines.logo_rules["clear_space"]:
            score -= 0.2
        
        # Check position
        if logo_data.get("position") not in guidelines.logo_rules["positions"]:
            score -= 0.1
        
        # Check background contrast
        if logo_data.get("background_contrast", 0) < guidelines.logo_rules["background_contrast"]:
            score -= 0.2
        
        return max(0, score)
    
    def _check_accessibility_compliance(self, 
                                      asset_data: Dict[str, Any],
                                      guidelines: BrandGuidelines) -> float:
        """Check accessibility compliance"""
        
        score = 1.0
        
        # Check color contrast ratios
        if "contrast_ratios" in asset_data:
            min_contrast = min(asset_data["contrast_ratios"])
            if min_contrast < guidelines.accessibility_requirements["min_contrast_ratio"]:
                score -= 0.3
        
        # Check color blind safety
        if guidelines.accessibility_requirements["color_blind_safe"]:
            if not asset_data.get("color_blind_safe", True):
                score -= 0.2
        
        # Check for alt text
        if not asset_data.get("has_alt_text", False):
            score -= 0.1
        
        return max(0, score)
    
    def _color_is_present(self, target_color: str, used_colors: Dict[str, Any]) -> bool:
        """Check if a color is present in the asset within tolerance"""
        
        target_rgb = self._hex_to_rgb(target_color)
        
        for color_data in used_colors.values():
            if isinstance(color_data, str):
                color_rgb = self._hex_to_rgb(color_data)
            else:
                color_rgb = color_data.get("rgb", [0, 0, 0])
            
            # Calculate color distance
            distance = np.linalg.norm(np.array(target_rgb) - np.array(color_rgb))
            if distance < 30:  # Threshold for color similarity
                return True
        
        return False
    
    def _hex_to_rgb(self, hex_color: str) -> Tuple[int, int, int]:
        """Convert hex color to RGB tuple"""
        hex_color = hex_color.lstrip('#')
        return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))
    
    def _generate_recommendations(self, 
                                scores: Dict[str, float],
                                guidelines: BrandGuidelines) -> List[str]:
        """Generate improvement recommendations based on scores"""
        
        recommendations = []
        
        # Color recommendations
        if scores["color"] < 0.8:
            recommendations.append(
                f"Increase usage of brand primary color ({guidelines.colors['primary']}) "
                f"to meet the {guidelines.color_ratios['primary']*100:.0f}% target ratio"
            )
        
        # Typography recommendations
        if scores["typography"] < 0.8:
            recommendations.append(
                f"Use only approved fonts: {guidelines.typography['primary_font']} "
                f"or {guidelines.typography['secondary_font']}"
            )
        
        # Spacing recommendations
        if scores["spacing"] < 0.8:
            recommendations.append(
                f"Increase padding to minimum {guidelines.spacing['min_padding']}px "
                f"and maintain {guidelines.spacing['element_gap']}px gaps between elements"
            )
        
        # Logo recommendations
        if scores["logo"] < 0.8:
            recommendations.append(
                f"Ensure logo is at least {guidelines.logo_rules['min_size']}px "
                f"with {guidelines.logo_rules['clear_space']}px clear space"
            )
        
        # Accessibility recommendations
        if scores["accessibility"] < 0.8:
            recommendations.append(
                f"Improve color contrast to meet WCAG AA standard "
                f"(minimum {guidelines.accessibility_requirements['min_contrast_ratio']}:1 ratio)"
            )
        
        return recommendations
    
    def generate_compliance_report(self, 
                                 compliance_data: Dict[str, Any],
                                 format: str = "html") -> str:
        """Generate formatted compliance report"""
        
        if format == "html":
            return self._generate_html_report(compliance_data)
        elif format == "json":
            return json.dumps(compliance_data, indent=2)
        else:
            return str(compliance_data)
    
    def _generate_html_report(self, compliance_data: Dict[str, Any]) -> str:
        """Generate HTML compliance report"""
        
        html = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>Brand Compliance Report</title>
            <style>
                body {{ font-family: Arial, sans-serif; margin: 40px; }}
                .score {{ font-size: 48px; font-weight: bold; }}
                .score.good {{ color: #22C55E; }}
                .score.warning {{ color: #F59E0B; }}
                .score.poor {{ color: #EF4444; }}
                .details {{ margin-top: 20px; }}
                .recommendation {{ 
                    background: #F3F4F6; 
                    padding: 10px; 
                    margin: 5px 0; 
                    border-radius: 4px; 
                }}
            </style>
        </head>
        <body>
            <h1>Brand Compliance Report</h1>
            <p>Brand: {compliance_data['brand_id']}</p>
            <p>Generated: {compliance_data['timestamp']}</p>
            
            <h2>Overall Score</h2>
            <div class="score {self._get_score_class(compliance_data['overall_score'])}">
                {compliance_data['overall_score']}%
            </div>
            
            <div class="details">
                <h3>Category Scores</h3>
                <ul>
        """
        
        for category, score in compliance_data['details'].items():
            html += f"<li>{category.title()}: {score}%</li>"
        
        html += """
                </ul>
                
                <h3>Recommendations</h3>
        """
        
        for rec in compliance_data.get('recommendations', []):
            html += f'<div class="recommendation">{rec}</div>'
        
        html += """
            </div>
        </body>
        </html>
        """
        
        return html
    
    def _get_score_class(self, score: float) -> str:
        """Get CSS class based on score"""
        if score >= 80:
            return "good"
        elif score >= 60:
            return "warning"
        else:
            return "poor"

# Singleton instance
brand_compliance_checker = BrandComplianceChecker()