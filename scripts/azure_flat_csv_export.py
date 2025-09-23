#!/usr/bin/env python3
"""
Azure SQL Flat CSV Export with DQ & Audit
Automated export of flat dataframe with comprehensive validation
"""

import os
import sys
import pyodbc
import pandas as pd
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import logging
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AzureFlatCSVExporter:
    """Azure SQL flat CSV export with independent DQ and audit"""

    def __init__(self):
        self.config = self._load_config()
        self.connection_string = self._build_connection_string()
        self.export_timestamp = datetime.now(timezone.utc)

    def _load_config(self) -> Dict[str, str]:
        """Load Azure SQL configuration from environment"""
        return {
            'server': os.getenv('AZSQL_HOST', 'your-server.database.windows.net'),
            'database': os.getenv('AZSQL_DB', 'your-database'),
            'username': os.getenv('AZSQL_USER', 'your-username'),
            'password': os.getenv('AZSQL_PASS', 'your-password'),
            'driver': '{ODBC Driver 17 for SQL Server}',
            'export_path': os.getenv('EXPORT_PATH', '/Users/tbwa/scout-v7/data/exports')
        }

    def _build_connection_string(self) -> str:
        """Build Azure SQL connection string"""
        return (
            f"DRIVER={self.config['driver']};"
            f"SERVER={self.config['server']};"
            f"DATABASE={self.config['database']};"
            f"UID={self.config['username']};"
            f"PWD={self.config['password']};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=no;"
            f"Connection Timeout=30;"
            f"CommandTimeout=300;"
        )

    def run_dq_checks(self, conn: pyodbc.Connection) -> Dict[str, Any]:
        """Run comprehensive data quality checks"""
        logger.info("Running pre-export data quality checks...")

        dq_results = {}

        # 1. Completeness check
        completeness_sql = "SELECT * FROM dq.v_flat_completeness"
        completeness_df = pd.read_sql(completeness_sql, conn)
        dq_results['completeness'] = completeness_df.to_dict('records')[0]

        # 2. Referential integrity check
        integrity_sql = "SELECT * FROM dq.v_flat_referential_integrity"
        integrity_df = pd.read_sql(integrity_sql, conn)
        dq_results['referential_integrity'] = integrity_df.to_dict('records')[0]

        # 3. Business rules check
        business_rules_sql = "SELECT * FROM dq.v_flat_business_rules"
        business_rules_df = pd.read_sql(business_rules_sql, conn)
        dq_results['business_rules'] = business_rules_df.to_dict('records')[0]

        # 4. Freshness check
        freshness_sql = "SELECT * FROM dq.v_flat_freshness"
        freshness_df = pd.read_sql(freshness_sql, conn)
        dq_results['freshness'] = freshness_df.to_dict('records')[0]

        # 5. Overall dashboard
        dashboard_sql = "SELECT * FROM dq.v_flat_export_dashboard"
        dashboard_df = pd.read_sql(dashboard_sql, conn)
        dq_results['dashboard'] = dashboard_df.to_dict('records')[0]

        logger.info(f"DQ Checks completed:")
        logger.info(f"  Total records: {dq_results['completeness']['total_records']:,}")
        logger.info(f"  Quality score: {dq_results['completeness']['avg_quality_score']:.1f}")
        logger.info(f"  Freshness: {dq_results['freshness']['freshness_status']}")
        logger.info(f"  Overall status: {dq_results['dashboard']['overall_quality_status']}")

        return dq_results

    def validate_export_readiness(self, dq_results: Dict[str, Any]) -> bool:
        """Validate if data is ready for export"""
        logger.info("Validating export readiness...")

        # Check overall quality status
        overall_status = dq_results['dashboard']['overall_quality_status']
        if overall_status in ['NEEDS_ATTENTION']:
            logger.error(f"Export blocked: Overall quality status is {overall_status}")
            return False

        # Check freshness
        freshness_status = dq_results['freshness']['freshness_status']
        if freshness_status == 'VERY_STALE':
            logger.error(f"Export blocked: Data freshness is {freshness_status}")
            return False

        # Check for critical integrity issues
        integrity = dq_results['referential_integrity']
        if integrity['negative_amounts'] > 0:
            logger.error(f"Export blocked: {integrity['negative_amounts']} records with negative amounts")
            return False

        # Check record count minimum
        total_records = dq_results['completeness']['total_records']
        if total_records < 100:
            logger.error(f"Export blocked: Only {total_records} records available (minimum: 100)")
            return False

        logger.info("✅ Export readiness validation passed")
        return True

    def export_flat_csv(self, conn: pyodbc.Connection, filename_prefix: str = "scout_flat_export") -> Dict[str, Any]:
        """Export flat dataframe to CSV with audit trail"""
        logger.info("Starting flat CSV export...")

        # Generate filename with timestamp
        timestamp_str = self.export_timestamp.strftime('%Y%m%d_%H%M%S')
        filename = f"{filename_prefix}_{timestamp_str}.csv"
        filepath = Path(self.config['export_path']) / filename

        # Ensure export directory exists
        filepath.parent.mkdir(parents=True, exist_ok=True)

        # Export query
        export_sql = """
        SELECT
            Transaction_ID,
            Transaction_Value,
            Basket_Size,
            Category,
            Brand,
            Daypart,
            Weekday_vs_Weekend,
            Time_of_transaction,
            [Demographics (Age/Gender/Role)],
            Emotions,
            Location,
            Other_products_bought,
            Was_there_substitution,
            StoreID,
            [Timestamp],
            FacialID,
            DeviceID,
            Data_Quality_Score,
            Data_Source
        FROM gold.v_flat_export_ready
        ORDER BY [Timestamp] DESC
        """

        # Execute export
        logger.info("Executing export query...")
        df = pd.read_sql(export_sql, conn)

        # Export to CSV
        logger.info(f"Writing {len(df):,} records to {filepath}")
        df.to_csv(filepath, index=False, encoding='utf-8')

        # Calculate file metrics
        file_size = filepath.stat().st_size
        file_hash = self._calculate_file_hash(filepath)

        # Validate export
        export_validation = self._validate_export(df, filepath)

        export_result = {
            'filename': filename,
            'filepath': str(filepath),
            'record_count': len(df),
            'file_size_bytes': file_size,
            'file_hash': file_hash,
            'export_status': 'SUCCESS' if export_validation['valid'] else 'FAILED',
            'validation': export_validation,
            'export_timestamp': self.export_timestamp
        }

        logger.info(f"✅ Export completed: {filename}")
        logger.info(f"  Records: {len(df):,}")
        logger.info(f"  File size: {file_size / 1024 / 1024:.2f} MB")
        logger.info(f"  Hash: {file_hash[:16]}...")

        return export_result

    def _calculate_file_hash(self, filepath: Path) -> str:
        """Calculate SHA-256 hash of exported file"""
        hash_sha256 = hashlib.sha256()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_sha256.update(chunk)
        return hash_sha256.hexdigest()

    def _validate_export(self, df: pd.DataFrame, filepath: Path) -> Dict[str, Any]:
        """Validate exported CSV file"""
        validation_result = {
            'valid': True,
            'issues': [],
            'metrics': {}
        }

        # Check file exists and readable
        if not filepath.exists():
            validation_result['valid'] = False
            validation_result['issues'].append('Export file does not exist')
            return validation_result

        # Verify file size
        if filepath.stat().st_size == 0:
            validation_result['valid'] = False
            validation_result['issues'].append('Export file is empty')
            return validation_result

        # Check dataframe structure
        expected_columns = [
            'Transaction_ID', 'Transaction_Value', 'Basket_Size', 'Category', 'Brand',
            'Daypart', 'Weekday_vs_Weekend', 'Time_of_transaction',
            'Demographics (Age/Gender/Role)', 'Emotions', 'Location',
            'Other_products_bought', 'Was_there_substitution', 'StoreID',
            'Timestamp', 'FacialID', 'DeviceID', 'Data_Quality_Score', 'Data_Source'
        ]

        missing_columns = set(expected_columns) - set(df.columns)
        if missing_columns:
            validation_result['valid'] = False
            validation_result['issues'].append(f'Missing columns: {missing_columns}')

        # Check for nulls in critical columns
        critical_columns = ['Transaction_ID', 'Transaction_Value', 'Category', 'Location']
        for col in critical_columns:
            if col in df.columns:
                null_count = df[col].isnull().sum()
                if null_count > 0:
                    validation_result['issues'].append(f'{col} has {null_count} null values')

        # Record metrics
        validation_result['metrics'] = {
            'record_count': len(df),
            'column_count': len(df.columns),
            'total_nulls': df.isnull().sum().sum(),
            'avg_quality_score': df['Data_Quality_Score'].mean() if 'Data_Quality_Score' in df.columns else None
        }

        return validation_result

    def log_export_audit(self, conn: pyodbc.Connection, export_result: Dict[str, Any],
                        dq_results: Dict[str, Any]) -> str:
        """Log export to audit trail"""
        logger.info("Logging export to audit trail...")

        export_id = self._generate_export_id()

        audit_sql = """
        INSERT INTO audit.export_history (
            export_id, export_timestamp, export_type, record_count,
            file_path, file_size_bytes, file_hash, export_status,
            quality_score, exported_by, export_parameters
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        audit_params = (
            export_id,
            self.export_timestamp,
            'FLAT_CSV',
            export_result['record_count'],
            export_result['filepath'],
            export_result['file_size_bytes'],
            export_result['file_hash'],
            export_result['export_status'],
            dq_results['completeness']['avg_quality_score'],
            'azure_flat_csv_export.py',
            json.dumps({
                'dq_status': dq_results['dashboard']['overall_quality_status'],
                'freshness': dq_results['freshness']['freshness_status'],
                'validation': export_result['validation']
            })
        )

        cursor = conn.cursor()
        cursor.execute(audit_sql, audit_params)
        conn.commit()
        cursor.close()

        logger.info(f"✅ Export logged to audit trail: {export_id}")
        return export_id

    def _generate_export_id(self) -> str:
        """Generate unique export ID"""
        import uuid
        return str(uuid.uuid4())

    def run_post_export_validation(self, conn: pyodbc.Connection, export_result: Dict[str, Any]) -> bool:
        """Run post-export validation checks"""
        logger.info("Running post-export validation...")

        # Re-check data quality after export
        current_dq = self.run_dq_checks(conn)

        # Compare with export metrics
        db_record_count = current_dq['completeness']['total_records']
        export_record_count = export_result['record_count']

        if abs(db_record_count - export_record_count) > 100:
            logger.error(f"Post-export validation failed: Record count mismatch")
            logger.error(f"  Database: {db_record_count:,}")
            logger.error(f"  Export: {export_record_count:,}")
            return False

        logger.info("✅ Post-export validation passed")
        return True

    def export(self, force_export: bool = False) -> Dict[str, Any]:
        """Main export function with comprehensive DQ and audit"""
        logger.info("🚀 Starting Azure SQL Flat CSV Export")
        logger.info("=" * 50)

        try:
            # Connect to Azure SQL
            logger.info("Connecting to Azure SQL...")
            conn = pyodbc.connect(self.connection_string)
            logger.info("✅ Connected to Azure SQL")

            # Run pre-export DQ checks
            dq_results = self.run_dq_checks(conn)

            # Validate export readiness
            if not force_export and not self.validate_export_readiness(dq_results):
                return {
                    'success': False,
                    'error': 'Export validation failed',
                    'dq_results': dq_results
                }

            # Export flat CSV
            export_result = self.export_flat_csv(conn)

            # Log to audit trail
            export_id = self.log_export_audit(conn, export_result, dq_results)
            export_result['export_id'] = export_id

            # Run post-export validation
            post_validation = self.run_post_export_validation(conn, export_result)
            export_result['post_validation'] = post_validation

            # Close connection
            conn.close()

            # Final result
            result = {
                'success': True,
                'export': export_result,
                'dq_results': dq_results,
                'export_timestamp': self.export_timestamp.isoformat()
            }

            logger.info("🎉 Export completed successfully!")
            logger.info(f"📁 File: {export_result['filename']}")
            logger.info(f"📊 Records: {export_result['record_count']:,}")
            logger.info(f"🔒 Hash: {export_result['file_hash'][:16]}...")
            logger.info(f"🆔 Export ID: {export_id}")

            return result

        except Exception as e:
            logger.error(f"❌ Export failed: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'export_timestamp': self.export_timestamp.isoformat()
            }

def main():
    """Command line interface"""
    import argparse

    parser = argparse.ArgumentParser(description='Azure SQL Flat CSV Export with DQ & Audit')
    parser.add_argument('--force', action='store_true', help='Force export even if DQ checks fail')
    parser.add_argument('--prefix', default='scout_flat_export', help='Filename prefix')
    parser.add_argument('--config-check', action='store_true', help='Check configuration only')

    args = parser.parse_args()

    # Configuration check
    if args.config_check:
        exporter = AzureFlatCSVExporter()
        print("Configuration:")
        print(f"  Server: {exporter.config['server']}")
        print(f"  Database: {exporter.config['database']}")
        print(f"  Username: {exporter.config['username']}")
        print(f"  Export path: {exporter.config['export_path']}")
        return

    # Run export
    exporter = AzureFlatCSVExporter()
    result = exporter.export(force_export=args.force)

    if result['success']:
        print(f"\n✅ Export successful!")
        print(f"File: {result['export']['filename']}")
        print(f"Records: {result['export']['record_count']:,}")
        print(f"Quality Score: {result['dq_results']['completeness']['avg_quality_score']:.1f}")
        sys.exit(0)
    else:
        print(f"\n❌ Export failed: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()