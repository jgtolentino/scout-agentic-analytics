#!/usr/bin/env python3
"""
Azure SQL Bulk Loader - Simple bulk insert, let Azure handle deduplication
Strategy: Load ALL files fast → Azure SQL does deduplication using ROW_NUMBER()
"""

import json
import os
import pyodbc
import logging
from typing import List
from datetime import datetime
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('azure_bulk_load.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class AzureBulkLoader:
    def __init__(self, connection_string: str, payload_directory: str):
        self.connection_string = connection_string
        self.payload_directory = Path(payload_directory)
        self.stats = {
            'files_scanned': 0,
            'files_loaded': 0,
            'json_errors': 0,
            'total_file_size': 0
        }

    def connect_database(self) -> pyodbc.Connection:
        """Establish database connection"""
        try:
            conn = pyodbc.connect(self.connection_string, timeout=60)
            conn.autocommit = False
            logger.info("Database connection established")
            return conn
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise

    def scan_all_payload_files(self) -> List[dict]:
        """Scan all JSON files and prepare for bulk insert"""
        logger.info(f"Scanning payload files in {self.payload_directory}")

        all_payloads = []

        for device_dir in self.payload_directory.iterdir():
            if not device_dir.is_dir():
                continue

            device_id = device_dir.name
            logger.info(f"Processing device: {device_id}")

            for file_path in device_dir.glob("*.json"):
                self.stats['files_scanned'] += 1
                self.stats['total_file_size'] += file_path.stat().st_size

                try:
                    # Parse JSON
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)

                    # Extract transaction_id (primary dedup key)
                    transaction_id = (
                        data.get('transactionId') or
                        data.get('transaction_id') or
                        'unspecified'
                    )

                    # Get store_id from data or device path
                    store_id = (
                        data.get('storeId') or
                        data.get('store_id') or
                        device_dir.name.split('-')[-1] if '-' in device_dir.name else 'unknown'
                    )

                    # Basic quality checks
                    items = data.get('items', [])
                    has_items = len(items) > 0 if isinstance(items, list) else False
                    item_count = len(items) if isinstance(items, list) else 0

                    payload_record = {
                        'transaction_id': transaction_id[:100],  # Truncate for DB column
                        'device_id': device_id[:50],
                        'store_id': store_id[:20],
                        'file_path': str(file_path)[:500],
                        'payload_json': json.dumps(data, ensure_ascii=False),
                        'file_timestamp': datetime.fromtimestamp(file_path.stat().st_mtime),
                        'has_items': has_items,
                        'item_count': item_count,
                        'payload_size': len(json.dumps(data))
                    }

                    all_payloads.append(payload_record)
                    self.stats['files_loaded'] += 1

                except json.JSONDecodeError as e:
                    logger.warning(f"JSON decode error in {file_path}: {e}")
                    self.stats['json_errors'] += 1
                except Exception as e:
                    logger.error(f"Error processing {file_path}: {e}")

                # Progress indicator
                if self.stats['files_scanned'] % 1000 == 0:
                    logger.info(f"Processed {self.stats['files_scanned']} files...")

        logger.info(f"Scanning complete: {self.stats['files_loaded']} valid files from {self.stats['files_scanned']} total")
        return all_payloads

    def bulk_insert_to_azure(self, payloads: List[dict]):
        """Bulk insert all payloads to Azure SQL staging table"""
        logger.info(f"Starting bulk insert of {len(payloads)} payloads to Azure SQL...")

        conn = self.connect_database()
        cursor = conn.cursor()

        try:
            # Prepare bulk insert SQL - using PayloadTransactions table directly
            insert_sql = """
            INSERT INTO dbo.PayloadTransactions (
                transaction_id, device_id, store_id,
                payload_json, file_timestamp, has_items, item_count, payload_size
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """

            # Prepare batch data (excluding file_path for PayloadTransactions table)
            batch_data = []
            for payload in payloads:
                batch_data.append((
                    payload['transaction_id'],
                    payload['device_id'],
                    payload['store_id'],
                    payload['payload_json'],
                    payload['file_timestamp'],
                    payload['has_items'],
                    payload['item_count'],
                    payload['payload_size']
                ))

            # Execute bulk insert in batches of 1000
            batch_size = 1000
            total_batches = (len(batch_data) + batch_size - 1) // batch_size

            for i in range(0, len(batch_data), batch_size):
                batch = batch_data[i:i + batch_size]
                batch_num = (i // batch_size) + 1

                logger.info(f"Inserting batch {batch_num}/{total_batches} ({len(batch)} records)...")
                cursor.executemany(insert_sql, batch)

                # Commit each batch to avoid transaction log issues
                conn.commit()

            logger.info(f"Bulk insert completed: {len(batch_data)} records loaded to staging")

        except Exception as e:
            conn.rollback()
            logger.error(f"Bulk insert failed: {e}")
            raise
        finally:
            cursor.close()
            conn.close()

    def execute_azure_deduplication(self):
        """Execute Azure SQL deduplication and ETL"""
        logger.info("Executing Azure SQL deduplication ETL...")

        conn = self.connect_database()
        cursor = conn.cursor()

        try:
            # Read and execute the Azure deduplication script
            etl_script_path = Path(__file__).parent.parent / "sql" / "05_azure_sql_deduplication.sql"

            with open(etl_script_path, 'r', encoding='utf-8') as f:
                etl_script = f.read()

            # Execute the complete script
            start_time = datetime.now()
            cursor.execute(etl_script)
            conn.commit()
            duration = (datetime.now() - start_time).total_seconds()

            logger.info(f"Azure SQL deduplication completed in {duration:.2f} seconds")

            # Get final results
            cursor.execute("SELECT @@ROWCOUNT as processed_records")
            results = cursor.fetchone()

            return results[0] if results else 0

        except Exception as e:
            conn.rollback()
            logger.error(f"Azure deduplication failed: {e}")
            raise
        finally:
            cursor.close()
            conn.close()

    def generate_summary_report(self):
        """Generate final processing summary"""
        logger.info("Generating processing summary...")

        conn = self.connect_database()
        cursor = conn.cursor()

        try:
            # Get final statistics from database
            queries = {
                'unique_transactions': "SELECT COUNT(*) FROM dbo.PayloadTransactions",
                'total_items': "SELECT COUNT(*) FROM dbo.TransactionItems",
                'unique_brands': "SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems WHERE brand_name IS NOT NULL",
                'baskets': "SELECT COUNT(*) FROM dbo.TransactionBaskets",
                'substitutions': "SELECT COUNT(*) FROM dbo.BrandSubstitutions"
            }

            results = {}
            for name, query in queries.items():
                cursor.execute(query)
                results[name] = cursor.fetchone()[0]

            # Print comprehensive report
            print("\n" + "="*80)
            print("AZURE SQL BULK LOAD + DEDUPLICATION - FINAL REPORT")
            print("="*80)
            print(f"File Processing:")
            print(f"  Files Scanned: {self.stats['files_scanned']:,}")
            print(f"  Valid JSON Files: {self.stats['files_loaded']:,}")
            print(f"  JSON Parse Errors: {self.stats['json_errors']:,}")
            print(f"  Total File Size: {self.stats['total_file_size'] / (1024*1024):.1f} MB")
            print()
            print(f"Azure SQL Results:")
            print(f"  Unique Transactions: {results['unique_transactions']:,}")
            print(f"  Transaction Items: {results['total_items']:,}")
            print(f"  Unique Brands: {results['unique_brands']:,}")
            print(f"  Transaction Baskets: {results['baskets']:,}")
            print(f"  Brand Substitutions: {results['substitutions']:,}")
            print()

            dedup_removed = self.stats['files_loaded'] - results['unique_transactions']
            dedup_rate = (dedup_removed / self.stats['files_loaded'] * 100) if self.stats['files_loaded'] > 0 else 0

            print(f"Deduplication Performance:")
            print(f"  Duplicates Removed: {dedup_removed:,}")
            print(f"  Deduplication Rate: {dedup_rate:.2f}%")
            print(f"  Processing Efficiency: {self.stats['files_loaded'] / self.stats['files_scanned'] * 100:.1f}%")
            print("="*80)
            print("AZURE SQL BULK LOAD COMPLETED SUCCESSFULLY")
            print("="*80)

        except Exception as e:
            logger.error(f"Report generation failed: {e}")
        finally:
            cursor.close()
            conn.close()

    def run(self):
        """Execute complete bulk load + Azure deduplication pipeline"""
        start_time = datetime.now()

        try:
            # Step 1: Scan all payload files
            logger.info("Step 1: Scanning all payload files...")
            all_payloads = self.scan_all_payload_files()

            if not all_payloads:
                logger.error("No valid payload files found!")
                return

            # Step 2: Bulk insert to Azure staging
            logger.info("Step 2: Bulk loading to Azure SQL staging table...")
            self.bulk_insert_to_azure(all_payloads)

            # Step 3: Execute Azure deduplication
            logger.info("Step 3: Executing Azure SQL deduplication and ETL...")
            self.execute_azure_deduplication()

            # Step 4: Generate summary report
            logger.info("Step 4: Generating final report...")
            self.generate_summary_report()

            total_duration = (datetime.now() - start_time).total_seconds()
            logger.info(f"Complete pipeline finished in {total_duration:.2f} seconds")

        except Exception as e:
            logger.error(f"Pipeline failed: {e}")
            raise

if __name__ == "__main__":
    # Configuration
    connection_string = (
        "Driver={ODBC Driver 17 for SQL Server};"
        "Server=sqltbwaprojectscoutserver.database.windows.net;"
        "Database=SQL-TBWA-ProjectScout-Reporting-Prod;"
        "UID=sqladmin;"
        "PWD=Azure_pw26;"
        "TrustServerCertificate=yes;"
        "Connection Timeout=60;"
    )

    payload_directory = "/Users/tbwa/Downloads/Project-Scout-2 3/dbo.payloadtransactions"

    # Execute Azure bulk load + deduplication
    loader = AzureBulkLoader(connection_string, payload_directory)
    loader.run()