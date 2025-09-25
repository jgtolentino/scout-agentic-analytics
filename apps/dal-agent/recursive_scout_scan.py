#!/usr/bin/env python3
"""
Recursive Scout Data Scan - Full analysis of Scout payload transaction data
Creates comprehensive data model and ETL design for granular transaction item details
"""

import os
import json
import pandas as pd
from pathlib import Path
import re
from collections import defaultdict, Counter
from datetime import datetime
import hashlib

def recursive_scout_scan():
    """Perform full recursive scan of Scout payload data"""

    base_path = Path("/Users/tbwa/Downloads/Project-Scout-2 3/dbo.payloadtransactions")

    print("🔍 SCOUT PAYLOAD TRANSACTION DATA - COMPREHENSIVE ANALYSIS")
    print("=" * 80)

    if not base_path.exists():
        print(f"❌ Path not found: {base_path}")
        return None

    # Initialize analysis structures
    device_summary = {}
    schema_analysis = defaultdict(Counter)
    item_details = []
    brand_analysis = defaultdict(Counter)
    transaction_patterns = []
    file_analysis = []

    total_files = 0
    total_transactions = 0
    error_files = 0

    print(f"\n📂 Scanning: {base_path}")
    print(f"📊 Device directories found: {len([d for d in base_path.iterdir() if d.is_dir() and not d.name.startswith('.')])}")

    # Scan each device directory
    for device_dir in sorted(base_path.iterdir()):
        if device_dir.is_dir() and not device_dir.name.startswith('.'):
            device_name = device_dir.name
            print(f"\n🔍 Scanning device: {device_name}")

            device_files = list(device_dir.glob('*.json'))
            device_summary[device_name] = {
                'total_files': len(device_files),
                'transactions': 0,
                'items': 0,
                'brands': set(),
                'stores': set(),
                'date_range': {'min': None, 'max': None},
                'file_size_total': 0
            }

            # Sample files for deep analysis
            sample_count = min(50, len(device_files))  # Sample first 50 files
            sample_files = device_files[:sample_count]

            for file_path in sample_files:
                total_files += 1

                try:
                    # File metadata
                    file_stat = file_path.stat()
                    device_summary[device_name]['file_size_total'] += file_stat.st_size

                    # Parse JSON
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)

                    # Extract transaction metadata
                    transaction_id = data.get('transactionId', 'unknown')
                    store_id = data.get('storeId', 'unknown')
                    device_id = data.get('deviceId', 'unknown')
                    timestamp = data.get('timestamp', '')

                    device_summary[device_name]['stores'].add(store_id)
                    total_transactions += 1
                    device_summary[device_name]['transactions'] += 1

                    # Analyze JSON structure
                    def analyze_json_structure(obj, prefix=""):
                        if isinstance(obj, dict):
                            for key, value in obj.items():
                                full_key = f"{prefix}.{key}" if prefix else key
                                schema_analysis['field_types'][full_key] += type(value).__name__
                                schema_analysis['field_presence'][full_key] += 1

                                if isinstance(value, (dict, list)):
                                    analyze_json_structure(value, full_key)
                        elif isinstance(obj, list):
                            schema_analysis['array_sizes'][prefix] += len(obj)
                            if obj:  # Analyze first item if array not empty
                                analyze_json_structure(obj[0], f"{prefix}[0]")

                    analyze_json_structure(data)

                    # Extract items details
                    items = data.get('items', [])
                    device_summary[device_name]['items'] += len(items)

                    for item in items:
                        item_detail = {
                            'transaction_id': transaction_id,
                            'device_id': device_id,
                            'store_id': store_id,
                            'timestamp': timestamp,
                            'file_path': str(file_path),
                            **item  # Spread all item properties
                        }
                        item_details.append(item_detail)

                    # Brand detection analysis
                    brand_detection = data.get('brandDetection', {})
                    detected_brands = brand_detection.get('detectedBrands', {})
                    explicit_mentions = brand_detection.get('explicitMentions', [])
                    implicit_signals = brand_detection.get('implicitSignals', [])

                    for brand in detected_brands.keys():
                        device_summary[device_name]['brands'].add(brand)
                        brand_analysis['detected'][brand] += 1

                    for mention in explicit_mentions:
                        brand_analysis['explicit'][mention] += 1

                    for signal in implicit_signals:
                        brand_analysis['implicit'][signal] += 1

                    # Transaction pattern analysis
                    totals = data.get('totals', {})
                    pattern = {
                        'device': device_name,
                        'store_id': store_id,
                        'item_count': len(items),
                        'total_amount': totals.get('totalAmount', 0),
                        'total_units': totals.get('totalUnits', 0),
                        'has_brands': len(detected_brands) > 0,
                        'has_transcription': bool(data.get('transcription', {}).get('text', '')),
                        'timestamp': timestamp
                    }
                    transaction_patterns.append(pattern)

                    # File analysis
                    file_info = {
                        'device': device_name,
                        'filename': file_path.name,
                        'size_bytes': file_stat.st_size,
                        'transaction_id': transaction_id,
                        'item_count': len(items),
                        'brand_count': len(detected_brands),
                        'has_audio': 'audioBuffer' in data,
                        'has_vision': bool(data.get('visionDetection', {}).get('detections', [])),
                        'json_keys': list(data.keys())
                    }
                    file_analysis.append(file_info)

                except Exception as e:
                    error_files += 1
                    print(f"   ❌ Error processing {file_path.name}: {e}")
                    continue

            # Convert sets to counts for summary
            device_summary[device_name]['unique_brands'] = len(device_summary[device_name]['brands'])
            device_summary[device_name]['unique_stores'] = len(device_summary[device_name]['stores'])
            device_summary[device_name]['brands'] = list(device_summary[device_name]['brands'])[:10]  # Top 10
            device_summary[device_name]['stores'] = list(device_summary[device_name]['stores'])

            print(f"   ✅ {device_name}: {device_summary[device_name]['transactions']} transactions, {device_summary[device_name]['items']} items")

    print(f"\n📊 SCAN SUMMARY:")
    print(f"   📁 Total files scanned: {total_files:,}")
    print(f"   🔍 Total transactions: {total_transactions:,}")
    print(f"   ❌ Error files: {error_files}")
    print(f"   📋 Total items extracted: {len(item_details):,}")
    print(f"   🏪 Unique brands detected: {len(brand_analysis['detected'])}")

    # Create comprehensive analysis
    analysis_result = {
        'summary': {
            'total_files': total_files,
            'total_transactions': total_transactions,
            'total_items': len(item_details),
            'error_files': error_files,
            'devices_analyzed': len(device_summary)
        },
        'device_summary': device_summary,
        'schema_analysis': dict(schema_analysis),
        'item_details': item_details,
        'brand_analysis': dict(brand_analysis),
        'transaction_patterns': transaction_patterns,
        'file_analysis': file_analysis
    }

    return analysis_result

def generate_data_model_dbml(analysis_result):
    """Generate DBML data model from analysis"""

    print("\n🏗️ GENERATING DATA MODEL (DBML)...")

    # Extract unique fields from items
    item_fields = defaultdict(set)
    for item in analysis_result['item_details']:
        for key, value in item.items():
            item_fields[key].add(type(value).__name__)

    # Generate DBML
    dbml_content = """// Scout Analytics Platform - Granular Transaction Data Model
// Generated from comprehensive payload analysis

Project scout_analytics {
  database_type: 'Azure SQL'
  Note: '''
    Comprehensive data model for Scout retail analytics platform
    Captures granular transaction item-level details from IoT devices
    Supports AI-powered brand detection and customer behavior analysis
  '''
}

// === CORE TRANSACTION TABLES ===

Table transactions {
  transaction_id varchar(50) [pk, note: 'Unique transaction identifier']
  canonical_tx_id varchar(50) [unique, note: 'Normalized transaction ID']
  session_id varchar(100) [note: 'Session identifier']
  device_id varchar(50) [ref: > devices.device_id, note: 'IoT device reference']
  store_id varchar(50) [ref: > stores.store_id, note: 'Store location reference']
  timestamp datetime [note: 'Transaction timestamp']
  customer_age int [note: 'Detected customer age']
  customer_gender varchar(20) [note: 'Detected customer gender']
  total_amount decimal(10,2) [note: 'Transaction total amount']
  total_units int [note: 'Total units in transaction']
  payment_method varchar(20) [note: 'Payment method used']
  duration_seconds int [note: 'Transaction duration']
  created_at datetime [default: `now()`, note: 'Record creation timestamp']

  indexes {
    (device_id, timestamp) [name: 'idx_device_timestamp']
    (store_id, timestamp) [name: 'idx_store_timestamp']
    timestamp [name: 'idx_timestamp']
  }

  Note: 'Core transaction records from IoT devices'
}

Table transaction_items {
  item_id bigint [pk, increment, note: 'Auto-increment item ID']
  transaction_id varchar(50) [ref: > transactions.transaction_id, note: 'Parent transaction']
  sequence_number int [note: 'Item sequence in transaction']
  product_name varchar(200) [note: 'Product name']
  brand_name varchar(100) [note: 'Brand name']
  category varchar(100) [note: 'Product category']
  sub_category varchar(100) [note: 'Product sub-category']
  sku varchar(100) [note: 'Stock keeping unit']
  barcode varchar(50) [note: 'Product barcode']
  unit_price decimal(10,2) [note: 'Price per unit']
  quantity int [note: 'Quantity purchased']
  total_price decimal(10,2) [note: 'Total item price']
  weight_grams int [note: 'Product weight in grams']
  volume_ml int [note: 'Product volume in milliliters']
  pack_size varchar(50) [note: 'Package size description']
  is_substitution boolean [default: false, note: 'Item is a substitution']
  substitution_reason varchar(100) [note: 'Reason for substitution']
  original_product_id varchar(100) [note: 'Original requested product']
  suggestion_accepted boolean [note: 'AI suggestion was accepted']
  created_at datetime [default: `now()`]

  indexes {
    transaction_id [name: 'idx_transaction_items_txn_id']
    brand_name [name: 'idx_transaction_items_brand']
    category [name: 'idx_transaction_items_category']
  }

  Note: 'Granular item-level transaction details'
}

// === BRAND DETECTION & AI ANALYSIS ===

Table brand_detections {
  detection_id bigint [pk, increment]
  transaction_id varchar(50) [ref: > transactions.transaction_id]
  brand_name varchar(100)
  confidence_score decimal(3,2) [note: 'AI confidence score 0.00-1.00']
  detection_method varchar(50) [note: 'vision|audio|text|barcode']
  detection_timestamp datetime
  bounding_box_coordinates json [note: 'Vision detection coordinates']
  audio_segment_start decimal(5,2) [note: 'Audio segment start time']
  audio_segment_end decimal(5,2) [note: 'Audio segment end time']
  explicit_mention boolean [note: 'Brand explicitly mentioned']
  implicit_signal boolean [note: 'Brand inferred from context']
  created_at datetime [default: `now()`]

  indexes {
    transaction_id [name: 'idx_brand_detections_txn_id']
    brand_name [name: 'idx_brand_detections_brand']
    confidence_score [name: 'idx_brand_detections_confidence']
  }

  Note: 'AI-powered brand detection results'
}

Table audio_transcriptions {
  transcription_id bigint [pk, increment]
  transaction_id varchar(50) [ref: > transactions.transaction_id]
  full_text text [note: 'Complete audio transcription']
  confidence_score decimal(3,2) [note: 'Transcription confidence']
  language_code varchar(10) [note: 'Detected language']
  word_count int [note: 'Number of words']
  duration_seconds decimal(5,2) [note: 'Audio duration']
  sentiment_score decimal(3,2) [note: 'Sentiment analysis score']
  sentiment_label varchar(20) [note: 'positive|negative|neutral']
  key_phrases json [note: 'Extracted key phrases']
  brand_mentions json [note: 'Brand mentions with timestamps']
  created_at datetime [default: `now()`]

  indexes {
    transaction_id [name: 'idx_audio_transcriptions_txn_id']
    sentiment_label [name: 'idx_audio_transcriptions_sentiment']
  }

  Note: 'Audio transcription and sentiment analysis'
}

Table vision_detections {
  detection_id bigint [pk, increment]
  transaction_id varchar(50) [ref: > transactions.transaction_id]
  object_type varchar(100) [note: 'Detected object type']
  confidence_score decimal(3,2)
  bounding_box json [note: 'Detection coordinates']
  object_attributes json [note: 'Additional object properties']
  brand_detected varchar(100) [note: 'Brand detected from object']
  text_extracted varchar(500) [note: 'OCR text extraction']
  image_segment_id varchar(100) [note: 'Image segment identifier']
  detection_timestamp datetime
  created_at datetime [default: `now()`]

  indexes {
    transaction_id [name: 'idx_vision_detections_txn_id']
    object_type [name: 'idx_vision_detections_object']
    brand_detected [name: 'idx_vision_detections_brand']
  }

  Note: 'Computer vision detection results'
}

// === MASTER DATA TABLES ===

Table devices {
  device_id varchar(50) [pk, note: 'IoT device identifier (e.g., SCOUTPI-0002)']
  device_name varchar(100) [note: 'Human-readable device name']
  device_type varchar(50) [note: 'Device type classification']
  store_id varchar(50) [ref: > stores.store_id]
  installation_date date
  status varchar(20) [note: 'active|inactive|maintenance']
  firmware_version varchar(20)
  last_heartbeat datetime [note: 'Last device communication']
  capabilities json [note: 'Device capabilities (audio, vision, etc.)']
  configuration json [note: 'Device configuration parameters']
  created_at datetime [default: `now()`]
  updated_at datetime [default: `now()`]

  indexes {
    store_id [name: 'idx_devices_store_id']
    status [name: 'idx_devices_status']
  }

  Note: 'IoT device master data'
}

Table stores {
  store_id varchar(50) [pk, note: 'Store identifier']
  store_name varchar(200) [note: 'Store display name']
  store_type varchar(50) [note: 'convenience|supermarket|pharmacy|etc']
  region varchar(100)
  province varchar(100)
  city varchar(100)
  barangay varchar(100)
  address text
  latitude decimal(10,6)
  longitude decimal(10,6)
  timezone varchar(50)
  opening_hours json [note: 'Store operating hours']
  contact_info json [note: 'Phone, email, manager details']
  active boolean [default: true]
  created_at datetime [default: `now()`]

  indexes {
    (latitude, longitude) [name: 'idx_stores_location']
    region [name: 'idx_stores_region']
    city [name: 'idx_stores_city']
  }

  Note: 'Store location master data'
}

Table products {
  product_id varchar(100) [pk, note: 'Product identifier']
  sku varchar(100) [unique, note: 'Stock keeping unit']
  product_name varchar(200)
  brand_id varchar(100) [ref: > brands.brand_id]
  category varchar(100)
  sub_category varchar(100)
  barcode varchar(50)
  unit_price decimal(10,2)
  weight_grams int
  volume_ml int
  pack_size varchar(50)
  description text
  ingredients json [note: 'Product ingredients list']
  nutritional_info json [note: 'Nutritional information']
  allergens json [note: 'Allergen information']
  active boolean [default: true]
  created_at datetime [default: `now()`]

  indexes {
    brand_id [name: 'idx_products_brand_id']
    category [name: 'idx_products_category']
    barcode [name: 'idx_products_barcode']
  }

  Note: 'Product master data'
}

Table brands {
  brand_id varchar(100) [pk, note: 'Brand identifier']
  brand_name varchar(200) [unique, note: 'Brand display name']
  parent_company varchar(200) [note: 'Parent company name']
  brand_category varchar(100) [note: 'Brand category classification']
  is_tbwa_client boolean [default: false, note: 'TBWA client brand flag']
  logo_url varchar(500) [note: 'Brand logo URL']
  brand_colors json [note: 'Brand color palette']
  keywords json [note: 'Brand recognition keywords']
  active boolean [default: true]
  created_at datetime [default: `now()`]

  indexes {
    is_tbwa_client [name: 'idx_brands_tbwa_client']
    brand_category [name: 'idx_brands_category']
  }

  Note: 'Brand master data'
}

// === ETL & AUDIT TABLES ===

Table payload_raw {
  payload_id bigint [pk, increment]
  transaction_id varchar(50)
  device_id varchar(50)
  file_path varchar(1000) [note: 'Original blob storage file path']
  file_size_bytes bigint
  file_hash varchar(64) [note: 'SHA-256 hash of original file']
  payload_json text [note: 'Raw JSON payload']
  ingestion_timestamp datetime [default: `now()`]
  processing_status varchar(20) [note: 'pending|processed|error']
  processing_timestamp datetime
  error_message text

  indexes {
    transaction_id [name: 'idx_payload_raw_txn_id']
    device_id [name: 'idx_payload_raw_device_id']
    ingestion_timestamp [name: 'idx_payload_raw_ingestion']
    processing_status [name: 'idx_payload_raw_status']
  }

  Note: 'Raw payload storage for audit and reprocessing'
}

Table etl_audit_log {
  audit_id bigint [pk, increment]
  process_name varchar(100) [note: 'ETL process name']
  source_table varchar(100)
  target_table varchar(100)
  records_processed int
  records_success int
  records_error int
  execution_start datetime
  execution_end datetime
  execution_duration_seconds int
  status varchar(20) [note: 'success|error|warning']
  error_details text
  created_at datetime [default: `now()`]

  indexes {
    process_name [name: 'idx_etl_audit_process']
    execution_start [name: 'idx_etl_audit_start']
    status [name: 'idx_etl_audit_status']
  }

  Note: 'ETL process audit and monitoring'
}

// === ANALYTICAL VIEWS (Documented for reference) ===

Note analytics_views {
  '''
  Key Analytical Views:

  1. v_transaction_summary
     - Aggregated transaction metrics by store, device, time period

  2. v_brand_performance
     - Brand detection rates, confidence scores, transaction correlation

  3. v_customer_behavior
     - Customer demographics, purchasing patterns, interaction duration

  4. v_product_analytics
     - Product performance, category trends, substitution patterns

  5. v_device_health
     - Device uptime, data quality, processing success rates

  6. v_store_performance
     - Store-level metrics, geographic analysis, operational insights
  '''
}
"""

    return dbml_content

def save_analysis_results(analysis_result, dbml_content):
    """Save analysis results and data model"""

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base_dir = "/Users/tbwa/scout-v7/apps/dal-agent"

    # Save comprehensive analysis as JSON
    analysis_file = f"{base_dir}/scout_payload_analysis_{timestamp}.json"
    with open(analysis_file, 'w') as f:
        # Convert sets to lists for JSON serialization
        json_safe_result = json.loads(json.dumps(analysis_result, default=str, indent=2))
        json.dump(json_safe_result, f, indent=2, default=str)

    # Save DBML data model
    dbml_file = f"{base_dir}/scout_data_model_{timestamp}.dbml"
    with open(dbml_file, 'w') as f:
        f.write(dbml_content)

    # Save item details as CSV for further analysis
    if analysis_result['item_details']:
        items_df = pd.DataFrame(analysis_result['item_details'])
        csv_file = f"{base_dir}/scout_item_details_{timestamp}.csv"
        items_df.to_csv(csv_file, index=False)

        print(f"✅ Item details CSV: {csv_file}")

    # Save transaction patterns
    if analysis_result['transaction_patterns']:
        patterns_df = pd.DataFrame(analysis_result['transaction_patterns'])
        patterns_file = f"{base_dir}/scout_transaction_patterns_{timestamp}.csv"
        patterns_df.to_csv(patterns_file, index=False)

        print(f"✅ Transaction patterns CSV: {patterns_file}")

    print(f"✅ Comprehensive analysis: {analysis_file}")
    print(f"✅ DBML data model: {dbml_file}")

    return {
        'analysis_file': analysis_file,
        'dbml_file': dbml_file,
        'items_csv': csv_file if analysis_result['item_details'] else None,
        'patterns_csv': patterns_file if analysis_result['transaction_patterns'] else None
    }

if __name__ == "__main__":
    print("🚀 Starting comprehensive Scout payload analysis...")

    # Perform recursive scan
    analysis_result = recursive_scout_scan()

    if analysis_result:
        # Generate DBML data model
        dbml_content = generate_data_model_dbml(analysis_result)

        # Save all results
        saved_files = save_analysis_results(analysis_result, dbml_content)

        print(f"\n🎉 ANALYSIS COMPLETE!")
        print(f"📊 Files generated: {len(saved_files)} files")

        # Print key insights
        summary = analysis_result['summary']
        print(f"\n📈 KEY INSIGHTS:")
        print(f"   🔍 Devices analyzed: {summary['devices_analyzed']}")
        print(f"   📁 Files processed: {summary['total_files']:,}")
        print(f"   💳 Transactions: {summary['total_transactions']:,}")
        print(f"   📦 Items captured: {summary['total_items']:,}")
        print(f"   ❌ Error rate: {(summary['error_files']/summary['total_files']*100):.1f}%")

    else:
        print("❌ Analysis failed!")