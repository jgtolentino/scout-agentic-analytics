#!/usr/bin/env python3
"""
Complete Scout Edge Dataset Processor
Processes all 13,289 JSON files from Project-Scout-2 for pipeline ingestion
"""

import json
import os
import sys
import glob
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import uuid
import hashlib
from collections import defaultdict, Counter
import concurrent.futures
from pathlib import Path

def analyze_json_file(file_path: str) -> Optional[Dict]:
    """Analyze a single Scout Edge JSON file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Extract key metrics
        analysis = {
            'file_path': file_path,
            'file_name': os.path.basename(file_path),
            'file_size': os.path.getsize(file_path),
            'file_hash': hashlib.md5(open(file_path, 'rb').read()).hexdigest(),
            
            # Core transaction data
            'transaction_id': data.get('transactionId'),
            'store_id': data.get('storeId'),
            'device_id': data.get('deviceId'),
            'timestamp': data.get('transactionTimestamp'),
            'edge_version': data.get('edgeVersion'),
            
            # Items and financial data
            'items_count': len(data.get('items', [])),
            'total_amount': data.get('totals', {}).get('totalAmount', 0),
            'currency': data.get('totals', {}).get('currency', 'PHP'),
            
            # Brand detection
            'detected_brands': list(data.get('brandDetection', {}).get('detectedBrands', {}).keys()),
            'brands_count': len(data.get('brandDetection', {}).get('detectedBrands', {})),
            'brand_confidence': data.get('brandDetection', {}).get('confidence', 0),
            
            # Context and privacy
            'has_audio_transcript': bool(data.get('transactionContext', {}).get('audioTranscript')),
            'processing_methods': data.get('transactionContext', {}).get('processingMethods', []),
            'audio_stored': data.get('privacy', {}).get('audioStored', False),
            'pii_detected': data.get('privacy', {}).get('piiDetected', False),
            
            # Data quality indicators
            'has_required_fields': all(k in data for k in ['transactionId', 'storeId', 'deviceId', 'items', 'totals']),
            'data_completeness': len([k for k in ['transactionId', 'storeId', 'deviceId', 'items', 'totals', 'brandDetection'] if k in data]) / 6,
            
            # Raw data for reference
            'raw_data': data
        }
        
        return analysis
        
    except Exception as e:
        return {
            'file_path': file_path,
            'file_name': os.path.basename(file_path),
            'error': str(e),
            'file_size': 0,
            'processing_failed': True
        }

def process_scout_dataset(base_path: str = "/Users/tbwa/Downloads/Project-Scout-2") -> Dict:
    """Process the complete Scout Edge dataset"""
    
    print(f"🔍 Scanning Scout Edge dataset at: {base_path}")
    
    # Find all JSON files
    json_pattern = os.path.join(base_path, "**/*.json")
    json_files = glob.glob(json_pattern, recursive=True)
    
    print(f"📊 Found {len(json_files)} JSON files")
    
    if len(json_files) == 0:
        print("❌ No JSON files found. Checking directory structure...")
        if os.path.exists(base_path):
            print(f"Directory exists. Contents:")
            for item in os.listdir(base_path)[:10]:  # Show first 10 items
                print(f"  - {item}")
        return {"error": "No JSON files found"}
    
    # Process files in parallel
    print(f"⚡ Processing {len(json_files)} files with parallel processing...")
    
    results = []
    failed_files = []
    
    # Use ThreadPoolExecutor for I/O bound operations
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        # Submit all files for processing
        future_to_file = {executor.submit(analyze_json_file, file_path): file_path 
                         for file_path in json_files}
        
        # Collect results as they complete
        for i, future in enumerate(concurrent.futures.as_completed(future_to_file)):
            file_path = future_to_file[future]
            try:
                result = future.result()
                if result.get('processing_failed'):
                    failed_files.append(result)
                else:
                    results.append(result)
                
                # Progress indicator
                if (i + 1) % 1000 == 0:
                    print(f"  Processed {i + 1:,}/{len(json_files):,} files...")
                    
            except Exception as e:
                failed_files.append({
                    'file_path': file_path,
                    'error': str(e),
                    'processing_failed': True
                })
    
    print(f"✅ Processing complete: {len(results):,} successful, {len(failed_files):,} failed")
    
    return {
        'total_files': len(json_files),
        'successful_files': len(results),
        'failed_files': len(failed_files),
        'results': results,
        'failed': failed_files
    }

def generate_dataset_analytics(processing_results: Dict) -> Dict:
    """Generate comprehensive analytics from the processed dataset"""
    
    results = processing_results.get('results', [])
    
    if not results:
        return {"error": "No valid results to analyze"}
    
    print(f"📈 Generating analytics for {len(results):,} transactions...")
    
    # Basic statistics
    devices = Counter(r.get('device_id') for r in results if r.get('device_id'))
    stores = Counter(r.get('store_id') for r in results if r.get('store_id'))
    currencies = Counter(r.get('currency') for r in results if r.get('currency'))
    
    # Financial analytics
    amounts = [r.get('total_amount', 0) for r in results if isinstance(r.get('total_amount'), (int, float))]
    item_counts = [r.get('items_count', 0) for r in results if isinstance(r.get('items_count'), int)]
    
    # Brand analytics
    all_brands = []
    for r in results:
        all_brands.extend(r.get('detected_brands', []))
    brand_frequency = Counter(all_brands)
    
    # Quality analytics
    completeness_scores = [r.get('data_completeness', 0) for r in results if r.get('data_completeness')]
    files_with_audio = sum(1 for r in results if r.get('has_audio_transcript'))
    files_with_brands = sum(1 for r in results if r.get('brands_count', 0) > 0)
    
    # Privacy compliance
    audio_stored_count = sum(1 for r in results if r.get('audio_stored'))
    pii_detected_count = sum(1 for r in results if r.get('pii_detected'))
    
    # Temporal analysis
    timestamps = []
    for r in results:
        ts = r.get('timestamp')
        if ts and isinstance(ts, (int, float)):
            try:
                # Convert from milliseconds to datetime
                if ts > 1e12:  # Likely milliseconds
                    timestamps.append(datetime.fromtimestamp(ts / 1000))
                else:  # Likely seconds
                    timestamps.append(datetime.fromtimestamp(ts))
            except:
                pass
    
    analytics = {
        'dataset_summary': {
            'total_transactions': len(results),
            'total_file_size_mb': sum(r.get('file_size', 0) for r in results) / 1024 / 1024,
            'date_range': {
                'earliest': min(timestamps).isoformat() if timestamps else None,
                'latest': max(timestamps).isoformat() if timestamps else None,
                'span_days': (max(timestamps) - min(timestamps)).days if len(timestamps) > 1 else 0
            }
        },
        
        'device_analytics': {
            'unique_devices': len(devices),
            'device_distribution': dict(devices.most_common(10)),
            'transactions_per_device': {
                'mean': len(results) / len(devices) if devices else 0,
                'max': max(devices.values()) if devices else 0,
                'min': min(devices.values()) if devices else 0
            }
        },
        
        'store_analytics': {
            'unique_stores': len(stores),
            'store_distribution': dict(stores.most_common(10)),
            'transactions_per_store': {
                'mean': len(results) / len(stores) if stores else 0,
                'max': max(stores.values()) if stores else 0,
                'min': min(stores.values()) if stores else 0
            }
        },
        
        'financial_analytics': {
            'currency_distribution': dict(currencies),
            'transaction_amounts': {
                'mean': sum(amounts) / len(amounts) if amounts else 0,
                'median': sorted(amounts)[len(amounts)//2] if amounts else 0,
                'max': max(amounts) if amounts else 0,
                'min': min(amounts) if amounts else 0,
                'total_revenue': sum(amounts)
            },
            'basket_analytics': {
                'mean_items': sum(item_counts) / len(item_counts) if item_counts else 0,
                'max_items': max(item_counts) if item_counts else 0,
                'min_items': min(item_counts) if item_counts else 0
            }
        },
        
        'brand_analytics': {
            'unique_brands': len(brand_frequency),
            'total_brand_detections': len(all_brands),
            'top_brands': dict(brand_frequency.most_common(20)),
            'transactions_with_brands': files_with_brands,
            'brand_detection_rate': files_with_brands / len(results) if results else 0
        },
        
        'quality_analytics': {
            'mean_completeness': sum(completeness_scores) / len(completeness_scores) if completeness_scores else 0,
            'transactions_with_audio': files_with_audio,
            'audio_transcript_rate': files_with_audio / len(results) if results else 0,
            'high_quality_transactions': sum(1 for s in completeness_scores if s >= 0.8),
            'quality_distribution': {
                'excellent': sum(1 for s in completeness_scores if s >= 0.9),
                'good': sum(1 for s in completeness_scores if 0.7 <= s < 0.9),
                'fair': sum(1 for s in completeness_scores if 0.5 <= s < 0.7),
                'poor': sum(1 for s in completeness_scores if s < 0.5)
            }
        },
        
        'privacy_compliance': {
            'audio_stored_count': audio_stored_count,
            'pii_detected_count': pii_detected_count,
            'privacy_compliant_rate': (len(results) - audio_stored_count - pii_detected_count) / len(results) if results else 0
        }
    }
    
    return analytics

def save_processed_dataset(results: List[Dict], analytics: Dict, output_dir: str = "/tmp/scout_full_dataset"):
    """Save the processed dataset and analytics"""
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    print(f"💾 Saving processed dataset to {output_dir}")
    
    # Save analytics summary
    analytics_file = os.path.join(output_dir, "dataset_analytics.json")
    with open(analytics_file, 'w') as f:
        json.dump(analytics, f, indent=2, default=str)
    
    # Save processed results (metadata only, not raw data)
    metadata_results = []
    for r in results:
        metadata = {k: v for k, v in r.items() if k != 'raw_data'}
        metadata_results.append(metadata)
    
    metadata_file = os.path.join(output_dir, "transaction_metadata.json")
    with open(metadata_file, 'w') as f:
        json.dump(metadata_results, f, indent=2)
    
    # Create bucket-ready file list
    bucket_files = []
    for i, r in enumerate(results):
        bucket_files.append({
            'id': str(uuid.uuid4()),
            'bucket_name': 'scout-ingest',
            'file_path': f"edge-transactions/{r['file_name']}",
            'file_name': r['file_name'],
            'file_size': r['file_size'],
            'file_hash': r['file_hash'],
            'source_type': 'google_drive',
            'source_id': '1j3CGrL1r_jX_K21mstrSh8lrLNzDnpiA',
            'processing_status': 'pending',
            'validation_status': 'valid' if r.get('has_required_fields') else 'invalid',
            'quality_score': r.get('data_completeness', 0),
            'scout_metadata': {
                'transaction_id': r.get('transaction_id'),
                'store_id': r.get('store_id'),
                'device_id': r.get('device_id'),
                'items_count': r.get('items_count'),
                'brands_count': r.get('brands_count'),
                'total_amount': r.get('total_amount'),
                'has_brand_detection': r.get('brands_count', 0) > 0,
                'has_audio_transcript': r.get('has_audio_transcript'),
                'edge_version': r.get('edge_version'),
                'privacy_compliant': not r.get('audio_stored', False) and not r.get('pii_detected', False)
            },
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        })
    
    bucket_file = os.path.join(output_dir, "bucket_files_manifest.json")
    with open(bucket_file, 'w') as f:
        json.dump(bucket_files, f, indent=2)
    
    # Create device-specific summaries
    device_summaries = defaultdict(list)
    for r in results:
        device_id = r.get('device_id')
        if device_id:
            device_summaries[device_id].append(r['file_name'])
    
    device_file = os.path.join(output_dir, "device_file_mapping.json")
    with open(device_file, 'w') as f:
        json.dump(dict(device_summaries), f, indent=2)
    
    return {
        'analytics_file': analytics_file,
        'metadata_file': metadata_file,
        'bucket_file': bucket_file,
        'device_file': device_file,
        'output_directory': output_dir
    }

def main():
    """Main execution function"""
    
    print("=" * 80)
    print("SCOUT EDGE COMPLETE DATASET PROCESSOR")
    print("Processing 13,289 JSON files from Project-Scout-2")
    print("=" * 80)
    
    # Check if source directory exists
    source_dir = "/Users/tbwa/Downloads/Project-Scout-2"
    if not os.path.exists(source_dir):
        print(f"❌ Source directory not found: {source_dir}")
        # Try alternative locations
        alt_locations = [
            "/Users/tbwa/Downloads/Project-Scout-2",
            "/Users/tbwa/scout-v7/data/Project-Scout-2",
            "/tmp/Project-Scout-2"
        ]
        
        for alt_path in alt_locations:
            if os.path.exists(alt_path):
                source_dir = alt_path
                print(f"✅ Found alternative location: {source_dir}")
                break
        else:
            print("❌ Could not find Project-Scout-2 directory in any expected location")
            return
    
    # Process the complete dataset
    start_time = datetime.now()
    print(f"🚀 Starting processing at {start_time}")
    
    processing_results = process_scout_dataset(source_dir)
    
    if 'error' in processing_results:
        print(f"❌ Processing failed: {processing_results['error']}")
        return
    
    # Generate analytics
    analytics = generate_dataset_analytics(processing_results)
    
    if 'error' in analytics:
        print(f"❌ Analytics generation failed: {analytics['error']}")
        return
    
    # Save results
    saved_files = save_processed_dataset(
        processing_results['results'], 
        analytics
    )
    
    end_time = datetime.now()
    processing_duration = end_time - start_time
    
    # Display summary
    print("\n" + "=" * 80)
    print("PROCESSING COMPLETE - DATASET SUMMARY")
    print("=" * 80)
    
    print(f"⏱️  Processing Time: {processing_duration}")
    print(f"📊 Total Files Processed: {processing_results['total_files']:,}")
    print(f"✅ Successful: {processing_results['successful_files']:,}")
    print(f"❌ Failed: {processing_results['failed_files']:,}")
    
    ds = analytics.get('dataset_summary', {})
    print(f"\n📈 Dataset Overview:")
    print(f"   Total Transactions: {ds.get('total_transactions', 0):,}")
    print(f"   Total Data Size: {ds.get('total_file_size_mb', 0):.1f} MB")
    print(f"   Date Range: {ds.get('date_range', {}).get('span_days', 0)} days")
    
    da = analytics.get('device_analytics', {})
    print(f"\n🤖 Device Analytics:")
    print(f"   Unique Devices: {da.get('unique_devices', 0)}")
    print(f"   Avg Transactions/Device: {da.get('transactions_per_device', {}).get('mean', 0):.1f}")
    
    ba = analytics.get('brand_analytics', {})
    print(f"\n🏷️  Brand Analytics:")
    print(f"   Unique Brands: {ba.get('unique_brands', 0)}")
    print(f"   Total Brand Detections: {ba.get('total_brand_detections', 0):,}")
    print(f"   Brand Detection Rate: {ba.get('brand_detection_rate', 0)*100:.1f}%")
    
    fa = analytics.get('financial_analytics', {})
    print(f"\n💰 Financial Analytics:")
    print(f"   Total Revenue: ₱{fa.get('transaction_amounts', {}).get('total_revenue', 0):,.2f}")
    print(f"   Avg Transaction: ₱{fa.get('transaction_amounts', {}).get('mean', 0):.2f}")
    
    qa = analytics.get('quality_analytics', {})
    print(f"\n🎯 Quality Analytics:")
    print(f"   Mean Completeness: {qa.get('mean_completeness', 0)*100:.1f}%")
    print(f"   High Quality Transactions: {qa.get('high_quality_transactions', 0):,}")
    print(f"   Audio Transcript Rate: {qa.get('audio_transcript_rate', 0)*100:.1f}%")
    
    print(f"\n📁 Output Files:")
    for key, filepath in saved_files.items():
        if key != 'output_directory':
            print(f"   {key}: {filepath}")
    
    print(f"\n🎯 Ready for Pipeline:")
    print(f"   ✅ {processing_results['successful_files']:,} transactions ready for bucket ingestion")
    print(f"   ✅ Metadata and analytics generated")
    print(f"   ✅ Device mapping and file manifest created")
    print(f"   ✅ Quality scores and validation status assigned")
    
    print(f"\n📋 Next Steps:")
    print(f"   1. Upload bucket_files_manifest.json to create bucket storage records")
    print(f"   2. Execute drive-to-bucket sync for actual file transfer")
    print(f"   3. Run bucket-to-bronze processing workflow")
    print(f"   4. Execute dbt models for Silver and Gold analytics")
    
    print("\n" + "=" * 80)

if __name__ == "__main__":
    main()