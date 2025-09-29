#!/usr/bin/env python3
"""
Scout v7 Performance Monitor & Optimization Engine
Real-time monitoring with automated optimization recommendations
"""

import os
import sys
import time
import json
import logging
import psutil
import hashlib
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, as_completed

@dataclass
class PerformanceMetrics:
    """Performance metrics container"""
    timestamp: datetime
    cpu_percent: float
    memory_percent: float
    disk_usage_percent: float
    export_file_count: int
    export_total_size: int
    validation_time: float
    bottlenecks: List[str]
    recommendations: List[str]

class PerformanceMonitor:
    """Real-time performance monitoring and optimization"""

    def __init__(self, export_dir: str = "out/inquiries_filtered"):
        self.export_dir = Path(export_dir)
        self.metrics_file = Path("performance_metrics.json")
        self.logger = self._setup_logging()
        self.baseline_metrics = self._load_baseline()

    def _setup_logging(self) -> logging.Logger:
        """Setup performance logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('performance.log'),
                logging.StreamHandler()
            ]
        )
        return logging.getLogger(__name__)

    def _load_baseline(self) -> Optional[Dict]:
        """Load baseline performance metrics"""
        if self.metrics_file.exists():
            try:
                with open(self.metrics_file, 'r') as f:
                    data = json.load(f)
                    if 'baseline' in data:
                        return data['baseline']
            except Exception as e:
                self.logger.warning(f"Failed to load baseline: {e}")
        return None

    def collect_system_metrics(self) -> Dict[str, Any]:
        """Collect system performance metrics"""
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        return {
            'cpu_percent': cpu_percent,
            'memory_percent': memory.percent,
            'memory_available_gb': memory.available / (1024**3),
            'disk_usage_percent': disk.percent,
            'disk_free_gb': disk.free / (1024**3),
            'timestamp': datetime.now().isoformat()
        }

    def analyze_export_performance(self) -> Dict[str, Any]:
        """Analyze export file performance metrics"""
        if not self.export_dir.exists():
            return {
                'file_count': 0,
                'total_size': 0,
                'avg_file_size': 0,
                'large_files': [],
                'empty_files': []
            }

        files = list(self.export_dir.rglob('*'))
        file_sizes = []
        large_files = []
        empty_files = []

        for file_path in files:
            if file_path.is_file():
                size = file_path.stat().st_size
                file_sizes.append(size)

                # Flag large files (>50MB)
                if size > 50 * 1024 * 1024:
                    large_files.append({
                        'path': str(file_path.relative_to(self.export_dir)),
                        'size_mb': size / (1024**2)
                    })

                # Flag empty files
                if size == 0:
                    empty_files.append(str(file_path.relative_to(self.export_dir)))

        total_size = sum(file_sizes)
        avg_size = total_size / len(file_sizes) if file_sizes else 0

        return {
            'file_count': len(file_sizes),
            'total_size': total_size,
            'total_size_mb': total_size / (1024**2),
            'avg_file_size': avg_size,
            'avg_file_size_kb': avg_size / 1024,
            'large_files': large_files,
            'empty_files': empty_files,
            'analysis_time': datetime.now().isoformat()
        }

    def measure_validation_performance(self) -> Dict[str, Any]:
        """Measure validation script performance"""
        start_time = time.time()

        try:
            # Run validation and capture timing
            import subprocess
            result = subprocess.run([
                'python3', 'scripts/validate_exports.py', str(self.export_dir), '--quiet'
            ], capture_output=True, text=True, timeout=300)

            validation_time = time.time() - start_time

            return {
                'validation_time': validation_time,
                'exit_code': result.returncode,
                'success': result.returncode == 0,
                'output_lines': len(result.stdout.split('\n')),
                'error_lines': len(result.stderr.split('\n')) if result.stderr else 0
            }
        except subprocess.TimeoutExpired:
            return {
                'validation_time': time.time() - start_time,
                'exit_code': -1,
                'success': False,
                'timeout': True
            }
        except Exception as e:
            return {
                'validation_time': time.time() - start_time,
                'exit_code': -1,
                'success': False,
                'error': str(e)
            }

    def identify_bottlenecks(self, system_metrics: Dict, export_metrics: Dict, validation_metrics: Dict) -> List[str]:
        """Identify performance bottlenecks"""
        bottlenecks = []

        # CPU bottlenecks
        if system_metrics['cpu_percent'] > 80:
            bottlenecks.append(f"High CPU usage: {system_metrics['cpu_percent']:.1f}%")

        # Memory bottlenecks
        if system_metrics['memory_percent'] > 85:
            bottlenecks.append(f"High memory usage: {system_metrics['memory_percent']:.1f}%")

        # Disk bottlenecks
        if system_metrics['disk_usage_percent'] > 90:
            bottlenecks.append(f"Low disk space: {system_metrics['disk_usage_percent']:.1f}% used")

        # Export size bottlenecks
        if export_metrics['total_size_mb'] > 500:
            bottlenecks.append(f"Large export size: {export_metrics['total_size_mb']:.1f}MB")

        # File count bottlenecks
        if export_metrics['file_count'] > 1000:
            bottlenecks.append(f"High file count: {export_metrics['file_count']} files")

        # Validation performance bottlenecks
        if validation_metrics.get('validation_time', 0) > 60:
            bottlenecks.append(f"Slow validation: {validation_metrics['validation_time']:.1f}s")

        # Large files
        if export_metrics['large_files']:
            bottlenecks.append(f"Large files detected: {len(export_metrics['large_files'])} files >50MB")

        return bottlenecks

    def generate_recommendations(self, bottlenecks: List[str], export_metrics: Dict) -> List[str]:
        """Generate optimization recommendations"""
        recommendations = []

        # CPU optimization
        if any("CPU usage" in b for b in bottlenecks):
            recommendations.append("Consider parallel processing with ThreadPoolExecutor")
            recommendations.append("Enable CPU-intensive operations batching")

        # Memory optimization
        if any("memory usage" in b for b in bottlenecks):
            recommendations.append("Implement streaming processing for large files")
            recommendations.append("Add memory usage limits and garbage collection")

        # Disk optimization
        if any("disk space" in b for b in bottlenecks):
            recommendations.append("Implement file cleanup and rotation")
            recommendations.append("Add compression for older export files")

        # Export optimization
        if any("export size" in b for b in bottlenecks):
            recommendations.append("Enable export file compression (gzip)")
            recommendations.append("Implement incremental exports")

        # File optimization
        if export_metrics['large_files']:
            recommendations.append("Split large files into chunks")
            recommendations.append("Implement Parquet format for better compression")

        if export_metrics['empty_files']:
            recommendations.append("Remove empty files from export pipeline")

        # Validation optimization
        if any("validation" in b for b in bottlenecks):
            recommendations.append("Implement parallel validation processing")
            recommendations.append("Add validation result caching")

        # General recommendations
        if len(bottlenecks) == 0:
            recommendations.append("Performance is optimal - no immediate optimizations needed")
        else:
            recommendations.append("Enable performance monitoring alerts")
            recommendations.append("Implement automated performance tuning")

        return recommendations

    def save_metrics(self, metrics: PerformanceMetrics):
        """Save performance metrics to file"""
        try:
            # Load existing data
            data = {}
            if self.metrics_file.exists():
                with open(self.metrics_file, 'r') as f:
                    data = json.load(f)

            # Add new metric
            if 'history' not in data:
                data['history'] = []

            data['history'].append({
                'timestamp': metrics.timestamp.isoformat(),
                'cpu_percent': metrics.cpu_percent,
                'memory_percent': metrics.memory_percent,
                'disk_usage_percent': metrics.disk_usage_percent,
                'export_file_count': metrics.export_file_count,
                'export_total_size': metrics.export_total_size,
                'validation_time': metrics.validation_time,
                'bottlenecks': metrics.bottlenecks,
                'recommendations': metrics.recommendations
            })

            # Keep only last 100 entries
            data['history'] = data['history'][-100:]

            # Update baseline if performance improved
            current_score = self._calculate_performance_score(metrics)
            if 'baseline' not in data or current_score > data.get('baseline_score', 0):
                data['baseline'] = {
                    'timestamp': metrics.timestamp.isoformat(),
                    'cpu_percent': metrics.cpu_percent,
                    'memory_percent': metrics.memory_percent,
                    'validation_time': metrics.validation_time,
                    'score': current_score
                }
                data['baseline_score'] = current_score

            # Save updated data
            with open(self.metrics_file, 'w') as f:
                json.dump(data, f, indent=2)

        except Exception as e:
            self.logger.error(f"Failed to save metrics: {e}")

    def _calculate_performance_score(self, metrics: PerformanceMetrics) -> float:
        """Calculate overall performance score (0-100)"""
        # Lower is better for most metrics
        cpu_score = max(0, 100 - metrics.cpu_percent)
        memory_score = max(0, 100 - metrics.memory_percent)
        disk_score = max(0, 100 - metrics.disk_usage_percent)

        # Validation time score (penalty for >30s)
        validation_score = max(0, 100 - (metrics.validation_time * 2))

        # Bottleneck penalty
        bottleneck_penalty = len(metrics.bottlenecks) * 10

        overall_score = (cpu_score + memory_score + disk_score + validation_score) / 4 - bottleneck_penalty
        return max(0, min(100, overall_score))

    def run_performance_analysis(self) -> PerformanceMetrics:
        """Run comprehensive performance analysis"""
        self.logger.info("🔍 Starting performance analysis...")

        # Collect metrics
        system_metrics = self.collect_system_metrics()
        export_metrics = self.analyze_export_performance()
        validation_metrics = self.measure_validation_performance()

        # Identify issues
        bottlenecks = self.identify_bottlenecks(system_metrics, export_metrics, validation_metrics)
        recommendations = self.generate_recommendations(bottlenecks, export_metrics)

        # Create metrics object
        metrics = PerformanceMetrics(
            timestamp=datetime.now(),
            cpu_percent=system_metrics['cpu_percent'],
            memory_percent=system_metrics['memory_percent'],
            disk_usage_percent=system_metrics['disk_usage_percent'],
            export_file_count=export_metrics['file_count'],
            export_total_size=export_metrics['total_size'],
            validation_time=validation_metrics.get('validation_time', 0),
            bottlenecks=bottlenecks,
            recommendations=recommendations
        )

        # Save metrics
        self.save_metrics(metrics)

        return metrics

    def print_performance_report(self, metrics: PerformanceMetrics):
        """Print formatted performance report"""
        print("\n" + "="*60)
        print("🚀 SCOUT V7 PERFORMANCE REPORT")
        print("="*60)

        # System metrics
        print(f"\n📊 SYSTEM METRICS:")
        print(f"  CPU Usage:     {metrics.cpu_percent:6.1f}%")
        print(f"  Memory Usage:  {metrics.memory_percent:6.1f}%")
        print(f"  Disk Usage:    {metrics.disk_usage_percent:6.1f}%")

        # Export metrics
        print(f"\n📁 EXPORT METRICS:")
        print(f"  File Count:    {metrics.export_file_count:6,} files")
        print(f"  Total Size:    {metrics.export_total_size/(1024**2):6.1f} MB")
        print(f"  Validation:    {metrics.validation_time:6.1f}s")

        # Performance score
        score = self._calculate_performance_score(metrics)
        score_emoji = "🟢" if score >= 80 else "🟡" if score >= 60 else "🔴"
        print(f"\n{score_emoji} PERFORMANCE SCORE: {score:.1f}/100")

        # Bottlenecks
        if metrics.bottlenecks:
            print(f"\n⚠️  BOTTLENECKS DETECTED:")
            for bottleneck in metrics.bottlenecks:
                print(f"  • {bottleneck}")
        else:
            print(f"\n✅ NO BOTTLENECKS DETECTED")

        # Recommendations
        print(f"\n💡 RECOMMENDATIONS:")
        for rec in metrics.recommendations:
            print(f"  • {rec}")

        print("\n" + "="*60)

def main():
    """Main execution function"""
    import argparse

    parser = argparse.ArgumentParser(description="Scout v7 Performance Monitor")
    parser.add_argument("--export-dir", default="out/inquiries_filtered",
                       help="Export directory to analyze")
    parser.add_argument("--json", action="store_true",
                       help="Output results as JSON")
    parser.add_argument("--baseline", action="store_true",
                       help="Set current performance as baseline")

    args = parser.parse_args()

    # Initialize monitor
    monitor = PerformanceMonitor(args.export_dir)

    # Run analysis
    metrics = monitor.run_performance_analysis()

    if args.json:
        # JSON output for CI/CD integration
        output = {
            'timestamp': metrics.timestamp.isoformat(),
            'performance_score': monitor._calculate_performance_score(metrics),
            'cpu_percent': metrics.cpu_percent,
            'memory_percent': metrics.memory_percent,
            'disk_usage_percent': metrics.disk_usage_percent,
            'export_file_count': metrics.export_file_count,
            'export_total_size_mb': metrics.export_total_size / (1024**2),
            'validation_time': metrics.validation_time,
            'bottlenecks': metrics.bottlenecks,
            'recommendations': metrics.recommendations
        }
        print(json.dumps(output, indent=2))
    else:
        # Human-readable report
        monitor.print_performance_report(metrics)

if __name__ == "__main__":
    main()