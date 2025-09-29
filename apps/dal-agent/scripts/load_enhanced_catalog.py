#!/usr/bin/env python3
"""
Enhanced Catalog Loader for Scout v7
Processes 1,100+ brands with lexical variations and conversation patterns
Created: 2025-09-26
"""

import json
import sys
import os
import pyodbc
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional

# Configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'{PROJECT_ROOT}/out/catalog_loader.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class EnhancedCatalogLoader:
    """Loads enhanced catalog data from JSON into Scout v7 database"""

    def __init__(self, connection_string: str):
        self.connection_string = connection_string
        self.connection = None
        self.cursor = None

    def connect(self):
        """Establish database connection"""
        try:
            self.connection = pyodbc.connect(self.connection_string)
            self.cursor = self.connection.cursor()
            logger.info("Database connection established")
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise

    def disconnect(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        logger.info("Database connection closed")

    def load_nielsen_categories(self, categories_data: Dict[str, Any]):
        """Load Nielsen category master data"""
        logger.info("Loading Nielsen categories...")

        # Clear existing data
        self.cursor.execute("DELETE FROM dbo.nielsen_categories")

        for category_code, category_info in categories_data.items():
            sql = """
            INSERT INTO dbo.nielsen_categories
            (nielsen_category, category_name, category_prefix, total_brands, is_active)
            VALUES (?, ?, ?, ?, 1)
            """

            # Extract category name from code (remove prefix numbers)
            category_name = category_code.split('_', 1)[1].replace('_', ' ').title()

            self.cursor.execute(sql, (
                category_code,
                category_name,
                category_info.get('prefix', ''),
                category_info.get('brands', 0)
            ))

        self.connection.commit()
        logger.info(f"Loaded {len(categories_data)} Nielsen categories")

    def load_brands(self, brands_data: Dict[str, Any], metadata: Dict[str, Any]):
        """Load enhanced brand catalog with lexical variations"""
        logger.info("Loading enhanced brand catalog...")

        # Clear existing data
        self.cursor.execute("DELETE FROM dbo.brand_lexical_variations")
        self.cursor.execute("DELETE FROM dbo.enhanced_brand_catalog")

        total_brands = 0
        total_variations = 0

        for brand_id, brand_info in brands_data.items():
            # Insert brand
            brand_sql = """
            INSERT INTO dbo.enhanced_brand_catalog
            (brand_id, brand_name, brand_name_normalized, nielsen_category,
             tbwa_client_id, is_active, created_date)
            VALUES (?, ?, ?, ?, ?, 1, SYSUTCDATETIME())
            """

            normalized_name = brand_info['brand_name'].lower().strip()

            self.cursor.execute(brand_sql, (
                brand_id,
                brand_info['brand_name'],
                normalized_name,
                brand_info.get('nielsen_category', ''),
                brand_info.get('tbwa_client', '')
            ))

            # Insert lexical variations
            if 'lexical_variations' in brand_info:
                for variation_type, variations in brand_info['lexical_variations'].items():
                    for variation_text in variations:
                        variation_sql = """
                        INSERT INTO dbo.brand_lexical_variations
                        (brand_id, variation_type, variation_text, confidence_weight,
                         language_code, created_date)
                        VALUES (?, ?, ?, ?, 'fil-PH', SYSUTCDATETIME())
                        """

                        # Set confidence weights based on variation type
                        confidence_weights = {
                            'formal': 1.0,
                            'informal': 0.9,
                            'code_switched': 0.8,
                            'abbreviated': 0.7
                        }

                        confidence = confidence_weights.get(variation_type, 0.8)

                        self.cursor.execute(variation_sql, (
                            brand_id,
                            variation_type,
                            variation_text,
                            confidence
                        ))
                        total_variations += 1

            total_brands += 1

            if total_brands % 100 == 0:
                logger.info(f"Processed {total_brands} brands...")

        self.connection.commit()
        logger.info(f"Loaded {total_brands} brands with {total_variations} lexical variations")

    def load_skus(self, brands_data: Dict[str, Any]):
        """Load enhanced SKU catalog"""
        logger.info("Loading enhanced SKU catalog...")

        # Clear existing data
        self.cursor.execute("DELETE FROM dbo.enhanced_sku_catalog")

        total_skus = 0

        for brand_id, brand_info in brands_data.items():
            if 'skus' in brand_info:
                for sku_id in brand_info['skus']:
                    sku_sql = """
                    INSERT INTO dbo.enhanced_sku_catalog
                    (sku_id, brand_id, sku_name, nielsen_category, is_active, created_date)
                    VALUES (?, ?, ?, ?, 1, SYSUTCDATETIME())
                    """

                    # Generate SKU name from brand and SKU ID
                    sku_name = f"{brand_info['brand_name']} - {sku_id}"

                    self.cursor.execute(sku_sql, (
                        sku_id,
                        brand_id,
                        sku_name,
                        brand_info.get('nielsen_category', '')
                    ))
                    total_skus += 1

        self.connection.commit()
        logger.info(f"Loaded {total_skus} SKUs")

    def load_conversation_patterns(self, patterns_data: Dict[str, Any]):
        """Load Filipino conversation patterns"""
        logger.info("Loading Filipino conversation patterns...")

        # Clear existing data
        self.cursor.execute("DELETE FROM dbo.filipino_conversation_patterns")

        total_patterns = 0

        for pattern_category, patterns in patterns_data.items():
            for pattern_text in patterns:
                pattern_sql = """
                INSERT INTO dbo.filipino_conversation_patterns
                (pattern_category, pattern_text, language_mix, politeness_level,
                 frequency_weight, cultural_context, is_active)
                VALUES (?, ?, ?, ?, 1.0, ?, 1)
                """

                # Determine language mix
                if any(word in pattern_text.lower() for word in ['pabili', 'magkano', 'meron', 'ubos']):
                    language_mix = 'filipino'
                    politeness = 4 if 'po' in pattern_text else 3
                elif pattern_text.lower() in ['available', 'okay']:
                    language_mix = 'english'
                    politeness = 3
                else:
                    language_mix = 'code_switched'
                    politeness = 3

                cultural_context = f"Common {pattern_category} pattern in Filipino retail"

                self.cursor.execute(pattern_sql, (
                    pattern_category,
                    pattern_text,
                    language_mix,
                    politeness,
                    cultural_context
                ))
                total_patterns += 1

        self.connection.commit()
        logger.info(f"Loaded {total_patterns} conversation patterns")

    def create_indexes(self):
        """Create additional performance indexes"""
        logger.info("Creating performance indexes...")

        indexes = [
            "CREATE INDEX IX_brand_lexical_text ON dbo.brand_lexical_variations(variation_text)",
            "CREATE INDEX IX_brand_nielsen ON dbo.enhanced_brand_catalog(nielsen_category)",
            "CREATE INDEX IX_sku_brand ON dbo.enhanced_sku_catalog(brand_id, nielsen_category)",
            "CREATE INDEX IX_pattern_text ON dbo.filipino_conversation_patterns(pattern_text)"
        ]

        for index_sql in indexes:
            try:
                self.cursor.execute(index_sql)
                logger.info(f"Created index: {index_sql.split()[2]}")
            except Exception as e:
                if "already exists" not in str(e):
                    logger.warning(f"Index creation failed: {e}")

        self.connection.commit()
        logger.info("Index creation completed")

    def validate_data(self):
        """Validate loaded data"""
        logger.info("Validating loaded data...")

        validations = [
            ("Enhanced brands", "SELECT COUNT(*) FROM dbo.enhanced_brand_catalog"),
            ("Lexical variations", "SELECT COUNT(*) FROM dbo.brand_lexical_variations"),
            ("Enhanced SKUs", "SELECT COUNT(*) FROM dbo.enhanced_sku_catalog"),
            ("Nielsen categories", "SELECT COUNT(*) FROM dbo.nielsen_categories"),
            ("Conversation patterns", "SELECT COUNT(*) FROM dbo.filipino_conversation_patterns"),
            ("TBWA client brands", "SELECT COUNT(*) FROM dbo.enhanced_brand_catalog WHERE tbwa_client_id IS NOT NULL AND tbwa_client_id != ''"),
            ("Brands with variations", "SELECT COUNT(DISTINCT brand_id) FROM dbo.brand_lexical_variations")
        ]

        validation_results = {}
        for name, query in validations:
            self.cursor.execute(query)
            count = self.cursor.fetchone()[0]
            validation_results[name] = count
            logger.info(f"{name}: {count:,}")

        return validation_results

def get_connection_string():
    """Get database connection string from environment or keychain"""
    import subprocess

    # Try keychain first
    try:
        result = subprocess.run([
            'security', 'find-generic-password',
            '-s', 'SQL-TBWA-ProjectScout-Reporting-Prod',
            '-a', 'scout-analytics',
            '-w'
        ], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        pass

    # Try environment variable
    conn_str = os.environ.get('AZURE_SQL_CONN_STR')
    if conn_str:
        return conn_str

    raise ValueError("No database connection string found. Set AZURE_SQL_CONN_STR or add to keychain.")

def main():
    """Main execution function"""
    if len(sys.argv) != 2:
        print("Usage: python3 load_enhanced_catalog.py <json_file>")
        print("Example: python3 load_enhanced_catalog.py data/enhanced_catalog.json")
        sys.exit(1)

    json_file = sys.argv[1]

    if not os.path.exists(json_file):
        logger.error(f"JSON file not found: {json_file}")
        sys.exit(1)

    # Load JSON data
    logger.info(f"Loading JSON data from: {json_file}")
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Validate JSON structure
    required_keys = ['metadata', 'sample_brands', 'nielsen_categories', 'conversation_patterns']
    for key in required_keys:
        if key not in data:
            logger.error(f"Missing required key in JSON: {key}")
            sys.exit(1)

    # Get connection string
    try:
        conn_str = get_connection_string()
    except ValueError as e:
        logger.error(str(e))
        sys.exit(1)

    # Load data
    loader = EnhancedCatalogLoader(conn_str)

    try:
        loader.connect()

        # Load in sequence
        loader.load_nielsen_categories(data['nielsen_categories'])
        loader.load_brands(data['sample_brands'], data['metadata'])
        loader.load_skus(data['sample_brands'])
        loader.load_conversation_patterns(data['conversation_patterns'])
        loader.create_indexes()

        # Validate
        results = loader.validate_data()

        # Success summary
        logger.info("=" * 50)
        logger.info("ENHANCED CATALOG LOAD COMPLETED SUCCESSFULLY")
        logger.info("=" * 50)
        logger.info(f"Total brands: {results['Enhanced brands']:,}")
        logger.info(f"Total SKUs: {results['Enhanced SKUs']:,}")
        logger.info(f"Total lexical variations: {results['Lexical variations']:,}")
        logger.info(f"TBWA client brands: {results['TBWA client brands']:,}")
        logger.info(f"Conversation patterns: {results['Conversation patterns']:,}")
        logger.info("=" * 50)

    except Exception as e:
        logger.error(f"Catalog loading failed: {e}")
        sys.exit(1)

    finally:
        loader.disconnect()

if __name__ == "__main__":
    main()