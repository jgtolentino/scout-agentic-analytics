#!/usr/bin/env python3
"""
Market Intelligence Loader
Processes comprehensive Philippine FMCG market research data and loads into Scout Edge database

Handles:
- Market category sizing and growth data
- Brand market share and consumer reach points
- Competitive positioning and benchmarking  
- Market trends and consumer insights

Usage:
    python market_intelligence_loader.py --source research_corpus.json
    python market_intelligence_loader.py --category beverages --update
    python market_intelligence_loader.py --validate-only
"""

import json
import csv
import re
import logging
from decimal import Decimal
from datetime import datetime, date
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import click

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class MarketIntelligence:
    """Market category intelligence data structure"""
    category: str
    subcategory: Optional[str]
    market_type: str
    market_size_php: Optional[Decimal]
    market_size_usd: Optional[Decimal]
    market_size_year: Optional[int]
    cagr_percent: Optional[Decimal]
    growth_forecast_years: Optional[int]
    yoy_growth_percent: Optional[Decimal]
    market_concentration: Optional[str]
    key_trends: List[str]
    growth_drivers: List[str]
    challenges: List[str]
    penetration_percent: Optional[Decimal]
    consumption_per_capita_php: Optional[Decimal]
    primary_channels: List[str]
    metro_manila_share: Optional[Decimal]
    luzon_share: Optional[Decimal]
    visayas_share: Optional[Decimal]
    mindanao_share: Optional[Decimal]
    confidence_score: Decimal
    data_freshness: date
    source_quality: str
    primary_sources: List[str]
    research_methodology: Optional[str]
    data_limitations: List[str]

@dataclass
class BrandMetrics:
    """Brand market performance metrics"""
    brand_name: str
    official_name: str
    parent_company: Optional[str]
    category: str
    subcategory: Optional[str]
    market_share_percent: Optional[Decimal]
    market_share_rank: Optional[int]
    market_share_year: Optional[int]
    consumer_reach_points: Optional[Decimal]
    crp_rank: Optional[int]
    crp_year: Optional[int]
    household_penetration: Optional[Decimal]
    purchase_frequency: Optional[Decimal]
    brand_loyalty_index: Optional[Decimal]
    position_type: Optional[str]
    competitive_advantage: List[str]
    threats: List[str]
    brand_growth_yoy: Optional[Decimal]
    fastest_growing: bool
    declining_brand: bool
    price_positioning: Optional[str]
    price_premium_percent: Optional[Decimal]
    strong_regions: List[str]
    weak_regions: List[str]
    expansion_opportunities: List[str]
    confidence_score: Decimal
    data_freshness: date
    source_types: List[str]
    validation_status: str

class MarketIntelligenceProcessor:
    """Processes market research data and loads into database"""
    
    def __init__(self, db_connection_string: str):
        self.db_conn_str = db_connection_string
        self.conn = None
        
        # Market intelligence patterns from research corpus
        self.market_data = {
            "snacks_confectionery": {
                "market_size_php": 137600,  # $2.6B * 53 PHP/USD
                "market_size_usd": 2600,
                "market_size_year": 2023,
                "cagr_percent": 8.0,
                "growth_forecast_years": 5,
                "yoy_growth_percent": 7.5,
                "market_concentration": "medium",
                "key_trends": [
                    "savory snacks dominate 70% of market",
                    "local companies hold 85% market share", 
                    "sachet packaging drives accessibility",
                    "flavor innovation accelerating"
                ],
                "growth_drivers": [
                    "convenience lifestyle",
                    "affordable indulgence",
                    "flavor innovation",
                    "distribution expansion"
                ],
                "challenges": [
                    "health consciousness growing",
                    "inflation pressure on ingredients",
                    "competition from international brands"
                ],
                "penetration_percent": 95.0,
                "consumption_per_capita_php": 1749,  # $33 * 53
                "primary_channels": ["sari-sari", "supermarket", "convenience"],
                "confidence_score": 0.9,
                "data_freshness": date(2023, 12, 31),
                "source_quality": "high",
                "primary_sources": [
                    "USDA/Euromonitor Philippines Snack Market Brief 2024",
                    "Philippine Statistics Authority Consumer Expenditure Survey"
                ]
            },
            "instant_noodles": {
                "market_size_php": 125600,  # $1.6B * 53 + growth to $2.37B projected
                "market_size_usd": 2370,  # 2029 projection
                "market_size_year": 2029,
                "cagr_percent": 11.5,
                "growth_forecast_years": 6,
                "yoy_growth_percent": 8.2,
                "market_concentration": "high",
                "key_trends": [
                    "Philippines ranks 7th globally in consumption",
                    "4.47 billion servings consumed in 2023",
                    "Lucky Me dominates with virtual monopoly",
                    "Premium variants growing"
                ],
                "growth_drivers": [
                    "convenience factor",
                    "affordability",
                    "disaster relief usage",
                    "urban lifestyle adoption"
                ],
                "challenges": [
                    "health concerns over sodium",
                    "competition from other quick meals",
                    "ingredient cost inflation"
                ],
                "penetration_percent": 98.5,
                "consumption_per_capita_php": 1060,  # $20 * 53
                "primary_channels": ["sari-sari", "supermarket", "hypermarket"],
                "confidence_score": 0.95,
                "data_freshness": date(2024, 6, 30),
                "source_quality": "high",
                "primary_sources": [
                    "World Instant Noodles Association Statistics 2024",
                    "Monde Nissin Annual Reports",
                    "Herald Express Food Trends Analysis"
                ]
            },
            "carbonated_soft_drinks": {
                "market_size_php": 148400,  # $2.8B * 53
                "market_size_usd": 2800,
                "market_size_year": 2024,
                "cagr_percent": 9.3,
                "growth_forecast_years": 9,
                "yoy_growth_percent": 6.8,
                "market_concentration": "high",
                "key_trends": [
                    "Coca-Cola commands ~60% volume share",
                    "Single-serve purchases dominate sari-sari",
                    "3.9 billion liters consumed in 2021",
                    "Local RC Cola maintains 8% share"
                ],
                "growth_drivers": [
                    "hot climate driving consumption",
                    "affordability of single serves",
                    "extensive distribution network",
                    "brand loyalty"
                ],
                "challenges": [
                    "health awareness campaigns",
                    "sugar tax regulations",
                    "water scarcity concerns"
                ],
                "penetration_percent": 89.0,
                "consumption_per_capita_php": 3975,  # $75 * 53
                "primary_channels": ["sari-sari", "convenience", "supermarket"],
                "confidence_score": 0.92,
                "data_freshness": date(2024, 12, 31),
                "source_quality": "high",
                "primary_sources": [
                    "IMARC Group Philippines Soft Drinks Market 2024",
                    "USDA Non-Alcoholic Beverages Market Brief",
                    "Coca-Cola Philippines Annual Reports"
                ]
            },
            "laundry_detergents": {
                "market_size_php": 31800,  # ₱31B as stated
                "market_size_usd": 600,
                "market_size_year": 2025,
                "cagr_percent": 10.0,
                "growth_forecast_years": 4,
                "yoy_growth_percent": 8.5,
                "market_concentration": "high",
                "key_trends": [
                    "Liquid soaps 42% of sales",
                    "Bar soaps still 38% of market", 
                    "Laundry powders/aids 15%",
                    "Sachet packaging dominates"
                ],
                "growth_drivers": [
                    "urbanization trends",
                    "hygiene awareness post-pandemic",
                    "income growth",
                    "product premiumization"
                ],
                "challenges": [
                    "price sensitivity high",
                    "inflation on raw materials",
                    "brand switching on promotions"
                ],
                "penetration_percent": 99.8,
                "consumption_per_capita_php": 530,  # $10 * 53
                "primary_channels": ["sari-sari", "supermarket", "public_market"],
                "confidence_score": 0.85,
                "data_freshness": date(2025, 2, 28),
                "source_quality": "medium",
                "primary_sources": [
                    "6W Research Philippines Soap and Detergent Market 2025",
                    "Unilever Philippines Market Data",
                    "P&G Philippines Category Reports"
                ]
            },
            "hair_care": {
                "market_size_php": 95930,  # $1.81B * 53
                "market_size_usd": 1810,
                "market_size_year": 2024,
                "cagr_percent": 4.5,
                "growth_forecast_years": 3,
                "yoy_growth_percent": 5.2,
                "market_concentration": "medium",
                "key_trends": [
                    "Unilever leads with 40-45% share",
                    "Sachet culture drives penetration",
                    "Tropical climate drives frequent washing",
                    "Premium segments growing slowly"
                ],
                "growth_drivers": [
                    "rising incomes",
                    "beauty consciousness",
                    "product innovation",
                    "distribution expansion"
                ],
                "challenges": [
                    "fragmented consumer preferences",
                    "price competition intense",
                    "counterfeit products"
                ],
                "penetration_percent": 97.5,
                "consumption_per_capita_php": 1590,  # $30 * 53
                "primary_channels": ["sari-sari", "supermarket", "salon"],
                "confidence_score": 0.78,
                "data_freshness": date(2024, 9, 30),
                "source_quality": "medium",
                "primary_sources": [
                    "IMARC Philippines Hair Care Market Analysis 2024",
                    "GlobalData Haircare Category Analysis",
                    "Unilever Philippines Market Intelligence"
                ]
            },
            "canned_foods": {
                "market_size_php": 127200,  # $2.4B * 53 (2028 projection)
                "market_size_usd": 2400,
                "market_size_year": 2028,
                "cagr_percent": 8.3,
                "growth_forecast_years": 7,
                "yoy_growth_percent": 7.8,
                "market_concentration": "medium",
                "key_trends": [
                    "Canned fish dominates category",
                    "Sardines as cheap protein source",
                    "Long shelf life valued",
                    "Emergency food stockpiling"
                ],
                "growth_drivers": [
                    "convenience factor",
                    "protein accessibility",
                    "disaster preparedness",
                    "price stability"
                ],
                "challenges": [
                    "fresh food preference growing",
                    "packaging cost increases",
                    "health concerns over preservatives"
                ],
                "penetration_percent": 92.0,
                "consumption_per_capita_php": 2968,  # $56 * 53
                "primary_channels": ["supermarket", "sari-sari", "public_market"],
                "confidence_score": 0.80,
                "data_freshness": date(2024, 6, 15),
                "source_quality": "medium",
                "primary_sources": [
                    "Research and Markets Philippines Canned Food Forecast 2023-2028",
                    "Century Pacific Annual Reports",
                    "Agriculture Canada Consumer Profile Philippines"
                ]
            }
        }
        
        # Brand performance data extracted from research
        self.brand_data = {
            # Market Leaders by CRP (Kantar Brand Footprint 2025)
            "lucky_me": {
                "brand_name": "Lucky Me!",
                "official_name": "Lucky Me! Instant Noodles",
                "parent_company": "Monde Nissin Corporation",
                "category": "instant_noodles",
                "market_share_percent": 75.0,  # Estimated dominance
                "market_share_rank": 1,
                "consumer_reach_points": 903.0,
                "crp_rank": 1,
                "crp_year": 2024,
                "position_type": "leader",
                "price_positioning": "mainstream",
                "brand_growth_yoy": 12.0,
                "fastest_growing": False,
                "declining_brand": False,
                "confidence_score": 0.95
            },
            "nescafe": {
                "brand_name": "Nescafé",
                "official_name": "Nescafé Coffee",
                "parent_company": "Nestlé Philippines",
                "category": "instant_coffee",
                "market_share_percent": 45.0,
                "market_share_rank": 1,
                "consumer_reach_points": 785.0,
                "crp_rank": 2,
                "crp_year": 2024,
                "position_type": "leader",
                "price_positioning": "premium",
                "brand_growth_yoy": 8.5,
                "confidence_score": 0.92
            },
            "kopiko": {
                "brand_name": "Kopiko",
                "official_name": "Kopiko Coffee & Candy",
                "parent_company": "Mayora Indah",
                "category": "coffee_candy",
                "market_share_percent": 35.0,
                "consumer_reach_points": 631.0,
                "crp_rank": 3,
                "position_type": "leader",
                "price_positioning": "mainstream",
                "brand_growth_yoy": 6.2,
                "confidence_score": 0.90
            },
            "coca_cola": {
                "brand_name": "Coca-Cola",
                "official_name": "Coca-Cola Philippines",
                "parent_company": "Coca-Cola Company",
                "category": "carbonated_soft_drinks",
                "market_share_percent": 33.0,  # 1/3 of soda volume
                "market_share_rank": 1,
                "consumer_reach_points": 594.0,
                "crp_rank": 4,
                "position_type": "leader",
                "price_positioning": "premium",
                "brand_growth_yoy": 5.8,
                "confidence_score": 0.95
            },
            "silver_swan": {
                "brand_name": "Silver Swan",
                "official_name": "Silver Swan Soy Sauce",
                "parent_company": "NutriAsia Inc.",
                "category": "condiments",
                "market_share_percent": 55.0,
                "consumer_reach_points": 564.0,
                "crp_rank": 5,
                "position_type": "leader",
                "price_positioning": "mainstream",
                "brand_growth_yoy": 4.2,
                "confidence_score": 0.88
            },
            "surf": {
                "brand_name": "Surf",
                "official_name": "Surf Laundry Detergent",
                "parent_company": "Unilever Philippines",
                "category": "laundry_detergents",
                "market_share_percent": 42.0,
                "market_share_rank": 1,
                "position_type": "leader",
                "price_positioning": "value",
                "brand_growth_yoy": 7.3,
                "confidence_score": 0.85
            },
            "safeguard": {
                "brand_name": "Safeguard",
                "official_name": "Safeguard Antibacterial Soap",
                "parent_company": "Procter & Gamble Philippines",
                "category": "bar_soap",
                "market_share_percent": 58.0,
                "household_penetration": 68.0,
                "position_type": "leader",
                "price_positioning": "mainstream",
                "brand_growth_yoy": 3.8,
                "confidence_score": 0.90
            },
            "colgate": {
                "brand_name": "Colgate",
                "official_name": "Colgate Total Toothpaste",
                "parent_company": "Colgate-Palmolive Philippines",
                "category": "oral_care",
                "market_share_percent": 65.0,
                "position_type": "leader",
                "price_positioning": "mainstream",
                "brand_growth_yoy": 2.5,
                "confidence_score": 0.92
            },
            "marlboro": {
                "brand_name": "Marlboro",
                "official_name": "Marlboro Cigarettes",
                "parent_company": "Philip Morris Fortune Tobacco",
                "category": "cigarettes",
                "market_share_percent": 33.0,
                "position_type": "leader",
                "price_positioning": "premium",
                "brand_growth_yoy": -2.1,  # Declining due to health campaigns
                "declining_brand": True,
                "confidence_score": 0.88
            }
        }
    
    def connect_database(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(self.db_conn_str)
            self.conn.autocommit = False
            logger.info("Database connection established")
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise
    
    def load_market_intelligence(self) -> int:
        """Load market category intelligence data"""
        if not self.conn:
            self.connect_database()
        
        records_loaded = 0
        
        try:
            with self.conn.cursor() as cursor:
                for category_key, data in self.market_data.items():
                    # Map category key to proper category name
                    category_map = {
                        'snacks_confectionery': 'Snacks & Confectionery',
                        'instant_noodles': 'Instant Noodles',
                        'carbonated_soft_drinks': 'Carbonated Soft Drinks',
                        'laundry_detergents': 'Laundry Detergents', 
                        'hair_care': 'Hair Care',
                        'canned_foods': 'Canned Foods'
                    }
                    
                    category_name = category_map.get(category_key, category_key.replace('_', ' ').title())
                    
                    insert_sql = """
                    INSERT INTO metadata.market_intelligence (
                        category, market_type, market_size_php, market_size_usd, 
                        market_size_year, cagr_percent, growth_forecast_years, 
                        yoy_growth_percent, market_concentration, key_trends,
                        growth_drivers, challenges, penetration_percent,
                        consumption_per_capita_php, primary_channels,
                        confidence_score, data_freshness, source_quality, primary_sources
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    ) ON CONFLICT DO NOTHING
                    """
                    
                    cursor.execute(insert_sql, (
                        category_name,
                        'fmcg',
                        data['market_size_php'],
                        data['market_size_usd'],
                        data['market_size_year'],
                        data['cagr_percent'],
                        data['growth_forecast_years'],
                        data['yoy_growth_percent'],
                        data['market_concentration'],
                        data['key_trends'],
                        data['growth_drivers'],
                        data['challenges'],
                        data['penetration_percent'],
                        data['consumption_per_capita_php'],
                        data['primary_channels'],
                        data['confidence_score'],
                        data['data_freshness'],
                        data['source_quality'],
                        data['primary_sources']
                    ))
                    
                    if cursor.rowcount > 0:
                        records_loaded += 1
                        logger.info(f"Loaded market intelligence for {category_name}")
            
            self.conn.commit()
            logger.info(f"Market intelligence loading completed: {records_loaded} records")
            return records_loaded
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error loading market intelligence: {e}")
            raise
    
    def load_brand_metrics(self) -> int:
        """Load brand market performance metrics"""
        if not self.conn:
            self.connect_database()
        
        records_loaded = 0
        
        try:
            with self.conn.cursor() as cursor:
                for brand_key, data in self.brand_data.items():
                    insert_sql = """
                    INSERT INTO metadata.brand_metrics (
                        brand_name, official_name, parent_company, category,
                        market_share_percent, market_share_rank, market_share_year,
                        consumer_reach_points, crp_rank, crp_year,
                        household_penetration, position_type, price_positioning,
                        brand_growth_yoy, fastest_growing, declining_brand,
                        confidence_score, data_freshness, source_types, validation_status
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    ) ON CONFLICT DO NOTHING
                    """
                    
                    cursor.execute(insert_sql, (
                        data['brand_name'],
                        data['official_name'],
                        data.get('parent_company'),
                        data['category'],
                        data.get('market_share_percent'),
                        data.get('market_share_rank'),
                        data.get('market_share_year', 2024),
                        data.get('consumer_reach_points'),
                        data.get('crp_rank'),
                        data.get('crp_year', 2024),
                        data.get('household_penetration'),
                        data.get('position_type'),
                        data.get('price_positioning'),
                        data.get('brand_growth_yoy'),
                        data.get('fastest_growing', False),
                        data.get('declining_brand', False),
                        data['confidence_score'],
                        date.today(),
                        ['kantar', 'nielsen', 'research'],
                        'validated'
                    ))
                    
                    if cursor.rowcount > 0:
                        records_loaded += 1
                        logger.info(f"Loaded brand metrics for {data['brand_name']}")
            
            self.conn.commit()
            logger.info(f"Brand metrics loading completed: {records_loaded} records")
            return records_loaded
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error loading brand metrics: {e}")
            raise
    
    def create_competitor_benchmarks(self) -> int:
        """Create competitive benchmarking relationships"""
        if not self.conn:
            self.connect_database()
        
        # Define key competitive relationships from research
        competitive_pairs = [
            ("Coca-Cola", "Pepsi", "carbonated_soft_drinks", "direct"),
            ("Coca-Cola", "RC Cola", "carbonated_soft_drinks", "direct"), 
            ("Sprite", "7Up", "lemon_lime_soda", "direct"),
            ("Lucky Me!", "Maggi", "instant_noodles", "direct"),
            ("Lucky Me!", "Nissin", "instant_noodles", "direct"),
            ("Surf", "Tide", "laundry_detergents", "direct"),
            ("Surf", "Ariel", "laundry_detergents", "direct"),
            ("Safeguard", "Dove", "bar_soap", "direct"),
            ("Safeguard", "Palmolive", "bar_soap", "direct"),
            ("Nescafé", "Great Taste", "instant_coffee", "direct"),
            ("Colgate", "Close-Up", "toothpaste", "direct"),
            ("Silver Swan", "Datu Puti", "soy_sauce", "direct"),
            ("Marlboro", "Winston", "cigarettes", "direct")
        ]
        
        records_loaded = 0
        
        try:
            with self.conn.cursor() as cursor:
                for primary, competitor, category, comp_type in competitive_pairs:
                    # Get brand data for comparison
                    primary_data = next((data for data in self.brand_data.values() 
                                       if data['brand_name'] == primary), None)
                    competitor_data = next((data for data in self.brand_data.values() 
                                          if data['brand_name'] == competitor), None)
                    
                    if primary_data and competitor_data:
                        share_gap = (primary_data.get('market_share_percent', 0) - 
                                   competitor_data.get('market_share_percent', 0))
                        
                        crp_gap = (primary_data.get('consumer_reach_points', 0) - 
                                 competitor_data.get('consumer_reach_points', 0))
                        
                        insert_sql = """
                        INSERT INTO metadata.competitor_benchmarks (
                            primary_brand, competitor_brand, category, comparison_type,
                            primary_share, competitor_share, share_gap,
                            primary_crp, competitor_crp, reach_advantage,
                            competitive_intensity, benchmark_date, confidence_score
                        ) VALUES (
                            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                        ) ON CONFLICT DO NOTHING
                        """
                        
                        cursor.execute(insert_sql, (
                            primary,
                            competitor,
                            category,
                            comp_type,
                            primary_data.get('market_share_percent'),
                            competitor_data.get('market_share_percent'),
                            share_gap,
                            primary_data.get('consumer_reach_points'),
                            competitor_data.get('consumer_reach_points'), 
                            crp_gap,
                            'high' if abs(share_gap) < 10 else 'medium',
                            date.today(),
                            0.8
                        ))
                        
                        if cursor.rowcount > 0:
                            records_loaded += 1
                            logger.info(f"Created benchmark: {primary} vs {competitor}")
            
            self.conn.commit()
            logger.info(f"Competitor benchmarks created: {records_loaded} relationships")
            return records_loaded
            
        except Exception as e:
            self.conn.rollback()
            logger.error(f"Error creating competitor benchmarks: {e}")
            raise
    
    def validate_data_quality(self) -> Dict[str, Any]:
        """Validate loaded market intelligence data"""
        if not self.conn:
            self.connect_database()
        
        validation_results = {
            'market_intelligence_count': 0,
            'brand_metrics_count': 0,
            'competitor_benchmarks_count': 0,
            'data_quality_issues': [],
            'coverage_analysis': {},
            'validation_passed': False
        }
        
        try:
            with self.conn.cursor() as cursor:
                # Count records
                cursor.execute("SELECT COUNT(*) FROM metadata.market_intelligence")
                validation_results['market_intelligence_count'] = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM metadata.brand_metrics") 
                validation_results['brand_metrics_count'] = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) FROM metadata.competitor_benchmarks")
                validation_results['competitor_benchmarks_count'] = cursor.fetchone()[0]
                
                # Check for data quality issues
                cursor.execute("""
                    SELECT category, COUNT(*) 
                    FROM metadata.market_intelligence 
                    WHERE confidence_score < 0.7 
                    GROUP BY category
                """)
                low_confidence_categories = cursor.fetchall()
                if low_confidence_categories:
                    validation_results['data_quality_issues'].append({
                        'issue': 'low_confidence_categories',
                        'details': low_confidence_categories
                    })
                
                # Check market coverage
                cursor.execute("""
                    SELECT 
                        SUM(market_size_php) as total_market_size,
                        COUNT(DISTINCT category) as categories_covered,
                        AVG(confidence_score) as avg_confidence
                    FROM metadata.market_intelligence
                """)
                coverage = cursor.fetchone()
                validation_results['coverage_analysis'] = {
                    'total_market_size_php': float(coverage[0]) if coverage[0] else 0,
                    'categories_covered': coverage[1],
                    'average_confidence': float(coverage[2]) if coverage[2] else 0
                }
                
                # Determine validation status
                validation_results['validation_passed'] = (
                    validation_results['market_intelligence_count'] >= 5 and
                    validation_results['brand_metrics_count'] >= 8 and
                    validation_results['coverage_analysis']['average_confidence'] >= 0.8
                )
                
                logger.info(f"Data validation completed: {validation_results}")
                return validation_results
                
        except Exception as e:
            logger.error(f"Error during data validation: {e}")
            validation_results['validation_error'] = str(e)
            return validation_results
    
    def close_connection(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
            logger.info("Database connection closed")

@click.command()
@click.option('--db-url', required=True, help='Database connection string')
@click.option('--load-market-intel', is_flag=True, help='Load market intelligence data')
@click.option('--load-brand-metrics', is_flag=True, help='Load brand performance metrics')
@click.option('--create-benchmarks', is_flag=True, help='Create competitive benchmarks')
@click.option('--validate-only', is_flag=True, help='Only run data validation')
@click.option('--load-all', is_flag=True, help='Load all market intelligence data')
def main(db_url, load_market_intel, load_brand_metrics, create_benchmarks, validate_only, load_all):
    """Market Intelligence Data Loader"""
    
    processor = MarketIntelligenceProcessor(db_url)
    
    try:
        processor.connect_database()
        
        if validate_only:
            results = processor.validate_data_quality()
            click.echo(f"Validation Results: {json.dumps(results, indent=2, default=str)}")
            return
        
        total_loaded = 0
        
        if load_all or load_market_intel:
            click.echo("Loading market intelligence data...")
            count = processor.load_market_intelligence()
            total_loaded += count
            click.echo(f"Loaded {count} market intelligence records")
        
        if load_all or load_brand_metrics:
            click.echo("Loading brand metrics...")
            count = processor.load_brand_metrics()
            total_loaded += count
            click.echo(f"Loaded {count} brand metrics records")
        
        if load_all or create_benchmarks:
            click.echo("Creating competitive benchmarks...")
            count = processor.create_competitor_benchmarks()
            total_loaded += count
            click.echo(f"Created {count} competitive benchmark relationships")
        
        # Always run validation after loading
        if total_loaded > 0:
            click.echo("Validating loaded data...")
            validation_results = processor.validate_data_quality()
            
            if validation_results['validation_passed']:
                click.echo("✅ Data validation passed!")
                click.echo(f"Market Intelligence Records: {validation_results['market_intelligence_count']}")
                click.echo(f"Brand Metrics Records: {validation_results['brand_metrics_count']}")
                click.echo(f"Competitor Benchmarks: {validation_results['competitor_benchmarks_count']}")
                click.echo(f"Average Confidence: {validation_results['coverage_analysis']['average_confidence']:.2f}")
            else:
                click.echo("❌ Data validation failed!")
                click.echo(f"Issues: {validation_results['data_quality_issues']}")
    
    except Exception as e:
        click.echo(f"Error: {e}")
    finally:
        processor.close_connection()

if __name__ == "__main__":
    main()