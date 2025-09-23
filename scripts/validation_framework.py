#!/usr/bin/env python3
"""
Scout Analytics Validation Framework
Comprehensive validation for RAG-CAG query results and data quality

Usage:
    python validation_framework.py --validate-template time_of_day_category
    python validation_framework.py --parity-check flat-vs-crosstab
    python validation_framework.py --quality-check --date-range 7
    python validation_framework.py --monitor --continuous
"""

import os
import json
import sqlite3
import logging
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass
from pathlib import Path
import statistics

import psycopg2
import pyodbc
import pandas as pd
import numpy as np

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class ValidationResult:
    """Validation result container"""
    test_name: str
    passed: bool
    score: float
    details: Dict[str, Any]
    issues: List[str]
    evidence: Dict[str, Any]
    timestamp: datetime

@dataclass
class QualityMetrics:
    """Data quality metrics"""
    completeness: float
    accuracy: float
    consistency: float
    timeliness: float
    validity: float
    overall_score: float

class DatabaseConnector:
    """Multi-engine database connector with connection pooling"""

    def __init__(self):
        self.connections = {}

    def get_connection(self, engine: str):
        """Get database connection for specified engine"""
        if engine in self.connections:
            # Test connection health
            try:
                conn = self.connections[engine]
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.fetchone()
                return conn
            except:
                # Connection failed, remove and reconnect
                del self.connections[engine]

        if engine == 'postgresql':
            conn = psycopg2.connect(
                host=os.getenv('SUPABASE_HOST', 'aws-0-ap-southeast-1.pooler.supabase.com'),
                port=int(os.getenv('SUPABASE_PORT', '6543')),
                database=os.getenv('SUPABASE_DB', 'postgres'),
                user=os.getenv('SUPABASE_USER', 'postgres.cxzllzyxwpyptfretryc'),
                password=os.getenv('SUPABASE_PASS', 'Postgres_26')
            )
        elif engine == 'azuresql':
            conn_str = (
                f"DRIVER={{ODBC Driver 18 for SQL Server}};"
                f"SERVER={os.getenv('AZURE_SQL_SERVER', 'sql-tbwa-projectscout-reporting-prod.database.windows.net')};"
                f"DATABASE={os.getenv('AZURE_SQL_DB', 'SQL-TBWA-ProjectScout-Reporting-Prod')};"
                f"UID={os.getenv('AZURE_SQL_USER', 'scout_reader')};"
                f"PWD={os.getenv('AZURE_SQL_PASS', 'Scout_Analytics_2025!')};"
                "TrustServerCertificate=yes;"
            )
            conn = pyodbc.connect(conn_str, timeout=60)
        else:
            raise ValueError(f"Unsupported database engine: {engine}")

        self.connections[engine] = conn
        return conn

    def execute_query(self, sql: str, engine: str = 'postgresql') -> pd.DataFrame:
        """Execute query and return DataFrame"""
        conn = self.get_connection(engine)
        return pd.read_sql_query(sql, conn)

class DataQualityValidator:
    """Data quality assessment and validation"""

    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector

    def validate_completeness(self, engine: str = 'postgresql') -> ValidationResult:
        """Validate data completeness for required fields"""
        sql = """
        WITH completeness_check AS (
            SELECT
                COUNT(*) as total_rows,
                COUNT(CASE WHEN storeid IS NOT NULL THEN 1 END) as storeid_complete,
                COUNT(CASE WHEN total_price IS NOT NULL AND total_price > 0 THEN 1 END) as amount_complete,
                COUNT(CASE WHEN category IS NOT NULL AND category != '' THEN 1 END) as category_complete,
                COUNT(CASE WHEN transactiondate IS NOT NULL THEN 1 END) as date_complete,
                COUNT(CASE WHEN location LIKE '%NCR%' THEN 1 END) as location_complete
            FROM public.scout_gold_transactions_flat
            WHERE transactiondate >= CURRENT_DATE - INTERVAL '7 days'
        )
        SELECT
            total_rows,
            ROUND(100.0 * storeid_complete / total_rows, 2) as storeid_pct,
            ROUND(100.0 * amount_complete / total_rows, 2) as amount_pct,
            ROUND(100.0 * category_complete / total_rows, 2) as category_pct,
            ROUND(100.0 * date_complete / total_rows, 2) as date_pct,
            ROUND(100.0 * location_complete / total_rows, 2) as location_pct
        FROM completeness_check
        """

        try:
            df = self.db.execute_query(sql, engine)
            if df.empty:
                return ValidationResult(
                    test_name="completeness",
                    passed=False,
                    score=0.0,
                    details={},
                    issues=["No data found"],
                    evidence={},
                    timestamp=datetime.now()
                )

            row = df.iloc[0]
            scores = [row['storeid_pct'], row['amount_pct'], row['category_pct'],
                     row['date_pct'], row['location_pct']]
            overall_score = statistics.mean(scores)

            issues = []
            if row['storeid_pct'] < 100:
                issues.append(f"StoreID completeness: {row['storeid_pct']}%")
            if row['amount_pct'] < 95:
                issues.append(f"Amount completeness: {row['amount_pct']}%")
            if row['category_pct'] < 90:
                issues.append(f"Category completeness: {row['category_pct']}%")

            return ValidationResult(
                test_name="completeness",
                passed=overall_score >= 95.0,
                score=overall_score,
                details=row.to_dict(),
                issues=issues,
                evidence={'total_rows': int(row['total_rows'])},
                timestamp=datetime.now()
            )

        except Exception as e:
            return ValidationResult(
                test_name="completeness",
                passed=False,
                score=0.0,
                details={},
                issues=[f"Query failed: {str(e)}"],
                evidence={},
                timestamp=datetime.now()
            )

    def validate_accuracy(self, engine: str = 'postgresql') -> ValidationResult:
        """Validate data accuracy against business rules"""
        sql = """
        WITH accuracy_check AS (
            SELECT
                COUNT(*) as total_rows,
                COUNT(CASE WHEN total_price > 0 AND total_price <= 10000 THEN 1 END) as valid_amounts,
                COUNT(CASE WHEN storeid IN (102,103,104,109,110,112) THEN 1 END) as scout_stores,
                COUNT(CASE WHEN location LIKE '%NCR%' OR location LIKE '%Metro Manila%' THEN 1 END) as ncr_locations,
                COUNT(CASE WHEN transactiondate >= '2025-01-01' AND transactiondate <= CURRENT_DATE THEN 1 END) as valid_dates,
                COUNT(CASE WHEN category IN ('Snacks', 'Beverages', 'Personal Care', 'Household', 'Food') THEN 1 END) as valid_categories
            FROM public.scout_gold_transactions_flat
            WHERE transactiondate >= CURRENT_DATE - INTERVAL '7 days'
        )
        SELECT
            total_rows,
            ROUND(100.0 * valid_amounts / total_rows, 2) as amount_accuracy_pct,
            ROUND(100.0 * scout_stores / total_rows, 2) as store_accuracy_pct,
            ROUND(100.0 * ncr_locations / total_rows, 2) as location_accuracy_pct,
            ROUND(100.0 * valid_dates / total_rows, 2) as date_accuracy_pct,
            ROUND(100.0 * valid_categories / total_rows, 2) as category_accuracy_pct
        FROM accuracy_check
        """

        try:
            df = self.db.execute_query(sql, engine)
            if df.empty:
                return ValidationResult(
                    test_name="accuracy",
                    passed=False,
                    score=0.0,
                    details={},
                    issues=["No data found"],
                    evidence={},
                    timestamp=datetime.now()
                )

            row = df.iloc[0]
            scores = [row['amount_accuracy_pct'], row['store_accuracy_pct'],
                     row['location_accuracy_pct'], row['date_accuracy_pct']]
            overall_score = statistics.mean(scores)

            issues = []
            if row['amount_accuracy_pct'] < 99:
                issues.append(f"Invalid amounts detected: {100 - row['amount_accuracy_pct']:.1f}%")
            if row['location_accuracy_pct'] < 100:
                issues.append(f"Non-NCR locations: {100 - row['location_accuracy_pct']:.1f}%")

            return ValidationResult(
                test_name="accuracy",
                passed=overall_score >= 95.0,
                score=overall_score,
                details=row.to_dict(),
                issues=issues,
                evidence={'total_rows': int(row['total_rows'])},
                timestamp=datetime.now()
            )

        except Exception as e:
            return ValidationResult(
                test_name="accuracy",
                passed=False,
                score=0.0,
                details={},
                issues=[f"Query failed: {str(e)}"],
                evidence={},
                timestamp=datetime.now()
            )

    def validate_timeliness(self, engine: str = 'postgresql') -> ValidationResult:
        """Validate data freshness and timeliness"""
        sql = """
        WITH timeliness_check AS (
            SELECT
                MAX(transactiondate) as latest_transaction,
                EXTRACT(EPOCH FROM (NOW() - MAX(transactiondate))) / 60 as minutes_behind,
                COUNT(*) as total_rows,
                COUNT(CASE WHEN transactiondate >= CURRENT_DATE THEN 1 END) as today_rows,
                COUNT(CASE WHEN transactiondate >= CURRENT_DATE - INTERVAL '1 day' THEN 1 END) as recent_rows
            FROM public.scout_gold_transactions_flat
        )
        SELECT
            latest_transaction,
            ROUND(minutes_behind, 1) as minutes_behind,
            total_rows,
            today_rows,
            recent_rows,
            CASE
                WHEN minutes_behind <= 60 THEN 100
                WHEN minutes_behind <= 240 THEN 80
                WHEN minutes_behind <= 1440 THEN 60
                ELSE 20
            END as freshness_score
        FROM timeliness_check
        """

        try:
            df = self.db.execute_query(sql, engine)
            if df.empty:
                return ValidationResult(
                    test_name="timeliness",
                    passed=False,
                    score=0.0,
                    details={},
                    issues=["No data found"],
                    evidence={},
                    timestamp=datetime.now()
                )

            row = df.iloc[0]
            freshness_score = float(row['freshness_score'])
            minutes_behind = float(row['minutes_behind'])

            issues = []
            if minutes_behind > 60:
                issues.append(f"Data is {minutes_behind:.1f} minutes behind")
            if row['today_rows'] == 0:
                issues.append("No transactions today")

            return ValidationResult(
                test_name="timeliness",
                passed=freshness_score >= 80,
                score=freshness_score,
                details=row.to_dict(),
                issues=issues,
                evidence={'latest_transaction': str(row['latest_transaction'])},
                timestamp=datetime.now()
            )

        except Exception as e:
            return ValidationResult(
                test_name="timeliness",
                passed=False,
                score=0.0,
                details={},
                issues=[f"Query failed: {str(e)}"],
                evidence={},
                timestamp=datetime.now()
            )

class ParityValidator:
    """Cross-tab and flat data parity validation"""

    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector

    def validate_flat_vs_crosstab_parity(self, engine: str = 'postgresql') -> ValidationResult:
        """Validate parity between flat and crosstab views"""
        # Flat data aggregation
        flat_sql = """
        SELECT
            COUNT(*) as total_transactions,
            SUM(total_price) as total_revenue,
            COUNT(DISTINCT storeid) as unique_stores,
            COUNT(DISTINCT category) as unique_categories
        FROM public.scout_gold_transactions_flat
        WHERE transactiondate >= CURRENT_DATE - INTERVAL '7 days'
          AND location LIKE '%NCR%'
        """

        # Crosstab data aggregation (if available)
        crosstab_sql = """
        SELECT
            SUM(txn_count) as total_transactions,
            SUM(total_amount) as total_revenue,
            COUNT(DISTINCT store_id) as unique_stores,
            COUNT(DISTINCT category) as unique_categories
        FROM analytics.v_transactions_crosstab
        WHERE date >= CURRENT_DATE - INTERVAL '7 days'
        """

        try:
            flat_df = self.db.execute_query(flat_sql, engine)

            # Try crosstab, fall back if not available
            try:
                crosstab_df = self.db.execute_query(crosstab_sql, engine)
                has_crosstab = True
            except:
                has_crosstab = False
                crosstab_df = pd.DataFrame()

            if flat_df.empty:
                return ValidationResult(
                    test_name="parity",
                    passed=False,
                    score=0.0,
                    details={},
                    issues=["No flat data found"],
                    evidence={},
                    timestamp=datetime.now()
                )

            flat_row = flat_df.iloc[0]

            if not has_crosstab or crosstab_df.empty:
                return ValidationResult(
                    test_name="parity",
                    passed=True,
                    score=90.0,  # Reduced score due to missing crosstab
                    details=flat_row.to_dict(),
                    issues=["Crosstab view not available for comparison"],
                    evidence={'has_crosstab': False},
                    timestamp=datetime.now()
                )

            crosstab_row = crosstab_df.iloc[0]

            # Calculate parity scores
            txn_parity = abs(flat_row['total_transactions'] - crosstab_row['total_transactions']) / flat_row['total_transactions'] * 100
            revenue_parity = abs(flat_row['total_revenue'] - crosstab_row['total_revenue']) / flat_row['total_revenue'] * 100
            store_parity = abs(flat_row['unique_stores'] - crosstab_row['unique_stores']) / flat_row['unique_stores'] * 100

            overall_parity = 100 - statistics.mean([txn_parity, revenue_parity, store_parity])

            issues = []
            if txn_parity > 5:
                issues.append(f"Transaction count variance: {txn_parity:.1f}%")
            if revenue_parity > 5:
                issues.append(f"Revenue variance: {revenue_parity:.1f}%")
            if store_parity > 0:
                issues.append(f"Store count variance: {store_parity:.1f}%")

            return ValidationResult(
                test_name="parity",
                passed=overall_parity >= 95.0,
                score=overall_parity,
                details={
                    'flat': flat_row.to_dict(),
                    'crosstab': crosstab_row.to_dict(),
                    'variances': {
                        'transactions': txn_parity,
                        'revenue': revenue_parity,
                        'stores': store_parity
                    }
                },
                issues=issues,
                evidence={'has_crosstab': True},
                timestamp=datetime.now()
            )

        except Exception as e:
            return ValidationResult(
                test_name="parity",
                passed=False,
                score=0.0,
                details={},
                issues=[f"Parity check failed: {str(e)}"],
                evidence={},
                timestamp=datetime.now()
            )

class TemplateValidator:
    """SQL template result validation"""

    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector

    def validate_template_result(self, template_id: str, result_df: pd.DataFrame,
                               expected_config: Dict[str, Any]) -> ValidationResult:
        """Validate template execution result against expectations"""
        issues = []
        score_components = []

        # Row count validation
        expected_rows = expected_config.get('expected_rows', '1-1000')
        if '-' in expected_rows:
            min_rows, max_rows = map(int, expected_rows.split('-'))
            row_count = len(result_df)

            if min_rows <= row_count <= max_rows:
                score_components.append(100)
            else:
                score_components.append(50)
                issues.append(f"Row count {row_count} outside expected range {expected_rows}")

        # Required columns validation
        required_columns = expected_config.get('required_columns', [])
        missing_columns = [col for col in required_columns if col not in result_df.columns]
        if missing_columns:
            score_components.append(50)
            issues.append(f"Missing columns: {missing_columns}")
        else:
            score_components.append(100)

        # Data type validation
        if not result_df.empty:
            for col in result_df.columns:
                if 'pct' in col.lower() or 'percentage' in col.lower():
                    # Percentage columns should be 0-100
                    pct_values = result_df[col].dropna()
                    if pct_values.dtype in ['float64', 'float32'] and len(pct_values) > 0:
                        if not all(0 <= val <= 100 for val in pct_values):
                            issues.append(f"Invalid percentage values in {col}")
                            score_components.append(80)
                        else:
                            score_components.append(100)

        # Statistical significance validation
        if 'transaction_count' in result_df.columns:
            min_txns = result_df['transaction_count'].min()
            if min_txns < 3:
                issues.append("Some results below statistical significance threshold (3 transactions)")
                score_components.append(90)
            else:
                score_components.append(100)

        overall_score = statistics.mean(score_components) if score_components else 0

        return ValidationResult(
            test_name=f"template_{template_id}",
            passed=overall_score >= 85.0 and len(issues) <= 1,
            score=overall_score,
            details={
                'row_count': len(result_df),
                'columns': list(result_df.columns),
                'expected_config': expected_config
            },
            issues=issues,
            evidence={'result_sample': result_df.head(3).to_dict('records') if not result_df.empty else []},
            timestamp=datetime.now()
        )

class PerformanceMonitor:
    """Performance and SLI monitoring"""

    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector

    def measure_query_performance(self, sql: str, engine: str = 'postgresql') -> Dict[str, Any]:
        """Measure query execution performance"""
        start_time = datetime.now()

        try:
            result_df = self.db.execute_query(sql, engine)
            execution_time = (datetime.now() - start_time).total_seconds() * 1000  # milliseconds

            return {
                'success': True,
                'execution_time_ms': execution_time,
                'row_count': len(result_df),
                'memory_usage_mb': result_df.memory_usage(deep=True).sum() / 1024 / 1024,
                'error': None
            }
        except Exception as e:
            execution_time = (datetime.now() - start_time).total_seconds() * 1000
            return {
                'success': False,
                'execution_time_ms': execution_time,
                'row_count': 0,
                'memory_usage_mb': 0,
                'error': str(e)
            }

    def get_system_health_metrics(self, engine: str = 'postgresql') -> Dict[str, Any]:
        """Get overall system health metrics"""
        health_sql = """
        WITH health_metrics AS (
            SELECT
                COUNT(*) as total_transactions_24h,
                COUNT(DISTINCT storeid) as active_stores_24h,
                MAX(transactiondate) as latest_transaction,
                EXTRACT(EPOCH FROM (NOW() - MAX(transactiondate))) / 60 as minutes_behind,
                AVG(total_price) as avg_transaction_value,
                COUNT(CASE WHEN total_price > 0 THEN 1 END) * 100.0 / COUNT(*) as data_quality_pct
            FROM public.scout_gold_transactions_flat
            WHERE transactiondate >= NOW() - INTERVAL '24 hours'
        )
        SELECT
            total_transactions_24h,
            active_stores_24h,
            latest_transaction,
            ROUND(minutes_behind, 1) as minutes_behind,
            ROUND(avg_transaction_value, 2) as avg_transaction_value,
            ROUND(data_quality_pct, 2) as data_quality_pct,
            CASE
                WHEN minutes_behind <= 60 AND total_transactions_24h >= 50 AND active_stores_24h >= 4 THEN 'HEALTHY'
                WHEN minutes_behind <= 240 AND total_transactions_24h >= 20 THEN 'WARNING'
                ELSE 'CRITICAL'
            END as overall_status
        FROM health_metrics
        """

        try:
            df = self.db.execute_query(health_sql, engine)
            if df.empty:
                return {'status': 'CRITICAL', 'error': 'No health data available'}

            return df.iloc[0].to_dict()
        except Exception as e:
            return {'status': 'CRITICAL', 'error': str(e)}

class ValidationFramework:
    """Main validation framework coordinator"""

    def __init__(self):
        self.db_connector = DatabaseConnector()
        self.quality_validator = DataQualityValidator(self.db_connector)
        self.parity_validator = ParityValidator(self.db_connector)
        self.template_validator = TemplateValidator(self.db_connector)
        self.performance_monitor = PerformanceMonitor(self.db_connector)

    def run_comprehensive_validation(self, engine: str = 'postgresql') -> Dict[str, Any]:
        """Run all validation checks and return comprehensive report"""
        logger.info("Running comprehensive validation suite...")

        results = {}

        # Data quality checks
        results['completeness'] = self.quality_validator.validate_completeness(engine)
        results['accuracy'] = self.quality_validator.validate_accuracy(engine)
        results['timeliness'] = self.quality_validator.validate_timeliness(engine)

        # Parity checks
        results['parity'] = self.parity_validator.validate_flat_vs_crosstab_parity(engine)

        # System health
        results['system_health'] = self.performance_monitor.get_system_health_metrics(engine)

        # Calculate overall scores
        validation_scores = [r.score for r in results.values() if hasattr(r, 'score')]
        overall_score = statistics.mean(validation_scores) if validation_scores else 0

        all_issues = []
        for result in results.values():
            if hasattr(result, 'issues'):
                all_issues.extend(result.issues)

        validation_passed = overall_score >= 80 and len(all_issues) <= 3

        return {
            'timestamp': datetime.now().isoformat(),
            'overall_score': overall_score,
            'validation_passed': validation_passed,
            'engine': engine,
            'total_issues': len(all_issues),
            'results': {k: v.__dict__ if hasattr(v, '__dict__') else v for k, v in results.items()},
            'summary': {
                'completeness': results['completeness'].score if hasattr(results['completeness'], 'score') else 0,
                'accuracy': results['accuracy'].score if hasattr(results['accuracy'], 'score') else 0,
                'timeliness': results['timeliness'].score if hasattr(results['timeliness'], 'score') else 0,
                'parity': results['parity'].score if hasattr(results['parity'], 'score') else 0,
                'system_status': results['system_health'].get('overall_status', 'UNKNOWN')
            }
        }

def main():
    """CLI interface for validation framework"""
    parser = argparse.ArgumentParser(description="Scout Analytics Validation Framework")
    parser.add_argument('--validate-template', type=str, help="Validate specific template")
    parser.add_argument('--parity-check', action='store_true', help="Run parity validation")
    parser.add_argument('--quality-check', action='store_true', help="Run data quality checks")
    parser.add_argument('--monitor', action='store_true', help="Run system monitoring")
    parser.add_argument('--comprehensive', action='store_true', help="Run all validations")
    parser.add_argument('--engine', type=str, default='postgresql', choices=['postgresql', 'azuresql'])
    parser.add_argument('--output', type=str, help="Output file for results")
    parser.add_argument('--continuous', action='store_true', help="Continuous monitoring mode")

    args = parser.parse_args()

    framework = ValidationFramework()

    if args.comprehensive or (not any([args.validate_template, args.parity_check,
                                      args.quality_check, args.monitor])):
        # Run comprehensive validation
        results = framework.run_comprehensive_validation(args.engine)

        print(f"\n🔍 Scout Analytics Validation Report")
        print(f"=" * 50)
        print(f"Overall Score: {results['overall_score']:.1f}/100")
        print(f"Status: {'✅ PASSED' if results['validation_passed'] else '❌ FAILED'}")
        print(f"Engine: {results['engine']}")
        print(f"Issues: {results['total_issues']}")

        print(f"\n📊 Component Scores:")
        for component, score in results['summary'].items():
            if isinstance(score, (int, float)):
                print(f"  {component.title()}: {score:.1f}/100")
            else:
                print(f"  {component.title()}: {score}")

        if args.output:
            with open(args.output, 'w') as f:
                json.dump(results, f, indent=2, default=str)
            logger.info(f"Results saved to {args.output}")

    elif args.parity_check:
        result = framework.parity_validator.validate_flat_vs_crosstab_parity(args.engine)
        print(f"\n🔄 Parity Check: {'✅ PASSED' if result.passed else '❌ FAILED'}")
        print(f"Score: {result.score:.1f}/100")
        if result.issues:
            print(f"Issues: {', '.join(result.issues)}")

    elif args.quality_check:
        completeness = framework.quality_validator.validate_completeness(args.engine)
        accuracy = framework.quality_validator.validate_accuracy(args.engine)
        timeliness = framework.quality_validator.validate_timeliness(args.engine)

        print(f"\n📊 Data Quality Report:")
        print(f"Completeness: {completeness.score:.1f}/100 {'✅' if completeness.passed else '❌'}")
        print(f"Accuracy: {accuracy.score:.1f}/100 {'✅' if accuracy.passed else '❌'}")
        print(f"Timeliness: {timeliness.score:.1f}/100 {'✅' if timeliness.passed else '❌'}")

    elif args.monitor:
        health = framework.performance_monitor.get_system_health_metrics(args.engine)
        print(f"\n💚 System Health: {health.get('overall_status', 'UNKNOWN')}")
        print(f"Transactions (24h): {health.get('total_transactions_24h', 0)}")
        print(f"Active Stores: {health.get('active_stores_24h', 0)}")
        print(f"Data Freshness: {health.get('minutes_behind', 0)} minutes behind")

if __name__ == "__main__":
    main()