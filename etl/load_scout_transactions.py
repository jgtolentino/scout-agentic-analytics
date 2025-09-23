#!/usr/bin/env python3
"""
Scout Edge Transaction ETL Pipeline
Loads transactions_flat_no_ts.csv with NCR location enrichment and substitution detection
"""

import csv
import json
import uuid
import hashlib
import psycopg2
import psycopg2.extras
from datetime import datetime, timezone
from decimal import Decimal
import logging
import sys
import os
from typing import Dict, List, Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ScoutTransactionETL:
    def __init__(self, db_url: str):
        """Initialize ETL pipeline with database connection"""
        self.db_url = db_url
        self.conn = None
        self.cursor = None
        self.processed_count = 0
        self.error_count = 0
        self.substitution_count = 0

    def connect_db(self):
        """Establish database connection"""
        try:
            self.conn = psycopg2.connect(self.db_url)
            self.cursor = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            logger.info("Database connection established")
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            sys.exit(1)

    def close_db(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()

    def generate_canonical_tx_id(self, store_id: str, timestamp: str, amount: float, device_id: str) -> str:
        """Generate deterministic UUID for transaction deduplication"""
        # Use current timestamp if none provided
        if not timestamp:
            timestamp = datetime.now(timezone.utc).isoformat()

        # Create hash from key components
        hash_input = f"{store_id}|{timestamp}|{amount}|{device_id}"
        hash_md5 = hashlib.md5(hash_input.encode()).hexdigest()

        # Convert MD5 hash to UUID format
        return str(uuid.UUID(hash_md5))

    def detect_substitution(self, transcript: str, purchased_brands: List[str]) -> Tuple[bool, str, float]:
        """
        Detect if customer requested different brands than purchased
        Returns: (is_substitution, reason, confidence_score)
        """
        if not transcript or not purchased_brands:
            return False, None, 0.0

        transcript_lower = transcript.lower().strip()

        # Check if any purchased brand appears in transcript
        brand_mentioned = False
        for brand in purchased_brands:
            if brand and brand.lower() in transcript_lower:
                brand_mentioned = True
                break

        if len(transcript_lower) > 0 and not brand_mentioned:
            # Calculate confidence based on transcript complexity
            if len(transcript_lower) > 50:
                score = 0.9
            elif len(transcript_lower) > 20:
                score = 0.7
            else:
                score = 0.5

            return True, "Brand not mentioned in transcript", score

        return False, None, 0.0

    def get_store_location(self, store_id: int) -> Dict:
        """Get NCR location data for store"""
        # Default NCR mappings based on known stores
        ncr_stores = {
            102: {'municipality': 'Manila', 'barangay': None},
            103: {'municipality': 'Quezon City', 'barangay': None},
            104: {'municipality': 'Makati', 'barangay': None},
            108: {'municipality': 'Pasig', 'barangay': None},
            109: {'municipality': 'Mandaluyong', 'barangay': None},
            110: {'municipality': 'Parañaque', 'barangay': None},
            112: {'municipality': 'Taguig', 'barangay': None}
        }

        store_data = ncr_stores.get(store_id, {'municipality': None, 'barangay': None})
        return {
            'region': 'NCR',
            'province_name': 'Metro Manila',
            'municipality_name': store_data['municipality'],
            'barangay_name': store_data['barangay'],
            'geo_latitude': None,
            'geo_longitude': None
        }

    def process_transaction(self, row: Dict) -> Optional[Dict]:
        """Process single transaction row"""
        try:
            # Parse JSON payload
            payload = json.loads(row['payload_json'])

            # Extract core transaction data
            transaction_id = payload.get('transactionId')
            device_id = payload.get('deviceId')
            store_id = int(payload.get('storeId'))

            # Generate canonical ID
            totals = payload.get('totals', {})
            total_amount = totals.get('totalAmount', 0)
            canonical_tx_id = self.generate_canonical_tx_id(
                str(store_id),
                payload.get('timestamp', ''),
                total_amount,
                device_id
            )

            # Get location data
            location = self.get_store_location(store_id)

            # Extract audio context
            context = payload.get('transactionContext', {})
            transcript = context.get('audioTranscript', '')

            # Extract purchased brands
            items = payload.get('items', [])
            purchased_brands = [item.get('brandName') for item in items if item.get('brandName')]

            # Detect substitution
            is_substitution, sub_reason, sub_score = self.detect_substitution(transcript, purchased_brands)
            if is_substitution:
                self.substitution_count += 1

            # Extract privacy settings
            privacy = payload.get('privacy', {})

            # Build main transaction record
            tx_record = {
                'canonical_tx_id': canonical_tx_id,
                'transaction_id': transaction_id,
                'device_id': device_id,
                'store_id': store_id,

                # Location
                'region': location['region'],
                'province_name': location['province_name'],
                'municipality_name': location['municipality_name'],
                'barangay_name': location['barangay_name'],
                'geo_latitude': location['geo_latitude'],
                'geo_longitude': location['geo_longitude'],

                # Transaction totals
                'total_amount': Decimal(str(total_amount)),
                'total_items': totals.get('totalItems', 0),
                'branded_amount': Decimal(str(totals.get('brandedAmount', 0))),
                'unbranded_amount': Decimal(str(totals.get('unbrandedAmount', 0))),
                'branded_count': totals.get('brandedCount', 0),
                'unbranded_count': totals.get('unbrandedCount', 0),
                'unique_brands_count': totals.get('uniqueBrandsCount', 0),

                # Audio & context
                'audio_transcript': transcript,
                'processing_duration': payload.get('processingTime'),
                'payment_method': context.get('paymentMethod'),
                'time_of_day': context.get('timeOfDay'),
                'day_type': context.get('dayType'),

                # Substitution analysis
                'substitution_detected': is_substitution,
                'substitution_reason': sub_reason,
                'requested_brands': json.dumps([]) if not transcript else json.dumps([transcript]),
                'purchased_brands': json.dumps(purchased_brands),
                'brand_switching_score': Decimal(str(sub_score)) if sub_score else None,

                # Privacy
                'audio_stored': privacy.get('audioStored', False),
                'facial_recognition': privacy.get('noFacialRecognition', True) == False,
                'anonymization_level': privacy.get('anonymizationLevel', 'high'),
                'data_retention_days': privacy.get('dataRetentionDays', 30),
                'consent_timestamp': privacy.get('consentTimestamp'),

                # Technical
                'edge_version': payload.get('edgeVersion'),
                'processing_methods': context.get('processingMethods', []),
                'source_file_path': row.get('source_path'),

                # Items for separate table
                'items': items
            }

            return tx_record

        except Exception as e:
            logger.error(f"Error processing transaction {row.get('transactionId', 'unknown')}: {e}")
            self.error_count += 1
            return None

    def insert_transaction(self, tx_record: Dict):
        """Insert transaction and items into database"""
        try:
            # Insert main transaction
            tx_insert_sql = """
                INSERT INTO fact_transactions_location (
                    canonical_tx_id, transaction_id, device_id, store_id,
                    region, province_name, municipality_name, barangay_name,
                    geo_latitude, geo_longitude,
                    total_amount, total_items, branded_amount, unbranded_amount,
                    branded_count, unbranded_count, unique_brands_count,
                    audio_transcript, processing_duration, payment_method,
                    time_of_day, day_type,
                    substitution_detected, substitution_reason, requested_brands,
                    purchased_brands, brand_switching_score,
                    audio_stored, facial_recognition, anonymization_level,
                    data_retention_days, consent_timestamp,
                    edge_version, processing_methods, source_file_path
                ) VALUES (
                    %(canonical_tx_id)s, %(transaction_id)s, %(device_id)s, %(store_id)s,
                    %(region)s, %(province_name)s, %(municipality_name)s, %(barangay_name)s,
                    %(geo_latitude)s, %(geo_longitude)s,
                    %(total_amount)s, %(total_items)s, %(branded_amount)s, %(unbranded_amount)s,
                    %(branded_count)s, %(unbranded_count)s, %(unique_brands_count)s,
                    %(audio_transcript)s, %(processing_duration)s, %(payment_method)s,
                    %(time_of_day)s, %(day_type)s,
                    %(substitution_detected)s, %(substitution_reason)s, %(requested_brands)s,
                    %(purchased_brands)s, %(brand_switching_score)s,
                    %(audio_stored)s, %(facial_recognition)s, %(anonymization_level)s,
                    %(data_retention_days)s, %(consent_timestamp)s,
                    %(edge_version)s, %(processing_methods)s, %(source_file_path)s
                )
                ON CONFLICT (canonical_tx_id) DO NOTHING
            """

            self.cursor.execute(tx_insert_sql, tx_record)

            # Insert items
            for item in tx_record['items']:
                customer_request = item.get('customerRequest', {})

                item_insert_sql = """
                    INSERT INTO fact_transaction_items (
                        canonical_tx_id, brand_name, product_name, generic_name,
                        local_name, sku, quantity, unit, unit_price, total_price,
                        category, subcategory, is_unbranded, is_bulk,
                        detection_method, confidence, brand_confidence, suggested_brands,
                        customer_request_type, specific_brand_requested,
                        pointed_to_product, accepted_suggestion, notes
                    ) VALUES (
                        %(canonical_tx_id)s, %(brand_name)s, %(product_name)s, %(generic_name)s,
                        %(local_name)s, %(sku)s, %(quantity)s, %(unit)s, %(unit_price)s, %(total_price)s,
                        %(category)s, %(subcategory)s, %(is_unbranded)s, %(is_bulk)s,
                        %(detection_method)s, %(confidence)s, %(brand_confidence)s, %(suggested_brands)s,
                        %(customer_request_type)s, %(specific_brand_requested)s,
                        %(pointed_to_product)s, %(accepted_suggestion)s, %(notes)s
                    )
                """

                item_data = {
                    'canonical_tx_id': tx_record['canonical_tx_id'],
                    'brand_name': item.get('brandName'),
                    'product_name': item.get('productName'),
                    'generic_name': item.get('genericName'),
                    'local_name': item.get('localName'),
                    'sku': item.get('sku'),
                    'quantity': item.get('quantity', 1),
                    'unit': item.get('unit', 'pc'),
                    'unit_price': Decimal(str(item.get('unitPrice', 0))),
                    'total_price': Decimal(str(item.get('totalPrice', 0))),
                    'category': item.get('category'),
                    'subcategory': item.get('subcategory'),
                    'is_unbranded': item.get('isUnbranded', False),
                    'is_bulk': item.get('isBulk', False),
                    'detection_method': item.get('detectionMethod'),
                    'confidence': Decimal(str(item.get('confidence', 0))) if item.get('confidence') else None,
                    'brand_confidence': Decimal(str(item.get('brandConfidence', 0))) if item.get('brandConfidence') else None,
                    'suggested_brands': json.dumps(item.get('suggestedBrands')) if item.get('suggestedBrands') else None,
                    'customer_request_type': customer_request.get('requestType'),
                    'specific_brand_requested': customer_request.get('specificBrand', False),
                    'pointed_to_product': customer_request.get('pointedToProduct', False),
                    'accepted_suggestion': customer_request.get('acceptedSuggestion', False),
                    'notes': item.get('notes')
                }

                self.cursor.execute(item_insert_sql, item_data)

            self.processed_count += 1

        except Exception as e:
            logger.error(f"Error inserting transaction {tx_record.get('transaction_id')}: {e}")
            self.error_count += 1

    def load_csv_file(self, csv_file_path: str):
        """Load transactions from CSV file"""
        logger.info(f"Loading transactions from {csv_file_path}")

        try:
            with open(csv_file_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)

                batch_size = 100
                batch_count = 0

                for row in reader:
                    tx_record = self.process_transaction(row)

                    if tx_record:
                        self.insert_transaction(tx_record)

                        batch_count += 1
                        if batch_count % batch_size == 0:
                            self.conn.commit()
                            logger.info(f"Processed {batch_count} transactions, {self.substitution_count} substitutions detected")

                # Commit final batch
                self.conn.commit()

        except Exception as e:
            logger.error(f"Error loading CSV file: {e}")
            if self.conn:
                self.conn.rollback()

    def print_summary(self):
        """Print ETL summary statistics"""
        logger.info("=" * 50)
        logger.info("ETL SUMMARY")
        logger.info("=" * 50)
        logger.info(f"Transactions processed: {self.processed_count}")
        logger.info(f"Substitutions detected: {self.substitution_count}")
        logger.info(f"Substitution rate: {(self.substitution_count/self.processed_count*100):.1f}%")
        logger.info(f"Errors encountered: {self.error_count}")
        logger.info("=" * 50)

def main():
    """Main ETL execution"""
    if len(sys.argv) != 3:
        print("Usage: python load_scout_transactions.py <csv_file_path> <database_url>")
        print("Example: python load_scout_transactions.py /path/to/transactions.csv postgresql://user:pass@host/db")
        sys.exit(1)

    csv_file_path = sys.argv[1]
    database_url = sys.argv[2]

    if not os.path.exists(csv_file_path):
        logger.error(f"CSV file not found: {csv_file_path}")
        sys.exit(1)

    # Initialize ETL pipeline
    etl = ScoutTransactionETL(database_url)

    try:
        etl.connect_db()
        etl.load_csv_file(csv_file_path)
        etl.print_summary()

    finally:
        etl.close_db()

if __name__ == "__main__":
    main()