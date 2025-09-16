#!/usr/bin/env python3
"""
Enhanced Brand Detection Processor
Re-processes Scout Edge JSON files with improved brand detection
Measures improvement in brand detection accuracy
"""

import json
import os
import psycopg2
from typing import Dict, List, Any, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
from dataclasses import dataclass

@dataclass
class BrandDetectionImprovement:
    transcript: str
    original_brands: List[str]
    enhanced_brands: List[Dict[str, Any]]
    brands_before: int
    brands_after: int
    improvement_count: int
    confidence_improvement: float

class EnhancedBrandDetectionProcessor:
    def __init__(self):
        self.conn_str = (
            "host=aws-0-ap-southeast-1.pooler.supabase.com "
            "port=6543 "
            "dbname=postgres "
            "user=postgres.cxzllzyxwpyptfretryc "
            "password=Postgres_26"
        )
        self.improvements = []
    
    def connect_db(self):
        """Create database connection"""
        return psycopg2.connect(self.conn_str)
    
    def enhanced_brand_detection(self, audio_transcript: str) -> List[Dict[str, Any]]:
        """Use enhanced brand detection function"""
        with self.connect_db() as conn:
            with conn.cursor() as cur:
                try:
                    cur.execute("""
                        SELECT brand_name, confidence, match_method, matched_phrase 
                        FROM match_brands_enhanced(%s, 0.6)
                        ORDER BY confidence DESC
                    """, (audio_transcript,))
                    
                    results = []
                    for row in cur.fetchall():
                        results.append({
                            'brand': row[0],
                            'confidence': float(row[1]),
                            'detection_type': row[2],
                            'matched_phrase': row[3]
                        })
                    return results
                except Exception as e:
                    print(f"Error in enhanced detection: {e}")
                    return []
    
    def process_scout_edge_file(self, file_path: str) -> BrandDetectionImprovement:
        """Process single Scout Edge JSON file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Extract original data
            transcript = data.get('transactionContext', {}).get('audioTranscript', '')
            if not transcript or transcript.strip() == '':
                return None
            
            original_brands = []
            if 'brandDetection' in data and 'detectedBrands' in data['brandDetection']:
                original_brands = list(data['brandDetection']['detectedBrands'].keys())
            
            # Get enhanced detection
            enhanced_brands = self.enhanced_brand_detection(transcript)
            
            # Calculate improvements
            brands_before = len(original_brands)
            brands_after = len(enhanced_brands)
            improvement_count = max(0, brands_after - brands_before)
            
            # Calculate confidence improvement
            original_confidence = 0.0
            if 'brandDetection' in data and 'detectedBrands' in data['brandDetection']:
                confidences = data['brandDetection']['detectedBrands'].values()
                original_confidence = sum(confidences) / len(confidences) if confidences else 0.0
            
            enhanced_confidence = 0.0
            if enhanced_brands:
                enhanced_confidence = sum(b['confidence'] for b in enhanced_brands) / len(enhanced_brands)
            
            confidence_improvement = enhanced_confidence - original_confidence
            
            return BrandDetectionImprovement(
                transcript=transcript,
                original_brands=original_brands,
                enhanced_brands=enhanced_brands,
                brands_before=brands_before,
                brands_after=brands_after,
                improvement_count=improvement_count,
                confidence_improvement=confidence_improvement
            )
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return None
    
    def process_directory_parallel(self, base_path: str, max_workers: int = 8) -> Dict[str, Any]:
        """Process all Scout Edge files with parallel processing"""
        print(f"🔍 Scanning Scout Edge files in: {base_path}")
        
        json_files = []
        for root, dirs, files in os.walk(base_path):
            for file in files:
                if file.endswith('.json'):
                    json_files.append(os.path.join(root, file))
        
        print(f"📁 Found {len(json_files)} JSON files")
        
        start_time = time.time()
        improvements = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            future_to_file = {
                executor.submit(self.process_scout_edge_file, file_path): file_path 
                for file_path in json_files
            }
            
            processed = 0
            for future in as_completed(future_to_file):
                file_path = future_to_file[future]
                try:
                    improvement = future.result()
                    if improvement is not None:
                        improvements.append(improvement)
                    
                    processed += 1
                    if processed % 1000 == 0:
                        print(f"✅ Processed {processed}/{len(json_files)} files")
                        
                except Exception as e:
                    print(f"❌ Error processing {file_path}: {e}")
        
        processing_time = time.time() - start_time
        
        # Calculate statistics
        total_files = len(json_files)
        successful_improvements = len(improvements)
        total_original_brands = sum(imp.brands_before for imp in improvements)
        total_enhanced_brands = sum(imp.brands_after for imp in improvements)
        total_improvement_count = sum(imp.improvement_count for imp in improvements)
        
        # Files with improvements
        files_with_improvements = len([imp for imp in improvements if imp.improvement_count > 0])
        
        # Average confidence improvement
        avg_confidence_improvement = (
            sum(imp.confidence_improvement for imp in improvements) / len(improvements)
            if improvements else 0.0
        )
        
        # Top improved transcripts
        top_improvements = sorted(
            improvements, 
            key=lambda x: x.improvement_count, 
            reverse=True
        )[:10]
        
        results = {
            'processing_summary': {
                'total_files': total_files,
                'successful_processing': successful_improvements,
                'processing_time_seconds': round(processing_time, 2),
                'files_per_second': round(total_files / processing_time, 2)
            },
            'brand_detection_improvement': {
                'total_original_brands': total_original_brands,
                'total_enhanced_brands': total_enhanced_brands,
                'net_improvement': total_improvement_count,
                'improvement_percentage': round((total_improvement_count / max(1, total_original_brands)) * 100, 2),
                'files_with_improvements': files_with_improvements,
                'improvement_rate': round((files_with_improvements / max(1, successful_improvements)) * 100, 2)
            },
            'confidence_analysis': {
                'average_confidence_improvement': round(avg_confidence_improvement, 3),
                'improved_files_count': len([imp for imp in improvements if imp.confidence_improvement > 0])
            },
            'top_improvements': [
                {
                    'transcript': imp.transcript[:100] + '...' if len(imp.transcript) > 100 else imp.transcript,
                    'brands_before': imp.brands_before,
                    'brands_after': imp.brands_after,
                    'improvement': imp.improvement_count,
                    'enhanced_brands': [b['brand'] for b in imp.enhanced_brands],
                    'confidence_boost': round(imp.confidence_improvement, 3)
                }
                for imp in top_improvements
            ]
        }
        
        self.improvements = improvements
        return results
    
    def save_improvements_to_db(self):
        """Save improvements to database for tracking"""
        if not self.improvements:
            return
        
        with self.connect_db() as conn:
            with conn.cursor() as cur:
                for imp in self.improvements[:100]:  # Save first 100 improvements
                    try:
                        cur.execute("""
                            INSERT INTO metadata.brand_detection_improvements 
                            (audio_transcript, original_brands, enhanced_brands, 
                             brands_before, brands_after, improvement_count, confidence_improvement)
                            VALUES (%s, %s, %s, %s, %s, %s, %s)
                        """, (
                            imp.transcript,
                            json.dumps(imp.original_brands),
                            json.dumps(imp.enhanced_brands),
                            imp.brands_before,
                            imp.brands_after,
                            imp.improvement_count,
                            imp.confidence_improvement
                        ))
                    except Exception as e:
                        print(f"Error saving improvement: {e}")
                
                conn.commit()
                print(f"💾 Saved {min(100, len(self.improvements))} improvements to database")

def main():
    print("=" * 80)
    print("🚀 ENHANCED SCOUT EDGE BRAND DETECTION PROCESSOR")
    print("=" * 80)
    
    processor = EnhancedBrandDetectionProcessor()
    base_path = "/Users/tbwa/Downloads/Project-Scout-2"
    
    print(f"\n📊 Processing Scout Edge dataset with enhanced brand detection...")
    results = processor.process_directory_parallel(base_path, max_workers=8)
    
    print("\n" + "=" * 80)
    print("📈 ENHANCED BRAND DETECTION RESULTS")
    print("=" * 80)
    
    # Processing Summary
    ps = results['processing_summary']
    print(f"\n🔧 Processing Performance:")
    print(f"   Total Files:           {ps['total_files']:,}")
    print(f"   Successfully Processed: {ps['successful_processing']:,}")
    print(f"   Processing Time:       {ps['processing_time_seconds']:.2f}s")
    print(f"   Processing Speed:      {ps['files_per_second']:.1f} files/second")
    
    # Brand Detection Improvement
    bd = results['brand_detection_improvement']
    print(f"\n🎯 Brand Detection Enhancement:")
    print(f"   Original Brands Detected:  {bd['total_original_brands']:,}")
    print(f"   Enhanced Brands Detected:  {bd['total_enhanced_brands']:,}")
    print(f"   Net Brand Improvement:     +{bd['net_improvement']:,} brands")
    print(f"   Improvement Percentage:    +{bd['improvement_percentage']}%")
    print(f"   Files with Improvements:   {bd['files_with_improvements']:,} ({bd['improvement_rate']}%)")
    
    # Confidence Analysis
    ca = results['confidence_analysis']
    print(f"\n📊 Confidence Enhancement:")
    print(f"   Avg Confidence Improvement: +{ca['average_confidence_improvement']:.3f}")
    print(f"   Files with Better Confidence: {ca['improved_files_count']:,}")
    
    # Top Improvements
    print(f"\n🏆 Top 5 Brand Detection Improvements:")
    for i, imp in enumerate(results['top_improvements'][:5], 1):
        print(f"\n   {i}. Transcript: \"{imp['transcript']}\"")
        print(f"      Before: {imp['brands_before']} brands | After: {imp['brands_after']} brands (+{imp['improvement']})")
        print(f"      Enhanced Brands: {', '.join(imp['enhanced_brands'])}")
        print(f"      Confidence Boost: +{imp['confidence_boost']:.3f}")
    
    # Save to database
    print(f"\n💾 Saving improvements to database...")
    processor.save_improvements_to_db()
    
    print("\n" + "=" * 80)
    print("✅ ENHANCED BRAND DETECTION ANALYSIS COMPLETE")
    print(f"📈 Overall Improvement: +{bd['net_improvement']} brands detected across {bd['files_with_improvements']} files")
    print("=" * 80)

if __name__ == "__main__":
    main()