#!/usr/bin/env python3
"""
Philippine FMCG Brand Knowledge Graph Generator
Processes brand research into JSON-LD, Neo4j CSVs, and vector chunks
"""

import csv
import json
import yaml
import re
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Any, Optional
import hashlib

# Configuration
DATA_DIR = "/Users/tbwa/scout-v7/data"
OUT_DIR = "/Users/tbwa/scout-v7/brand_kg"
COUNTRY_FOCUS = "Philippines"
LANG_PRIMARY = "en"
LANG_SECONDARY = "tl"

class BrandKnowledgeGenerator:
    def __init__(self):
        self.brands = {}
        self.categories = {}
        self.aliases = {}
        self.sources = {}
        self.graph_nodes = []
        self.graph_edges = []
        
        # Load Philippine FMCG market intelligence sources
        self.load_sources()
    
    def load_sources(self):
        """Load citation sources from research"""
        self.sources = {
            "src:agriculture-canada-2023": {
                "title": "Consumer Profile – Philippines",
                "publisher": "Agriculture Canada",
                "date": "2023-01-15",
                "url": "https://agriculture.canada.ca/en/international-trade/market-intelligence/reports-and-guides/consumer-profile-philippines",
                "type": "government",
                "confidence": 0.9
            },
            "src:nielseniq-2025": {
                "title": "Understand where Philippines FMCG growth really happens",
                "publisher": "NielsenIQ",
                "date": "2025-01-20",
                "url": "https://nielseniq.com/global/en/insights/analysis/2025/understand-the-next-frontier-where-philippines-fmcg-growth-really-happens/",
                "type": "industry",
                "confidence": 0.85
            },
            "src:kantar-2025": {
                "title": "Food and beverage tops list of leading FMCG products",
                "publisher": "Kantar via BusinessWorld",
                "date": "2025-06-05",
                "url": "https://www.bworldonline.com/economy/2025/06/05/677559/food-and-beverage-tops-list-of-leading-fmcg-products/",
                "type": "industry",
                "confidence": 0.9
            },
            "src:usda-snacks-2024": {
                "title": "Snack Foods Market Brief",
                "publisher": "USDA Foreign Agricultural Service",
                "date": "2024-03-15",
                "url": "https://apps.fas.usda.gov/newgainapi/api/Report/DownloadReportByFileName?fileName=Snack%20Foods%20Market%20Brief_Manila_Philippines_RP2024-0015.pdf",
                "type": "government",
                "confidence": 0.85
            },
            "src:imarc-softdrinks-2024": {
                "title": "Philippines Soft Drinks Market Size, Trends | Report 2033",
                "publisher": "IMARC Group",
                "date": "2024-08-10",
                "url": "https://www.imarcgroup.com/philippines-soft-drinks-market",
                "type": "research",
                "confidence": 0.7
            },
            "src:researchandmarkets-canned-2023": {
                "title": "Philippines Canned Food Market Forecasts from 2023 to 2028",
                "publisher": "Research and Markets",
                "date": "2023-11-20",
                "url": "https://www.researchandmarkets.com/reports/5743382/philippines-canned-food-market-forecasts",
                "type": "research",
                "confidence": 0.7
            },
            "src:6wresearch-soap-2025": {
                "title": "Philippines Soap And Detergent Market (2025-2031)",
                "publisher": "6Wresearch",
                "date": "2025-01-05",
                "url": "https://www.6wresearch.com/industry-report/philippines-soap-and-detergent-market-outlook",
                "type": "research",
                "confidence": 0.7
            }
        }
    
    def normalize_brand_name(self, name: str) -> str:
        """Normalize brand name for slug generation"""
        # Remove special characters, convert to lowercase, replace spaces with hyphens
        normalized = re.sub(r'[^\w\s-]', '', name.lower())
        normalized = re.sub(r'[\s_]+', '-', normalized.strip())
        return normalized
    
    def create_brand_slug(self, brand_name: str) -> str:
        """Create URL-safe slug for brand"""
        return self.normalize_brand_name(brand_name)
    
    def load_csv_data(self):
        """Load brand data from CSV files"""
        print("Loading brand data from CSVs...")
        
        # Load main brands
        brands_file = Path(DATA_DIR) / "Unique_Brands_with_Totals.csv"
        with open(brands_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                brand_name = row['brand_name']
                self.brands[brand_name] = {
                    'name': brand_name,
                    'category': row['category'],
                    'count': int(row['total_count']),
                    'market_data': row['market_data'],
                    'source': 'known',
                    'slug': self.create_brand_slug(brand_name)
                }
        
        # Load missed brands
        missed_file = Path(DATA_DIR) / "missed_brands_summary.csv"
        with open(missed_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                brand_name = row['brand_name']
                self.brands[brand_name] = {
                    'name': brand_name,
                    'category': row['category'],
                    'count': int(row['missed_count']),
                    'market_data': f"Detection issues: {row['detection_issues']}",
                    'source': 'missed',
                    'relevance': row['market_relevance'],
                    'slug': self.create_brand_slug(brand_name)
                }
        
        # Load categories
        categories_file = Path(DATA_DIR) / "Unique_Categories_with_Totals.csv"
        with open(categories_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                category_name = row['category_name']
                self.categories[category_name] = {
                    'name': category_name,
                    'count': int(row['total_count']),
                    'market_size': float(row['market_size_usd']) if row['market_size_usd'] else None,
                    'growth_rate': float(row['growth_rate']) if row['growth_rate'] else None,
                    'key_brands': row['key_brands'].split(', ') if row['key_brands'] else [],
                    'slug': self.create_brand_slug(category_name)
                }
        
        print(f"Loaded {len(self.brands)} brands and {len(self.categories)} categories")
    
    def create_aliases_map(self):
        """Create brand aliases mapping"""
        aliases = {
            'coca-cola': ['coke', 'coca cola', 'cocacola'],
            'lucky-me': ['lucky me', 'luckymeee'],
            'safeguard': ['safe guard', 'safegard'], 
            'surf': ['surf detergent', 'unilever surf'],
            'hello': ['halo', 'helo', 'hallo'],
            'tm': ['touch mobile', 'tm lucky me'],
            'tang': ['tan', 'teng', 'ten'],
            'voice': ['vois', 'bois', 'voise'],
            'roller-coaster': ['rollercoaster', 'roler', 'rolor'],
            'smart': ['smart communications', 'smar', 'smat'],
            'globe': ['globe telecom', 'glob', 'glof'],
            'tnt': ['talk-n-text', 'talk n text', 'tint', 'tent'],
            'great-taste': ['greattaste', 'gret teis'],
            'magic-flakes': ['magic crackers', 'majik', 'magik'],
            'piattos': ['piatos', 'piatos chips'],
            'oishi': ['oyshi', 'oishi snacks'],
            'marlboro': ['marlbro', 'malboro'],
            'nescafe': ['nescafé', 'nes cafe'],
            'kopiko': ['kopiko coffee', 'kopico'],
            'sprite': ['sprit', 'spirte'],
            'pepsi': ['pepsi cola', 'pesi'],
            'colgate': ['colgeit', 'colget'],
            'palmolive': ['palmoliv', 'palmolieve'],
            'sunsilk': ['sunslik', 'sunsilk shampoo'],
            'datu-puti': ['datuputi', 'datu puti vinegar'],
            'silver-swan': ['silverswan', 'silver swan soy sauce']
        }
        
        # Save aliases to YAML
        aliases_file = Path(OUT_DIR) / "aliases.yml"
        with open(aliases_file, 'w', encoding='utf-8') as f:
            yaml.dump({'aliases': aliases}, f, default_flow_style=False, allow_unicode=True)
        
        self.aliases = aliases
        print(f"Created aliases for {len(aliases)} brands")

if __name__ == "__main__":
    generator = BrandKnowledgeGenerator()
    generator.load_csv_data()
    generator.create_aliases_map()
    
    print("\n=== Brand Data Processing Complete ===")
    print(f"Total brands: {len(generator.brands)}")
    print(f"Categories: {len(generator.categories)}")
    print(f"Sources: {len(generator.sources)}")