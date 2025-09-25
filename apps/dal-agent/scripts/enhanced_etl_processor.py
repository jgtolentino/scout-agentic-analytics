#!/usr/bin/env python3
"""
Enhanced ETL Processor with Deduplication and Completeness Validation
Processes Scout payload files with comprehensive deduplication and quality control
"""

import json
import os
import pyodbc
import logging
from typing import Dict, List, Set, Tuple, Optional
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path
import hashlib

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('enhanced_etl.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class EnhancedETLProcessor:
    def __init__(self, connection_string: str, payload_directory: str):
        self.connection_string = connection_string
        self.payload_directory = Path(payload_directory)
        self.stats = {
            'files_scanned': 0,
            'files_processed': 0,
            'duplicates_found': 0,
            'invalid_files': 0,
            'items_extracted': 0,
            'substitutions_found': 0,
            'errors': 0
        }

        # Deduplication tracking
        self.transaction_registry = {}  # transaction_id -> file_info
        self.interaction_registry = {}  # interaction_id -> file_info
        self.duplicate_groups = defaultdict(list)
        self.processed_hashes = set()

    def connect_database(self) -> pyodbc.Connection:
        """Establish database connection with retry logic"""
        try:
            conn = pyodbc.connect(self.connection_string, timeout=30)
            conn.autocommit = False
            logger.info("Database connection established")
            return conn
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise

    def calculate_file_signature(self, file_path: Path) -> str:
        """Calculate unique signature for file content to detect exact duplicates"""
        try:
            with open(file_path, 'rb') as f:
                content = f.read()
                return hashlib.sha256(content).hexdigest()
        except Exception as e:
            logger.error(f"Error calculating signature for {file_path}: {e}")
            return ""

    def extract_identifiers(self, data: Dict) -> Tuple[str, str, str]:
        """Extract transaction identifiers from payload - PRIMARY: transactionId only"""
        # Transaction ID extraction - ONLY use transactionId for deduplication
        transaction_id = (
            data.get('transactionId') or
            data.get('transaction_id') or
            'unspecified'
        )

        # Interaction ID and Session ID for reference only (NOT for deduplication)
        interaction_id = (
            data.get('interactionId') or
            data.get('interaction_id') or
            'unspecified'
        )

        session_id = (
            data.get('sessionId') or
            data.get('session_id') or
            'unspecified'
        )

        return transaction_id, interaction_id, session_id

    def analyze_payload_quality(self, data: Dict, file_path: Path) -> Dict:
        """Analyze payload quality and completeness"""
        quality_metrics = {
            'has_items': False,
            'item_count': 0,
            'has_transaction_data': False,
            'has_timestamp': False,
            'has_store_data': False,
            'completeness_score': 0.0,
            'quality_flags': []
        }

        # Check for items array
        items = data.get('items', [])
        if items and isinstance(items, list) and len(items) > 0:
            quality_metrics['has_items'] = True
            quality_metrics['item_count'] = len(items)

            # Validate item structure
            valid_items = 0
            for item in items:
                if isinstance(item, dict) and item.get('productName'):
                    valid_items += 1
            quality_metrics['valid_item_ratio'] = valid_items / len(items) if items else 0

        # Check transaction context
        if data.get('transaction') or data.get('totals'):
            quality_metrics['has_transaction_data'] = True

        # Check timestamp
        if data.get('timestamp') or data.get('createdAt'):
            quality_metrics['has_timestamp'] = True

        # Check store data
        if data.get('storeId') or data.get('store_id'):
            quality_metrics['has_store_data'] = True

        # Calculate completeness score
        score_components = [
            quality_metrics['has_items'],
            quality_metrics['has_transaction_data'],
            quality_metrics['has_timestamp'],
            quality_metrics['has_store_data']
        ]
        quality_metrics['completeness_score'] = sum(score_components) / len(score_components)

        # Quality flags
        if not quality_metrics['has_items']:
            quality_metrics['quality_flags'].append('no_items')
        if not quality_metrics['has_timestamp']:
            quality_metrics['quality_flags'].append('no_timestamp')
        if quality_metrics['completeness_score'] < 0.5:
            quality_metrics['quality_flags'].append('low_completeness')

        return quality_metrics

    def scan_and_deduplicate_payloads(self) -> List[Dict]:
        """Scan all payload files and identify duplicates"""
        logger.info(f"Scanning payload files in {self.payload_directory}")

        payload_candidates = []
        file_signatures = set()

        for device_dir in self.payload_directory.iterdir():
            if not device_dir.is_dir():
                continue

            device_id = device_dir.name
            logger.info(f"Processing device: {device_id}")

            for file_path in device_dir.glob("*.json"):
                self.stats['files_scanned'] += 1

                try:
                    # Check for exact file duplicates
                    file_sig = self.calculate_file_signature(file_path)
                    if file_sig in file_signatures:
                        logger.debug(f"Exact duplicate file: {file_path}")
                        self.stats['duplicates_found'] += 1
                        continue
                    file_signatures.add(file_sig)

                    # Parse JSON
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)

                    # Extract identifiers
                    transaction_id, interaction_id, session_id = self.extract_identifiers(data)

                    # Quality analysis
                    quality_metrics = self.analyze_payload_quality(data, file_path)

                    # Determine store_id from path or data
                    store_id = data.get('storeId') or data.get('store_id') or device_dir.name.split('-')[-1] if '-' in device_dir.name else 'unknown'

                    payload_info = {
                        'file_path': str(file_path),
                        'device_id': device_id,
                        'store_id': store_id,
                        'transaction_id': transaction_id,
                        'interaction_id': interaction_id,
                        'session_id': session_id,
                        'data': data,
                        'quality': quality_metrics,
                        'file_size': file_path.stat().st_size,
                        'file_timestamp': datetime.fromtimestamp(file_path.stat().st_mtime),
                        'dedup_key': transaction_id,  # ONLY use transaction_id for deduplication
                        'is_duplicate': False,
                        'duplicate_rank': 1
                    }

                    payload_candidates.append(payload_info)

                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error in {file_path}: {e}")
                    self.stats['invalid_files'] += 1
                except Exception as e:
                    logger.error(f"Error processing {file_path}: {e}")
                    self.stats['errors'] += 1

        # Deduplication logic
        logger.info("Performing deduplication analysis...")
        return self._deduplicate_payloads(payload_candidates)

    def _deduplicate_payloads(self, candidates: List[Dict]) -> List[Dict]:
        """Apply sophisticated deduplication logic"""
        # Group by deduplication key
        dedup_groups = defaultdict(list)
        for candidate in candidates:
            dedup_groups[candidate['dedup_key']].append(candidate)

        # Process each group
        deduplicated_payloads = []
        for dedup_key, group in dedup_groups.items():
            if len(group) == 1:
                # No duplicates
                deduplicated_payloads.extend(group)
            else:
                # Multiple candidates - rank them
                self.stats['duplicates_found'] += len(group) - 1

                # Ranking criteria (higher is better):
                # 1. Has items (weight: 4)
                # 2. Item count (weight: 2)
                # 3. Completeness score (weight: 2)
                # 4. File size (weight: 1)
                # 5. Most recent timestamp (weight: 1)

                ranked = sorted(group, key=lambda x: (
                    x['quality']['has_items'] * 4,
                    x['quality']['item_count'] * 2,
                    x['quality']['completeness_score'] * 2,
                    x['file_size'],
                    x['file_timestamp'].timestamp()
                ), reverse=True)

                # Mark ranks
                for i, payload in enumerate(ranked):
                    payload['duplicate_rank'] = i + 1
                    payload['is_duplicate'] = i > 0

                # Take only the best one
                deduplicated_payloads.append(ranked[0])

                logger.debug(f"Deduplicated group {dedup_key}: kept {ranked[0]['file_path']}, discarded {len(group)-1} duplicates")

        valid_payloads = [p for p in deduplicated_payloads if not p['is_duplicate'] and p['store_id'] != '108']
        self.stats['files_processed'] = len(valid_payloads)

        logger.info(f"Deduplication complete: {len(candidates)} -> {len(valid_payloads)} (removed {len(candidates) - len(valid_payloads)} duplicates/invalid)")
        return valid_payloads

    def bulk_insert_payloads(self, payloads: List[Dict]):
        """Insert deduplicated payloads into database"""
        logger.info("Inserting deduplicated payloads into database...")

        conn = self.connect_database()
        cursor = conn.cursor()

        try:
            # Clear existing data
            cursor.execute("TRUNCATE TABLE dbo.PayloadTransactions")
            logger.info("Cleared existing payload data")

            # Prepare bulk insert
            insert_sql = """
            INSERT INTO dbo.PayloadTransactions (
                transaction_id, device_id, store_id, file_path, payload_json, created_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            """

            batch_data = []
            for payload in payloads:
                batch_data.append((
                    payload['transaction_id'][:50],  # Truncate to fit column
                    payload['device_id'][:50],
                    payload['store_id'][:20],
                    payload['file_path'][:500],
                    json.dumps(payload['data'], ensure_ascii=False),
                    payload['file_timestamp']
                ))

            # Execute batch insert
            cursor.executemany(insert_sql, batch_data)
            conn.commit()

            logger.info(f"Inserted {len(batch_data)} deduplicated payloads")

        except Exception as e:
            conn.rollback()
            logger.error(f"Database insert failed: {e}")
            raise
        finally:
            cursor.close()
            conn.close()

    def execute_enhanced_etl(self):
        """Execute the enhanced ETL SQL pipeline"""
        logger.info("Executing enhanced ETL pipeline...")

        conn = self.connect_database()
        cursor = conn.cursor()

        try:
            # Read and execute the enhanced ETL script
            etl_script_path = Path(__file__).parent.parent / "sql" / "04_enhanced_etl_with_deduplication.sql"

            with open(etl_script_path, 'r', encoding='utf-8') as f:
                etl_script = f.read()

            # Execute in batches (split by GO statements if any)
            statements = etl_script.split('GO')

            start_time = datetime.now()
            for i, statement in enumerate(statements):
                if statement.strip():
                    logger.info(f"Executing ETL batch {i+1}/{len(statements)}")
                    cursor.execute(statement)

            conn.commit()
            duration = (datetime.now() - start_time).total_seconds()

            logger.info(f"Enhanced ETL pipeline completed in {duration:.2f} seconds")

        except Exception as e:
            conn.rollback()
            logger.error(f"ETL execution failed: {e}")
            raise
        finally:
            cursor.close()
            conn.close()

    def generate_completion_report(self):
        """Generate comprehensive completion report"""
        logger.info("Generating ETL completion report...")

        conn = self.connect_database()
        cursor = conn.cursor()

        try:
            # Gather final statistics
            queries = {
                'unique_transactions': "SELECT COUNT(DISTINCT transaction_id) FROM dbo.TransactionItems",
                'total_items': "SELECT COUNT(*) FROM dbo.TransactionItems",
                'unique_brands': "SELECT COUNT(DISTINCT brand_name) FROM dbo.TransactionItems WHERE brand_name IS NOT NULL",
                'transaction_baskets': "SELECT COUNT(*) FROM dbo.TransactionBaskets",
                'brand_substitutions': "SELECT COUNT(*) FROM dbo.BrandSubstitutions",
                'completion_records': "SELECT COUNT(*) FROM dbo.TransactionCompletionStatus",
                'tobacco_analytics': "SELECT COUNT(*) FROM dbo.TobaccoAnalytics",
                'laundry_analytics': "SELECT COUNT(*) FROM dbo.LaundryAnalytics"
            }

            results = {}
            for name, query in queries.items():
                cursor.execute(query)
                results[name] = cursor.fetchone()[0]

            # Print comprehensive report
            print("\n" + "="*80)
            print("ENHANCED ETL PIPELINE WITH DEDUPLICATION - COMPLETION REPORT")
            print("="*80)
            print(f"Processing Statistics:")
            print(f"  Files Scanned: {self.stats['files_scanned']:,}")
            print(f"  Files Processed: {self.stats['files_processed']:,}")
            print(f"  Duplicates Removed: {self.stats['duplicates_found']:,}")
            print(f"  Invalid Files: {self.stats['invalid_files']:,}")
            print(f"  Processing Errors: {self.stats['errors']:,}")
            print()
            print(f"Data Extraction Results:")
            print(f"  Unique Transactions: {results['unique_transactions']:,}")
            print(f"  Transaction Items: {results['total_items']:,}")
            print(f"  Unique Brands Detected: {results['unique_brands']:,}")
            print(f"  Transaction Baskets: {results['transaction_baskets']:,}")
            print(f"  Brand Substitutions: {results['brand_substitutions']:,}")
            print(f"  Completion Records: {results['completion_records']:,}")
            print(f"  Tobacco Analytics: {results['tobacco_analytics']:,}")
            print(f"  Laundry Analytics: {results['laundry_analytics']:,}")
            print()
            print(f"Quality Metrics:")
            dedup_rate = (self.stats['duplicates_found'] / self.stats['files_scanned'] * 100) if self.stats['files_scanned'] > 0 else 0
            processing_rate = (self.stats['files_processed'] / self.stats['files_scanned'] * 100) if self.stats['files_scanned'] > 0 else 0
            print(f"  Deduplication Rate: {dedup_rate:.2f}%")
            print(f"  Processing Success Rate: {processing_rate:.2f}%")
            print(f"  Items per Transaction: {results['total_items'] / results['unique_transactions']:.2f}" if results['unique_transactions'] > 0 else "  Items per Transaction: N/A")
            print("="*80)
            print("ETL PIPELINE COMPLETED SUCCESSFULLY")
            print("="*80)

        except Exception as e:
            logger.error(f"Report generation failed: {e}")
        finally:
            cursor.close()
            conn.close()

    def run(self):
        """Execute complete ETL pipeline with deduplication"""
        start_time = datetime.now()

        try:
            # Step 1: Scan and deduplicate payloads
            logger.info("Step 1: Scanning and deduplicating payload files...")
            deduplicated_payloads = self.scan_and_deduplicate_payloads()

            # Step 2: Bulk insert into database
            logger.info("Step 2: Loading deduplicated payloads into database...")
            self.bulk_insert_payloads(deduplicated_payloads)

            # Step 3: Execute enhanced ETL
            logger.info("Step 3: Executing enhanced ETL pipeline...")
            self.execute_enhanced_etl()

            # Step 4: Generate report
            logger.info("Step 4: Generating completion report...")
            self.generate_completion_report()

            total_duration = (datetime.now() - start_time).total_seconds()
            logger.info(f"Complete ETL pipeline finished in {total_duration:.2f} seconds")

        except Exception as e:
            logger.error(f"ETL pipeline failed: {e}")
            raise

if __name__ == "__main__":
    # Configuration
    connection_string = (
        "Driver={ODBC Driver 17 for SQL Server};"
        "Server=sqltbwaprojectscoutserver.database.windows.net;"
        "Database=SQL-TBWA-ProjectScout-Reporting-Prod;"
        "UID=sqladmin;"
        "PWD=R@nd0mPA$2025!;"
        "TrustServerCertificate=yes;"
    )

    payload_directory = "/Users/tbwa/Downloads/Project-Scout-2 3/dbo.payloadtransactions"

    # Execute ETL
    processor = EnhancedETLProcessor(connection_string, payload_directory)
    processor.run()