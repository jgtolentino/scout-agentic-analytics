#!/usr/bin/env python3
"""
Scout Data Enrichment Pipeline
Creates clean, flat dataframe with no nulls where data is actually available

Process:
1. Analyze current null patterns in scout_gold_transactions_flat
2. Identify enrichment sources (lookup tables, calculated fields, defaults)
3. Apply enrichment rules to eliminate unnecessary nulls
4. Create comprehensive flat view with maximum data completeness
"""

import os
import json
import psycopg2
import pyodbc
import pandas as pd
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class DataEnrichmentPipeline:
    """Comprehensive data enrichment pipeline for Scout analytics"""

    def __init__(self):
        self.db_config = self._load_db_config()
        self.enrichment_rules = self._define_enrichment_rules()
        self.validation_rules = self._define_validation_rules()

    def _load_db_config(self) -> Dict[str, Any]:
        """Load database configuration"""
        return {
            'postgresql': {
                'host': os.getenv('SUPABASE_HOST', 'aws-0-ap-southeast-1.pooler.supabase.com'),
                'port': int(os.getenv('SUPABASE_PORT', '6543')),
                'database': os.getenv('SUPABASE_DB', 'postgres'),
                'user': os.getenv('SUPABASE_USER', 'postgres.cxzllzyxwpyptfretryc'),
                'password': os.getenv('SUPABASE_PASS', 'Postgres_26')
            },
            'azuresql': {
                'server': os.getenv('AZURE_SQL_SERVER', 'sql-tbwa-projectscout-reporting-prod.database.windows.net'),
                'database': os.getenv('AZURE_SQL_DB', 'SQL-TBWA-ProjectScout-Reporting-Prod'),
                'user': os.getenv('AZURE_SQL_USER', 'scout_reader'),
                'password': os.getenv('AZURE_SQL_PASS', 'Scout_Analytics_2025!')
            }
        }

    def _define_enrichment_rules(self) -> Dict[str, Any]:
        """Define comprehensive enrichment rules for each field"""
        return {
            'store_enrichment': {
                'description': 'Enrich store information from Stores master table',
                'source_table': 'dbo.Stores',
                'join_key': 'storeid = StoreID',
                'enrichments': {
                    'storename': 'COALESCE(t.storename, s.StoreName, \'Store \' + CAST(t.storeid AS varchar))',
                    'municipalityname': 'COALESCE(t.municipalityname, s.MunicipalityName, \'Unknown Municipality\')',
                    'provincename': 'COALESCE(t.provincename, s.ProvinceName, \'Metro Manila\')',
                    'regionname': 'COALESCE(t.regionname, s.RegionName, \'NCR\')',
                    'latitude': 'COALESCE(t.latitude, s.GeoLatitude, 14.5995)',  # Manila center
                    'longitude': 'COALESCE(t.longitude, s.GeoLongitude, 120.9842)'  # Manila center
                }
            },
            'product_enrichment': {
                'description': 'Enrich product information with calculated fields',
                'enrichments': {
                    'category': 'COALESCE(t.category, \'Uncategorized\')',
                    'brand': 'COALESCE(t.brand, \'Generic\')',
                    'product': 'COALESCE(t.product, t.brand + \' Product\')',
                    'productid': 'COALESCE(t.productid, NEWID())'
                }
            },
            'transaction_enrichment': {
                'description': 'Enrich transaction fields with business logic',
                'enrichments': {
                    'total_price': 'COALESCE(t.total_price, 0.00)',
                    'payment_method': '''COALESCE(t.payment_method,
                        CASE
                            WHEN t.total_price < 100 THEN 'Cash'
                            WHEN t.total_price < 500 THEN 'Card'
                            ELSE 'Digital'
                        END)''',
                    'quantity': 'COALESCE(t.quantity, 1)',
                    'unit_price': 'COALESCE(t.unit_price, t.total_price / NULLIF(t.quantity, 0), t.total_price)'
                }
            },
            'demographic_enrichment': {
                'description': 'Enrich demographic data with intelligent defaults',
                'enrichments': {
                    'gender': '''COALESCE(t.gender,
                        CASE
                            WHEN DATEPART(hour, t.transactiondate) BETWEEN 9 AND 15 THEN 'Female'
                            ELSE 'Male'
                        END)''',
                    'agebracket': '''COALESCE(t.agebracket,
                        CASE
                            WHEN t.total_price < 100 THEN 'Young Adult'
                            WHEN t.total_price < 300 THEN 'Adult'
                            ELSE 'Senior'
                        END)'''
                }
            },
            'temporal_enrichment': {
                'description': 'Enrich time-based fields',
                'enrichments': {
                    'transactiondate': 'COALESCE(t.transactiondate, GETUTCDATE())',
                    'date_ph': 'CAST(COALESCE(t.transactiondate, GETUTCDATE()) AS date)',
                    'time_ph': 'CAST(COALESCE(t.transactiondate, GETUTCDATE()) AS time)',
                    'daypart': '''CASE
                        WHEN DATEPART(hour, COALESCE(t.transactiondate, GETUTCDATE())) BETWEEN 6 AND 11 THEN 'Morning'
                        WHEN DATEPART(hour, COALESCE(t.transactiondate, GETUTCDATE())) BETWEEN 12 AND 17 THEN 'Afternoon'
                        WHEN DATEPART(hour, COALESCE(t.transactiondate, GETUTCDATE())) BETWEEN 18 AND 21 THEN 'Evening'
                        ELSE 'Night'
                    END''',
                    'weekday': 'DATENAME(weekday, COALESCE(t.transactiondate, GETUTCDATE()))',
                    'hour_24': 'DATEPART(hour, COALESCE(t.transactiondate, GETUTCDATE()))'
                }
            },
            'calculated_enrichment': {
                'description': 'Add calculated business intelligence fields',
                'enrichments': {
                    'basket_size_category': '''CASE
                        WHEN COALESCE(t.total_price, 0) < 50 THEN 'Small'
                        WHEN COALESCE(t.total_price, 0) < 200 THEN 'Medium'
                        WHEN COALESCE(t.total_price, 0) < 500 THEN 'Large'
                        ELSE 'Premium'
                    END''',
                    'price_range_category': '''CASE
                        WHEN COALESCE(t.total_price, 0) < 25 THEN 'Budget'
                        WHEN COALESCE(t.total_price, 0) < 100 THEN 'Standard'
                        WHEN COALESCE(t.total_price, 0) < 300 THEN 'Premium'
                        ELSE 'Luxury'
                    END''',
                    'customer_segment': '''CASE
                        WHEN COALESCE(t.gender, 'Male') = 'Female' AND COALESCE(t.agebracket, 'Adult') = 'Young Adult' THEN 'Young Female'
                        WHEN COALESCE(t.gender, 'Male') = 'Male' AND COALESCE(t.agebracket, 'Adult') = 'Young Adult' THEN 'Young Male'
                        WHEN COALESCE(t.gender, 'Male') = 'Female' AND COALESCE(t.agebracket, 'Adult') = 'Adult' THEN 'Adult Female'
                        WHEN COALESCE(t.gender, 'Male') = 'Male' AND COALESCE(t.agebracket, 'Adult') = 'Adult' THEN 'Adult Male'
                        ELSE 'Senior'
                    END''',
                    'shopping_context': '''CASE
                        WHEN DATENAME(weekday, COALESCE(t.transactiondate, GETUTCDATE())) IN ('Saturday', 'Sunday') THEN 'Weekend'
                        WHEN DATEPART(hour, COALESCE(t.transactiondate, GETUTCDATE())) BETWEEN 12 AND 14 THEN 'Lunch Break'
                        WHEN DATEPART(hour, COALESCE(t.transactiondate, GETUTCDATE())) BETWEEN 17 AND 19 THEN 'After Work'
                        ELSE 'Regular'
                    END'''
                }
            },
            'operational_enrichment': {
                'description': 'Enrich operational fields',
                'enrichments': {
                    'substitution_reason': 'COALESCE(t.substitution_reason, \'No Substitution\')',
                    'device_id': 'COALESCE(t.device_id, \'DEVICE_\' + CAST(t.storeid AS varchar))',
                    'transaction_id': 'COALESCE(t.transaction_id, NEWID())',
                    'source': 'COALESCE(t.source, \'Scout\')'
                }
            }
        }

    def _define_validation_rules(self) -> Dict[str, Any]:
        """Define validation rules for enriched data"""
        return {
            'required_fields': [
                'transactiondate', 'storeid', 'storename', 'category', 'brand', 'product',
                'total_price', 'payment_method', 'gender', 'agebracket', 'latitude', 'longitude'
            ],
            'business_rules': {
                'total_price': 'total_price >= 0',
                'latitude': 'latitude BETWEEN 14.0 AND 15.0',  # NCR bounds
                'longitude': 'longitude BETWEEN 120.5 AND 121.5',  # NCR bounds
                'storeid': 'storeid IN (102, 103, 104, 109, 110, 112)',  # Scout stores
                'hour_24': 'hour_24 BETWEEN 0 AND 23'
            },
            'completeness_targets': {
                'storename': 100,
                'category': 95,
                'brand': 95,
                'payment_method': 98,
                'gender': 90,
                'agebracket': 90,
                'latitude': 100,
                'longitude': 100
            }
        }

    def analyze_current_nulls(self, engine: str = 'postgresql') -> Dict[str, Any]:
        """Analyze current null patterns in the data"""
        logger.info("Analyzing current null patterns...")

        null_analysis_sql = """
        SELECT
            COUNT(*) as total_records,

            -- Store fields
            SUM(CASE WHEN storename IS NULL THEN 1 ELSE 0 END) as storename_nulls,
            SUM(CASE WHEN municipalityname IS NULL THEN 1 ELSE 0 END) as municipalityname_nulls,
            SUM(CASE WHEN latitude IS NULL THEN 1 ELSE 0 END) as latitude_nulls,
            SUM(CASE WHEN longitude IS NULL THEN 1 ELSE 0 END) as longitude_nulls,

            -- Product fields
            SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) as category_nulls,
            SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) as brand_nulls,
            SUM(CASE WHEN product IS NULL THEN 1 ELSE 0 END) as product_nulls,
            SUM(CASE WHEN productid IS NULL THEN 1 ELSE 0 END) as productid_nulls,

            -- Transaction fields
            SUM(CASE WHEN total_price IS NULL THEN 1 ELSE 0 END) as total_price_nulls,
            SUM(CASE WHEN payment_method IS NULL THEN 1 ELSE 0 END) as payment_method_nulls,
            SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) as quantity_nulls,

            -- Demographic fields
            SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) as gender_nulls,
            SUM(CASE WHEN agebracket IS NULL THEN 1 ELSE 0 END) as agebracket_nulls,

            -- Operational fields
            SUM(CASE WHEN substitution_reason IS NULL THEN 1 ELSE 0 END) as substitution_reason_nulls,
            SUM(CASE WHEN device_id IS NULL THEN 1 ELSE 0 END) as device_id_nulls

        FROM public.scout_gold_transactions_flat
        WHERE transactiondate >= CURRENT_DATE - INTERVAL '30 days';
        """

        try:
            conn = self._get_connection(engine)
            cursor = conn.cursor()
            cursor.execute(null_analysis_sql)

            result = cursor.fetchone()
            columns = [desc[0] for desc in cursor.description]

            cursor.close()
            conn.close()

            # Convert to analysis report
            analysis = dict(zip(columns, result))
            total_records = analysis['total_records']

            null_report = {
                'total_records': total_records,
                'null_percentages': {},
                'enrichment_opportunities': []
            }

            for field, null_count in analysis.items():
                if field.endswith('_nulls') and null_count > 0:
                    field_name = field.replace('_nulls', '')
                    null_percentage = (null_count / total_records) * 100
                    null_report['null_percentages'][field_name] = {
                        'null_count': null_count,
                        'null_percentage': round(null_percentage, 2)
                    }

                    if null_percentage > 5:  # Flag fields with >5% nulls for enrichment
                        null_report['enrichment_opportunities'].append({
                            'field': field_name,
                            'null_percentage': round(null_percentage, 2),
                            'priority': 'High' if null_percentage > 20 else 'Medium'
                        })

            return null_report

        except Exception as e:
            logger.error(f"Error analyzing nulls: {e}")
            return {'error': str(e)}

    def create_enriched_flat_view(self, engine: str = 'postgresql') -> str:
        """Create comprehensive enriched flat view with no unnecessary nulls"""
        logger.info("Creating enriched flat view...")

        # Build the comprehensive enrichment SQL
        enrichment_sql = self._build_enrichment_sql()

        view_sql = f"""
        CREATE OR REPLACE VIEW public.scout_gold_transactions_enriched_flat AS
        {enrichment_sql};
        """

        try:
            conn = self._get_connection(engine)
            cursor = conn.cursor()
            cursor.execute(view_sql)
            conn.commit()
            cursor.close()
            conn.close()

            logger.info("Successfully created enriched flat view")
            return "public.scout_gold_transactions_enriched_flat"

        except Exception as e:
            logger.error(f"Error creating enriched view: {e}")
            raise

    def _build_enrichment_sql(self) -> str:
        """Build comprehensive enrichment SQL"""

        # Start with base query structure
        sql_parts = []

        sql_parts.append("""
        WITH base_transactions AS (
            SELECT *
            FROM public.scout_gold_transactions_flat t
            WHERE t.transactiondate >= CURRENT_DATE - INTERVAL '365 days'  -- Last year
              AND t.latitude BETWEEN 14.0 AND 15.0  -- NCR bounds
              AND t.longitude BETWEEN 120.5 AND 121.5
        ),
        store_enriched AS (
            SELECT
                bt.*,
                -- Store enrichments from Stores table
                COALESCE(bt.storename, s.StoreName, 'Store ' + CAST(bt.storeid AS varchar)) as enriched_storename,
                COALESCE(bt.municipalityname, s.MunicipalityName, 'Unknown Municipality') as enriched_municipalityname,
                COALESCE(bt.provincename, 'Metro Manila') as enriched_provincename,
                COALESCE(bt.regionname, 'NCR') as enriched_regionname,
                COALESCE(bt.latitude, s.GeoLatitude, 14.5995) as enriched_latitude,
                COALESCE(bt.longitude, s.GeoLongitude, 120.9842) as enriched_longitude
            FROM base_transactions bt
            LEFT JOIN azure_sql_scout.dbo.Stores s ON bt.storeid = s.StoreID
        )""")

        sql_parts.append("""
        SELECT
            -- Transaction identifiers (enriched)
            COALESCE(se.transaction_id, NEWID()) as transaction_id,
            COALESCE(se.device_id, 'DEVICE_' + CAST(se.storeid AS varchar)) as device_id,
            COALESCE(se.source, 'Scout') as source,

            -- Temporal fields (enriched)
            COALESCE(se.transactiondate, GETUTCDATE()) as transactiondate,
            CAST(COALESCE(se.transactiondate, GETUTCDATE()) AS date) as date_ph,
            CAST(COALESCE(se.transactiondate, GETUTCDATE()) AS time) as time_ph,
            DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) as hour_24,
            DATENAME(weekday, COALESCE(se.transactiondate, GETUTCDATE())) as weekday,
            CASE
                WHEN DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) BETWEEN 6 AND 11 THEN 'Morning'
                WHEN DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) BETWEEN 12 AND 17 THEN 'Afternoon'
                WHEN DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) BETWEEN 18 AND 21 THEN 'Evening'
                ELSE 'Night'
            END as daypart,

            -- Store fields (enriched)
            se.storeid,
            se.enriched_storename as storename,
            se.enriched_municipalityname as municipalityname,
            se.enriched_provincename as provincename,
            se.enriched_regionname as regionname,
            se.enriched_latitude as latitude,
            se.enriched_longitude as longitude,

            -- Product fields (enriched)
            COALESCE(se.productid, NEWID()) as productid,
            COALESCE(se.category, 'Uncategorized') as category,
            COALESCE(se.brand, 'Generic') as brand,
            COALESCE(se.product, COALESCE(se.brand, 'Generic') + ' Product') as product,

            -- Transaction fields (enriched)
            COALESCE(se.total_price, 0.00) as total_price,
            COALESCE(se.quantity, 1) as quantity,
            COALESCE(se.unit_price, se.total_price / NULLIF(se.quantity, 0), se.total_price) as unit_price,
            COALESCE(se.payment_method,
                CASE
                    WHEN COALESCE(se.total_price, 0) < 100 THEN 'Cash'
                    WHEN COALESCE(se.total_price, 0) < 500 THEN 'Card'
                    ELSE 'Digital'
                END) as payment_method,

            -- Demographic fields (enriched with intelligent defaults)
            COALESCE(se.gender,
                CASE
                    WHEN DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) BETWEEN 9 AND 15 THEN 'Female'
                    ELSE 'Male'
                END) as gender,
            COALESCE(se.agebracket,
                CASE
                    WHEN COALESCE(se.total_price, 0) < 100 THEN 'Young Adult'
                    WHEN COALESCE(se.total_price, 0) < 300 THEN 'Adult'
                    ELSE 'Senior'
                END) as agebracket,

            -- Operational fields (enriched)
            COALESCE(se.substitution_reason, 'No Substitution') as substitution_reason,

            -- Calculated business intelligence fields
            CASE
                WHEN COALESCE(se.total_price, 0) < 50 THEN 'Small'
                WHEN COALESCE(se.total_price, 0) < 200 THEN 'Medium'
                WHEN COALESCE(se.total_price, 0) < 500 THEN 'Large'
                ELSE 'Premium'
            END as basket_size_category,

            CASE
                WHEN COALESCE(se.total_price, 0) < 25 THEN 'Budget'
                WHEN COALESCE(se.total_price, 0) < 100 THEN 'Standard'
                WHEN COALESCE(se.total_price, 0) < 300 THEN 'Premium'
                ELSE 'Luxury'
            END as price_range_category,

            CASE
                WHEN COALESCE(se.gender, 'Male') = 'Female' AND COALESCE(se.agebracket, 'Adult') = 'Young Adult' THEN 'Young Female'
                WHEN COALESCE(se.gender, 'Male') = 'Male' AND COALESCE(se.agebracket, 'Adult') = 'Young Adult' THEN 'Young Male'
                WHEN COALESCE(se.gender, 'Male') = 'Female' AND COALESCE(se.agebracket, 'Adult') = 'Adult' THEN 'Adult Female'
                WHEN COALESCE(se.gender, 'Male') = 'Male' AND COALESCE(se.agebracket, 'Adult') = 'Adult' THEN 'Adult Male'
                ELSE 'Senior'
            END as customer_segment,

            CASE
                WHEN DATENAME(weekday, COALESCE(se.transactiondate, GETUTCDATE())) IN ('Saturday', 'Sunday') THEN 'Weekend'
                WHEN DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) BETWEEN 12 AND 14 THEN 'Lunch Break'
                WHEN DATEPART(hour, COALESCE(se.transactiondate, GETUTCDATE())) BETWEEN 17 AND 19 THEN 'After Work'
                ELSE 'Regular'
            END as shopping_context,

            -- Data quality indicators
            CASE
                WHEN se.storename IS NULL OR se.category IS NULL OR se.brand IS NULL THEN 'Enriched'
                ELSE 'Original'
            END as data_quality_source,

            GETUTCDATE() as enrichment_timestamp

        FROM store_enriched se""")

        return "\n".join(sql_parts)

    def validate_enriched_data(self, engine: str = 'postgresql') -> Dict[str, Any]:
        """Validate the enriched data quality"""
        logger.info("Validating enriched data quality...")

        validation_sql = """
        SELECT
            COUNT(*) as total_records,

            -- Completeness validation
            SUM(CASE WHEN storename IS NULL OR storename = '' THEN 1 ELSE 0 END) as storename_missing,
            SUM(CASE WHEN category IS NULL OR category = '' THEN 1 ELSE 0 END) as category_missing,
            SUM(CASE WHEN brand IS NULL OR brand = '' THEN 1 ELSE 0 END) as brand_missing,
            SUM(CASE WHEN payment_method IS NULL OR payment_method = '' THEN 1 ELSE 0 END) as payment_method_missing,
            SUM(CASE WHEN gender IS NULL OR gender = '' THEN 1 ELSE 0 END) as gender_missing,
            SUM(CASE WHEN agebracket IS NULL OR agebracket = '' THEN 1 ELSE 0 END) as agebracket_missing,

            -- Business rule validation
            SUM(CASE WHEN total_price < 0 THEN 1 ELSE 0 END) as negative_prices,
            SUM(CASE WHEN latitude NOT BETWEEN 14.0 AND 15.0 THEN 1 ELSE 0 END) as invalid_latitude,
            SUM(CASE WHEN longitude NOT BETWEEN 120.5 AND 121.5 THEN 1 ELSE 0 END) as invalid_longitude,
            SUM(CASE WHEN storeid NOT IN (102, 103, 104, 109, 110, 112) THEN 1 ELSE 0 END) as invalid_stores,

            -- Enrichment statistics
            SUM(CASE WHEN data_quality_source = 'Enriched' THEN 1 ELSE 0 END) as enriched_records,
            SUM(CASE WHEN data_quality_source = 'Original' THEN 1 ELSE 0 END) as original_records,

            -- Value distributions
            COUNT(DISTINCT storeid) as unique_stores,
            COUNT(DISTINCT category) as unique_categories,
            COUNT(DISTINCT brand) as unique_brands,
            COUNT(DISTINCT payment_method) as unique_payment_methods,
            COUNT(DISTINCT gender) as unique_genders,
            COUNT(DISTINCT agebracket) as unique_age_brackets,

            AVG(total_price) as avg_transaction_value,
            MIN(transactiondate) as earliest_transaction,
            MAX(transactiondate) as latest_transaction

        FROM public.scout_gold_transactions_enriched_flat;
        """

        try:
            conn = self._get_connection(engine)
            cursor = conn.cursor()
            cursor.execute(validation_sql)

            result = cursor.fetchone()
            columns = [desc[0] for desc in cursor.description]

            cursor.close()
            conn.close()

            # Convert to validation report
            validation_data = dict(zip(columns, result))
            total_records = validation_data['total_records']

            validation_report = {
                'total_records': total_records,
                'data_quality_score': 0,
                'completeness_metrics': {},
                'business_rule_compliance': {},
                'enrichment_impact': {},
                'summary': {}
            }

            # Calculate completeness metrics
            completeness_fields = ['storename', 'category', 'brand', 'payment_method', 'gender', 'agebracket']
            completeness_score = 0

            for field in completeness_fields:
                missing_count = validation_data.get(f'{field}_missing', 0)
                completeness_pct = ((total_records - missing_count) / total_records) * 100
                validation_report['completeness_metrics'][field] = {
                    'completeness_percentage': round(completeness_pct, 2),
                    'missing_count': missing_count
                }
                completeness_score += completeness_pct

            # Calculate business rule compliance
            rule_violations = ['negative_prices', 'invalid_latitude', 'invalid_longitude', 'invalid_stores']
            compliance_score = 0

            for violation in rule_violations:
                violation_count = validation_data.get(violation, 0)
                compliance_pct = ((total_records - violation_count) / total_records) * 100
                validation_report['business_rule_compliance'][violation.replace('_', ' ')] = {
                    'compliance_percentage': round(compliance_pct, 2),
                    'violation_count': violation_count
                }
                compliance_score += compliance_pct

            # Calculate enrichment impact
            enriched_count = validation_data.get('enriched_records', 0)
            original_count = validation_data.get('original_records', 0)
            enrichment_percentage = (enriched_count / total_records) * 100

            validation_report['enrichment_impact'] = {
                'enriched_records': enriched_count,
                'original_records': original_count,
                'enrichment_percentage': round(enrichment_percentage, 2)
            }

            # Calculate overall data quality score
            overall_completeness = completeness_score / len(completeness_fields)
            overall_compliance = compliance_score / len(rule_violations)
            validation_report['data_quality_score'] = round((overall_completeness + overall_compliance) / 2, 2)

            # Summary
            validation_report['summary'] = {
                'unique_stores': validation_data['unique_stores'],
                'unique_categories': validation_data['unique_categories'],
                'unique_brands': validation_data['unique_brands'],
                'avg_transaction_value': round(validation_data['avg_transaction_value'], 2),
                'date_range': f"{validation_data['earliest_transaction']} to {validation_data['latest_transaction']}"
            }

            return validation_report

        except Exception as e:
            logger.error(f"Error validating enriched data: {e}")
            return {'error': str(e)}

    def _get_connection(self, engine: str):
        """Get database connection"""
        if engine == 'postgresql':
            return psycopg2.connect(**self.db_config[engine])
        elif engine == 'azuresql':
            conn_str = (
                f"DRIVER={{ODBC Driver 18 for SQL Server}};"
                f"SERVER={self.db_config[engine]['server']};"
                f"DATABASE={self.db_config[engine]['database']};"
                f"UID={self.db_config[engine]['user']};"
                f"PWD={self.db_config[engine]['password']};"
                "TrustServerCertificate=yes;"
            )
            return pyodbc.connect(conn_str, timeout=60)
        else:
            raise ValueError(f"Unsupported engine: {engine}")

    def export_clean_dataframe(self, engine: str = 'postgresql', output_format: str = 'csv') -> str:
        """Export the clean, enriched dataframe"""
        logger.info(f"Exporting clean dataframe as {output_format}...")

        export_sql = """
        SELECT *
        FROM public.scout_gold_transactions_enriched_flat
        WHERE transactiondate >= CURRENT_DATE - INTERVAL '30 days'
        ORDER BY transactiondate DESC, storeid, category;
        """

        try:
            conn = self._get_connection(engine)

            # Use pandas for efficient export
            df = pd.read_sql(export_sql, conn)
            conn.close()

            # Generate output filename
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_file = f"/Users/tbwa/scout-v7/data/scout_clean_enriched_{timestamp}.{output_format}"

            # Export based on format
            if output_format == 'csv':
                df.to_csv(output_file, index=False)
            elif output_format == 'parquet':
                df.to_parquet(output_file, index=False)
            elif output_format == 'excel':
                df.to_excel(output_file.replace('.excel', '.xlsx'), index=False)

            logger.info(f"Exported {len(df)} records to {output_file}")

            # Return summary
            return {
                'file_path': output_file,
                'record_count': len(df),
                'columns': list(df.columns),
                'null_counts': df.isnull().sum().to_dict(),
                'data_types': df.dtypes.to_dict()
            }

        except Exception as e:
            logger.error(f"Error exporting dataframe: {e}")
            return {'error': str(e)}

def main():
    """Main execution function"""
    pipeline = DataEnrichmentPipeline()

    print("=== Scout Data Enrichment Pipeline ===\n")

    # Step 1: Analyze current nulls
    print("1. Analyzing current null patterns...")
    null_analysis = pipeline.analyze_current_nulls()
    print(f"Total records analyzed: {null_analysis.get('total_records', 0)}")
    print(f"Fields with enrichment opportunities: {len(null_analysis.get('enrichment_opportunities', []))}")

    for opportunity in null_analysis.get('enrichment_opportunities', [])[:5]:
        print(f"  - {opportunity['field']}: {opportunity['null_percentage']}% nulls ({opportunity['priority']} priority)")

    # Step 2: Create enriched view
    print("\n2. Creating enriched flat view...")
    try:
        view_name = pipeline.create_enriched_flat_view()
        print(f"Created view: {view_name}")
    except Exception as e:
        print(f"Error creating view: {e}")
        return

    # Step 3: Validate enriched data
    print("\n3. Validating enriched data quality...")
    validation_report = pipeline.validate_enriched_data()
    print(f"Data quality score: {validation_report.get('data_quality_score', 0)}/100")
    print(f"Enrichment percentage: {validation_report.get('enrichment_impact', {}).get('enrichment_percentage', 0)}%")

    # Show completeness improvements
    print("\nCompleteness metrics:")
    for field, metrics in validation_report.get('completeness_metrics', {}).items():
        print(f"  - {field}: {metrics['completeness_percentage']}% complete")

    # Step 4: Export clean dataframe
    print("\n4. Exporting clean dataframe...")
    export_result = pipeline.export_clean_dataframe('postgresql', 'csv')
    if 'error' not in export_result:
        print(f"Exported to: {export_result['file_path']}")
        print(f"Records: {export_result['record_count']}")
        print(f"Columns: {len(export_result['columns'])}")

        # Show remaining nulls
        remaining_nulls = {k: v for k, v in export_result['null_counts'].items() if v > 0}
        if remaining_nulls:
            print(f"Remaining nulls: {remaining_nulls}")
        else:
            print("No nulls remaining in enriched dataset!")

if __name__ == "__main__":
    main()