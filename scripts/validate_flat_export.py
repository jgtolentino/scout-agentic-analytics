#!/usr/bin/env python3
"""
Validate Azure Flat CSV Export
Independent validation of exported flat CSV files
"""

import pandas as pd
import pyodbc
import hashlib
import json
from pathlib import Path
from datetime import datetime, timezone
import logging
from typing import Dict, Any, List, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FlatExportValidator:
    """Independent validation of flat CSV exports"""

    def __init__(self, csv_path: str, azure_connection_string: Optional[str] = None):
        self.csv_path = Path(csv_path)
        self.connection_string = azure_connection_string
        self.validation_timestamp = datetime.now(timezone.utc)

    def validate_file_integrity(self) -> Dict[str, Any]:
        """Validate file integrity and basic structure"""
        logger.info("Validating file integrity...")

        validation = {
            'valid': True,
            'issues': [],
            'metrics': {}
        }

        # Check file exists
        if not self.csv_path.exists():
            validation['valid'] = False
            validation['issues'].append(f'File does not exist: {self.csv_path}')
            return validation

        # Check file size
        file_size = self.csv_path.stat().st_size
        validation['metrics']['file_size_bytes'] = file_size

        if file_size == 0:
            validation['valid'] = False
            validation['issues'].append('File is empty')
            return validation

        # Calculate file hash
        file_hash = self._calculate_file_hash()
        validation['metrics']['file_hash'] = file_hash

        try:
            # Load CSV
            df = pd.read_csv(self.csv_path)
            validation['metrics']['record_count'] = len(df)
            validation['metrics']['column_count'] = len(df.columns)

            logger.info(f"✅ File integrity check passed")
            logger.info(f"  Records: {len(df):,}")
            logger.info(f"  Columns: {len(df.columns)}")
            logger.info(f"  Size: {file_size / 1024 / 1024:.2f} MB")

        except Exception as e:
            validation['valid'] = False
            validation['issues'].append(f'Failed to read CSV: {str(e)}')

        return validation

    def validate_schema_structure(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Validate CSV schema matches expected structure"""
        logger.info("Validating schema structure...")

        validation = {
            'valid': True,
            'issues': [],
            'metrics': {}
        }

        # Expected columns from flat export specification
        expected_columns = [
            'Transaction_ID',
            'Transaction_Value',
            'Basket_Size',
            'Category',
            'Brand',
            'Daypart',
            'Weekday_vs_Weekend',
            'Time_of_transaction',
            'Demographics (Age/Gender/Role)',
            'Emotions',
            'Location',
            'Other_products_bought',
            'Was_there_substitution',
            'StoreID',
            'Timestamp',
            'FacialID',
            'DeviceID',
            'Data_Quality_Score',
            'Data_Source'
        ]

        actual_columns = df.columns.tolist()

        # Check for missing columns
        missing_columns = set(expected_columns) - set(actual_columns)
        if missing_columns:
            validation['valid'] = False
            validation['issues'].append(f'Missing required columns: {missing_columns}')

        # Check for extra columns
        extra_columns = set(actual_columns) - set(expected_columns)
        if extra_columns:
            validation['issues'].append(f'Unexpected columns: {extra_columns}')

        validation['metrics']['expected_columns'] = len(expected_columns)
        validation['metrics']['actual_columns'] = len(actual_columns)
        validation['metrics']['missing_columns'] = len(missing_columns)
        validation['metrics']['extra_columns'] = len(extra_columns)

        if validation['valid']:
            logger.info("✅ Schema structure validation passed")
        else:
            logger.error("❌ Schema structure validation failed")

        return validation

    def validate_data_quality(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Validate data quality of exported records"""
        logger.info("Validating data quality...")

        validation = {
            'valid': True,
            'issues': [],
            'metrics': {}
        }

        # 1. Check for null values in critical columns
        critical_columns = ['Transaction_ID', 'Transaction_Value', 'Category', 'Location', 'StoreID']
        for col in critical_columns:
            if col in df.columns:
                null_count = df[col].isnull().sum()
                validation['metrics'][f'{col}_nulls'] = null_count
                if null_count > 0:
                    validation['issues'].append(f'{col} has {null_count} null values')

        # 2. Validate business rules - REAL PRODUCTION DATA
        if 'Category' in df.columns:
            valid_categories = {
                'Snacks & Confectionery', 'Salty Snacks (Chichirya)', 'Candies & Sweets',
                'Body Care', 'Hair Care', 'Oral Care', 'Beverages', 'Non-Alcoholic',
                'Other Essentials', 'unspecified', 'Unknown'
            }
            invalid_categories = set(df['Category'].unique()) - valid_categories
            if invalid_categories:
                validation['issues'].append(f'Invalid categories: {invalid_categories}')

        if 'Brand' in df.columns:
            valid_brands = {
                'Safeguard', 'Jack \'n Jill', 'Piattos', 'Combi', 'Pantene',
                'Head & Shoulders', 'Close Up', 'Cream Silk', 'Gatorade',
                'C2', 'Coca-Cola', 'Unknown'
            }
            # Allow any brand - real production has many brands
            # Just check for obvious test data
            test_brands = {'Brand A', 'Brand B', 'Brand C', 'Local Brand'}
            invalid_brands = set(df['Brand'].unique()).intersection(test_brands)
            if invalid_brands:
                validation['issues'].append(f'Test/placeholder brands detected: {invalid_brands}')

        if 'Location' in df.columns:
            valid_locations = {'Los Baños', 'Quezon City', 'Manila', 'Pateros', 'Metro Manila'}
            invalid_locations = set(df['Location'].unique()) - valid_locations
            if invalid_locations:
                validation['issues'].append(f'Invalid locations: {invalid_locations}')

        if 'StoreID' in df.columns:
            valid_store_ids = {102, 103, 104, 109, 110, 112}
            invalid_store_ids = set(df['StoreID'].unique()) - valid_store_ids
            if invalid_store_ids:
                validation['issues'].append(f'Invalid store IDs: {invalid_store_ids}')

        if 'Was_there_substitution' in df.columns:
            valid_substitution = {'Yes', 'No'}
            invalid_substitution = set(df['Was_there_substitution'].unique()) - valid_substitution
            if invalid_substitution:
                validation['issues'].append(f'Invalid substitution values: {invalid_substitution}')

        # 3. Validate numeric ranges
        if 'Transaction_Value' in df.columns:
            negative_amounts = (df['Transaction_Value'] < 0).sum()
            very_high_amounts = (df['Transaction_Value'] > 5000).sum()
            validation['metrics']['negative_amounts'] = negative_amounts
            validation['metrics']['very_high_amounts'] = very_high_amounts

            if negative_amounts > 0:
                validation['issues'].append(f'{negative_amounts} records with negative transaction values')

        if 'Basket_Size' in df.columns:
            negative_baskets = (df['Basket_Size'] < 0).sum()
            very_large_baskets = (df['Basket_Size'] > 50).sum()
            validation['metrics']['negative_baskets'] = negative_baskets
            validation['metrics']['very_large_baskets'] = very_large_baskets

            if negative_baskets > 0:
                validation['issues'].append(f'{negative_baskets} records with negative basket sizes')

        # 4. Calculate overall metrics
        total_issues = len(validation['issues'])
        validation['metrics']['total_issues'] = total_issues
        validation['metrics']['data_quality_score'] = max(0, 100 - (total_issues * 5))  # 5 points per issue

        if total_issues == 0:
            logger.info("✅ Data quality validation passed")
        else:
            logger.warning(f"⚠️  Data quality validation found {total_issues} issues")
            if total_issues > 10:
                validation['valid'] = False

        return validation

    def validate_completeness(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Validate data completeness"""
        logger.info("Validating data completeness...")

        validation = {
            'valid': True,
            'issues': [],
            'metrics': {}
        }

        total_cells = len(df) * len(df.columns)
        total_nulls = df.isnull().sum().sum()
        completeness_pct = ((total_cells - total_nulls) / total_cells * 100) if total_cells > 0 else 0

        validation['metrics']['total_cells'] = total_cells
        validation['metrics']['total_nulls'] = total_nulls
        validation['metrics']['completeness_percentage'] = completeness_pct

        # Check completeness by column
        for col in df.columns:
            null_count = df[col].isnull().sum()
            col_completeness = ((len(df) - null_count) / len(df) * 100) if len(df) > 0 else 0
            validation['metrics'][f'{col}_completeness'] = col_completeness

            if col_completeness < 95:  # Less than 95% complete
                validation['issues'].append(f'{col} is only {col_completeness:.1f}% complete')

        # Overall completeness threshold
        if completeness_pct < 90:
            validation['valid'] = False
            validation['issues'].append(f'Overall completeness {completeness_pct:.1f}% below threshold (90%)')

        logger.info(f"✅ Completeness validation: {completeness_pct:.1f}%")
        return validation

    def validate_against_database(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Validate export against source database"""
        if not self.connection_string:
            return {'valid': True, 'issues': ['Database validation skipped - no connection string'], 'metrics': {}}

        logger.info("Validating against source database...")

        validation = {
            'valid': True,
            'issues': [],
            'metrics': {}
        }

        try:
            conn = pyodbc.connect(self.connection_string)

            # Get database totals
            db_sql = """
            SELECT
                COUNT(*) as db_record_count,
                SUM(Transaction_Value) as db_total_revenue,
                AVG(Data_Quality_Score) as db_avg_quality
            FROM gold.v_flat_export_ready
            """

            db_result = pd.read_sql(db_sql, conn)
            db_record_count = db_result['db_record_count'].iloc[0]
            db_total_revenue = db_result['db_total_revenue'].iloc[0]
            db_avg_quality = db_result['db_avg_quality'].iloc[0]

            # Calculate export totals
            export_record_count = len(df)
            export_total_revenue = df['Transaction_Value'].sum() if 'Transaction_Value' in df.columns else 0
            export_avg_quality = df['Data_Quality_Score'].mean() if 'Data_Quality_Score' in df.columns else 0

            # Compare totals
            record_diff = abs(db_record_count - export_record_count)
            revenue_diff = abs(db_total_revenue - export_total_revenue) if db_total_revenue else 0
            quality_diff = abs(db_avg_quality - export_avg_quality) if db_avg_quality else 0

            validation['metrics']['db_record_count'] = db_record_count
            validation['metrics']['export_record_count'] = export_record_count
            validation['metrics']['record_difference'] = record_diff
            validation['metrics']['db_total_revenue'] = db_total_revenue
            validation['metrics']['export_total_revenue'] = export_total_revenue
            validation['metrics']['revenue_difference'] = revenue_diff
            validation['metrics']['quality_difference'] = quality_diff

            # Validation thresholds
            if record_diff > 100:  # Allow small differences due to timing
                validation['issues'].append(f'Record count difference too large: {record_diff}')

            if revenue_diff > 1000:  # Allow small rounding differences
                validation['issues'].append(f'Revenue difference too large: {revenue_diff:.2f}')

            if quality_diff > 5:  # Quality score difference
                validation['issues'].append(f'Quality score difference: {quality_diff:.2f}')

            conn.close()
            logger.info("✅ Database validation completed")

        except Exception as e:
            validation['issues'].append(f'Database validation failed: {str(e)}')
            logger.error(f"❌ Database validation error: {str(e)}")

        return validation

    def generate_validation_report(self, validations: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
        """Generate comprehensive validation report"""
        logger.info("Generating validation report...")

        all_valid = all(v['valid'] for v in validations.values())
        total_issues = sum(len(v['issues']) for v in validations.values())

        # Overall status
        if all_valid and total_issues == 0:
            overall_status = 'EXCELLENT'
        elif all_valid and total_issues <= 5:
            overall_status = 'GOOD'
        elif total_issues <= 15:
            overall_status = 'ACCEPTABLE'
        else:
            overall_status = 'NEEDS_ATTENTION'

        report = {
            'validation_timestamp': self.validation_timestamp.isoformat(),
            'file_path': str(self.csv_path),
            'overall_status': overall_status,
            'all_validations_passed': all_valid,
            'total_issues': total_issues,
            'validations': validations,
            'summary': {
                'file_integrity': validations.get('file_integrity', {}).get('valid', False),
                'schema_structure': validations.get('schema_structure', {}).get('valid', False),
                'data_quality': validations.get('data_quality', {}).get('valid', False),
                'completeness': validations.get('completeness', {}).get('valid', False),
                'database_consistency': validations.get('database', {}).get('valid', False)
            }
        }

        return report

    def _calculate_file_hash(self) -> str:
        """Calculate SHA-256 hash of file"""
        hash_sha256 = hashlib.sha256()
        with open(self.csv_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_sha256.update(chunk)
        return hash_sha256.hexdigest()

    def validate(self) -> Dict[str, Any]:
        """Run comprehensive validation of flat CSV export"""
        logger.info("🔍 Starting comprehensive flat CSV validation")
        logger.info("=" * 50)

        validations = {}

        # 1. File integrity validation
        validations['file_integrity'] = self.validate_file_integrity()

        if not validations['file_integrity']['valid']:
            logger.error("❌ File integrity validation failed - stopping validation")
            return self.generate_validation_report(validations)

        # Load dataframe for further validation
        try:
            df = pd.read_csv(self.csv_path)
        except Exception as e:
            logger.error(f"❌ Failed to load CSV for validation: {str(e)}")
            validations['file_integrity']['issues'].append(f'Failed to load CSV: {str(e)}')
            return self.generate_validation_report(validations)

        # 2. Schema structure validation
        validations['schema_structure'] = self.validate_schema_structure(df)

        # 3. Data quality validation
        validations['data_quality'] = self.validate_data_quality(df)

        # 4. Completeness validation
        validations['completeness'] = self.validate_completeness(df)

        # 5. Database consistency validation (if connection available)
        validations['database'] = self.validate_against_database(df)

        # Generate final report
        report = self.generate_validation_report(validations)

        # Log summary
        logger.info("📊 Validation Summary:")
        logger.info(f"  Overall Status: {report['overall_status']}")
        logger.info(f"  Total Issues: {report['total_issues']}")
        logger.info(f"  File Integrity: {'✅' if report['summary']['file_integrity'] else '❌'}")
        logger.info(f"  Schema Structure: {'✅' if report['summary']['schema_structure'] else '❌'}")
        logger.info(f"  Data Quality: {'✅' if report['summary']['data_quality'] else '❌'}")
        logger.info(f"  Completeness: {'✅' if report['summary']['completeness'] else '❌'}")
        logger.info(f"  Database Consistency: {'✅' if report['summary']['database_consistency'] else '❌'}")

        return report

def main():
    """Command line interface"""
    import argparse

    parser = argparse.ArgumentParser(description='Validate Azure Flat CSV Export')
    parser.add_argument('csv_path', help='Path to CSV file to validate')
    parser.add_argument('--connection-string', help='Azure SQL connection string for database validation')
    parser.add_argument('--report-file', help='Save validation report to JSON file')

    args = parser.parse_args()

    # Run validation
    validator = FlatExportValidator(args.csv_path, args.connection_string)
    report = validator.validate()

    # Save report if requested
    if args.report_file:
        with open(args.report_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        print(f"Validation report saved to: {args.report_file}")

    # Print summary
    print(f"\n📊 Validation Results:")
    print(f"Overall Status: {report['overall_status']}")
    print(f"All Validations Passed: {report['all_validations_passed']}")
    print(f"Total Issues: {report['total_issues']}")

    # Exit with appropriate code
    if report['overall_status'] in ['EXCELLENT', 'GOOD']:
        exit(0)
    elif report['overall_status'] == 'ACCEPTABLE':
        exit(1)
    else:
        exit(2)

if __name__ == "__main__":
    main()