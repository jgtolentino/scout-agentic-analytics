#!/usr/bin/env python3
"""
Scout v7 Export Validator
Validates CSV/Parquet exports against locked schemas and canonical contracts
Created: 2025-09-26
"""

import os
import sys
import json
import csv
import gzip
import hashlib
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
import argparse

# Locked schema definitions
LOCKED_SCHEMAS = {
    "canonical_15col": [
        "Transaction_ID", "Transaction_Value", "Basket_Size", "Category", "Brand",
        "Daypart", "Age", "Gender", "Persona", "Weekday_vs_Weekend",
        "Time_of_Transaction", "Location", "Other_Products", "Was_Substitution",
        "Export_Timestamp"
    ],
    "overall/store_profiles": [
        "store_id", "store_name", "region", "transactions", "total_items", "total_amount"
    ],
    "overall/sales_by_week": [
        "iso_week", "week_start", "transactions", "total_amount"
    ],
    "overall/daypart_by_category": [
        "daypart", "category", "transactions", "share_pct"
    ],
    "overall/purchase_profile_pdp": [
        "dom_bucket", "transactions", "share_pct"
    ],
    "tobacco/demo_gender_age_brand": [
        "gender", "age_band", "brand", "transactions", "share_pct"
    ],
    "tobacco/purchase_profile_pdp": [
        "dom_bucket", "transactions", "share_pct"
    ],
    "tobacco/sales_by_day_daypart": [
        "date", "daypart", "transactions", "share_pct"
    ],
    "tobacco/sticks_per_visit": [
        "transaction_id", "brand", "items", "sticks_per_pack", "estimated_sticks"
    ],
    "tobacco/copurchase_categories": [
        "category", "co_category", "txn_cocount", "confidence", "lift"
    ],
    "laundry/copurchase_categories": [
        "category", "transactions", "share_pct"
    ],
    "laundry/detergent_type": [
        "detergent_type", "with_fabcon", "transactions", "share_pct"
    ]
}

class ExportValidator:
    """Validates Scout v7 export files against locked schemas"""

    def __init__(self, export_root: Path, strict: bool = False):
        self.export_root = Path(export_root)
        self.strict = strict
        self.issues = []
        self.files_scanned = []
        self.canonical_15col_found = False

        # Try to import pyarrow for Parquet support
        try:
            import pyarrow.parquet as pq
            self.has_parquet_support = True
            self.pq = pq
        except ImportError:
            self.has_parquet_support = False
            self.pq = None
            print("Warning: pyarrow not installed, Parquet validation disabled")

    def scan_exports(self) -> Dict[str, Any]:
        """Scan export directory and validate all files"""
        print(f"Scanning exports in: {self.export_root}")

        if not self.export_root.exists():
            self.issues.append({
                "type": "MISSING_DIRECTORY",
                "message": f"Export directory not found: {self.export_root}",
                "severity": "ERROR"
            })
            return self._generate_report()

        # Recursively scan all files
        for file_path in self.export_root.rglob("*"):
            if file_path.is_file():
                self._analyze_file(file_path)

        return self._generate_report()

    def _analyze_file(self, file_path: Path):
        """Analyze individual file"""
        relative_path = file_path.relative_to(self.export_root)

        file_info = {
            "path": str(relative_path),
            "size": file_path.stat().st_size,
            "extension": file_path.suffix.lower(),
            "stem": file_path.stem.replace('.csv', '').replace('.gz', ''),
            "modified": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat()
        }

        # Calculate MD5 hash
        try:
            with open(file_path, 'rb') as f:
                file_info["md5"] = hashlib.md5(f.read()).hexdigest()
        except Exception as e:
            file_info["md5"] = f"ERROR: {e}"

        self.files_scanned.append(file_info)

        # Validate based on file type
        if file_path.suffix.lower() in ['.csv', '.gz']:
            if file_path.suffix.lower() == '.gz' or file_path.name.endswith('.csv.gz'):
                self._validate_csv_file(file_path, relative_path, compressed=True)
            else:
                self._validate_csv_file(file_path, relative_path, compressed=False)
        elif file_path.suffix.lower() == '.parquet':
            self._validate_parquet_file(file_path, relative_path)

    def _validate_csv_file(self, file_path: Path, relative_path: Path, compressed: bool):
        """Validate CSV file against locked schemas"""
        try:
            # Read header
            if compressed:
                with gzip.open(file_path, 'rt', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    header = next(reader)
            else:
                with open(file_path, 'r', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    header = next(reader)

            # Check for canonical 15-column file
            if self._is_canonical_15col_file(file_path, header):
                self.canonical_15col_found = True
                self._validate_schema("canonical_15col", header, relative_path)
                return

            # Check against locked schemas
            schema_key = self._get_schema_key(relative_path)
            if schema_key:
                self._validate_schema(schema_key, header, relative_path)

        except Exception as e:
            self.issues.append({
                "type": "CSV_READ_ERROR",
                "file": str(relative_path),
                "message": f"Failed to read CSV: {e}",
                "severity": "ERROR"
            })

    def _validate_parquet_file(self, file_path: Path, relative_path: Path):
        """Validate Parquet file schema"""
        if not self.has_parquet_support:
            return

        try:
            table = self.pq.read_table(file_path)
            header = table.column_names

            # Check against locked schemas
            schema_key = self._get_schema_key(relative_path)
            if schema_key:
                self._validate_schema(schema_key, header, relative_path, file_type="PARQUET")

        except Exception as e:
            self.issues.append({
                "type": "PARQUET_READ_ERROR",
                "file": str(relative_path),
                "message": f"Failed to read Parquet: {e}",
                "severity": "ERROR"
            })

    def _is_canonical_15col_file(self, file_path: Path, header: List[str]) -> bool:
        """Check if this is the canonical 15-column file"""
        # Look for specific patterns in filename or path
        path_str = str(file_path).lower()
        canonical_indicators = [
            "canonical", "15col", "flat_export", "main_export",
            "v_flat_export", "canonical_export"
        ]

        has_indicator = any(indicator in path_str for indicator in canonical_indicators)
        has_15_columns = len(header) == 15

        return has_indicator and has_15_columns

    def _get_schema_key(self, relative_path: Path) -> Optional[str]:
        """Get schema key for file path"""
        path_str = str(relative_path).lower()

        # Map file patterns to schema keys - order matters for specificity
        if "tobacco" in path_str and "copurchase_categories" in path_str:
            return "tobacco/copurchase_categories"
        elif "laundry" in path_str and "copurchase_categories" in path_str:
            return "laundry/copurchase_categories"

        schema_mappings = {
            "store_profiles": "overall/store_profiles",
            "sales_by_week": "overall/sales_by_week",
            "daypart_by_category": "overall/daypart_by_category",
            "purchase_profile_pdp": "overall/purchase_profile_pdp",
            "demo_gender_age_brand": "tobacco/demo_gender_age_brand",
            "sales_by_day_daypart": "tobacco/sales_by_day_daypart",
            "sticks_per_visit": "tobacco/sticks_per_visit",
            "detergent_type": "laundry/detergent_type"
        }

        for pattern, schema_key in schema_mappings.items():
            if pattern in path_str:
                return schema_key

        return None

    def _validate_schema(self, schema_key: str, header: List[str], file_path: Path, file_type: str = "CSV"):
        """Validate header against locked schema"""
        expected_schema = LOCKED_SCHEMAS.get(schema_key)
        if not expected_schema:
            return

        if header != expected_schema:
            self.issues.append({
                "type": "SCHEMA_DRIFT",
                "file": str(file_path),
                "file_type": file_type,
                "schema_key": schema_key,
                "expected": expected_schema,
                "actual": header,
                "severity": "ERROR",
                "drift_details": self._analyze_drift(expected_schema, header)
            })

    def _analyze_drift(self, expected: List[str], actual: List[str]) -> Dict[str, Any]:
        """Analyze schema drift details"""
        return {
            "missing_columns": [col for col in expected if col not in actual],
            "extra_columns": [col for col in actual if col not in expected],
            "column_count_expected": len(expected),
            "column_count_actual": len(actual),
            "order_mismatch": expected != actual and set(expected) == set(actual)
        }

    def _check_csv_parquet_pairs(self):
        """Check for CSV↔Parquet pairs"""
        csv_stems = set()
        parquet_stems = set()

        for file_info in self.files_scanned:
            if file_info["extension"] in ['.csv', '.gz']:
                csv_stems.add(file_info["stem"])
            elif file_info["extension"] == '.parquet':
                parquet_stems.add(file_info["stem"])

        # Find missing pairs
        csv_only = csv_stems - parquet_stems
        parquet_only = parquet_stems - csv_stems

        for stem in csv_only:
            self.issues.append({
                "type": "MISSING_PARQUET_PAIR",
                "stem": stem,
                "message": f"CSV file '{stem}' has no corresponding Parquet file",
                "severity": "WARNING"
            })

        for stem in parquet_only:
            self.issues.append({
                "type": "MISSING_CSV_PAIR",
                "stem": stem,
                "message": f"Parquet file '{stem}' has no corresponding CSV file",
                "severity": "WARNING"
            })

    def _generate_report(self) -> Dict[str, Any]:
        """Generate comprehensive validation report"""
        self._check_csv_parquet_pairs()

        # Count issues by severity
        error_count = len([i for i in self.issues if i["severity"] == "ERROR"])
        warning_count = len([i for i in self.issues if i["severity"] == "WARNING"])

        report = {
            "timestamp": datetime.now().isoformat(),
            "export_root": str(self.export_root),
            "files_scanned": len(self.files_scanned),
            "canonical_15col_found": self.canonical_15col_found,
            "issues_found": len(self.issues),
            "error_count": error_count,
            "warning_count": warning_count,
            "has_parquet_support": self.has_parquet_support,
            "validation_status": "PASS" if error_count == 0 else "FAIL",
            "files": self.files_scanned,
            "issues": self.issues,
            "locked_schemas_checked": list(LOCKED_SCHEMAS.keys())
        }

        return report

    def write_manifests(self, report: Dict[str, Any]):
        """Write manifest files to export directory"""
        # Main manifest
        manifest_file = self.export_root / "_SCAN_MANIFEST.json"
        with open(manifest_file, 'w') as f:
            json.dump({
                "timestamp": report["timestamp"],
                "files_scanned": report["files_scanned"],
                "canonical_15col_found": report["canonical_15col_found"],
                "validation_status": report["validation_status"],
                "files": report["files"]
            }, f, indent=2)

        # Issues manifest
        issues_file = self.export_root / "_SCAN_ISSUES.json"
        with open(issues_file, 'w') as f:
            json.dump({
                "timestamp": report["timestamp"],
                "issues_found": report["issues_found"],
                "error_count": report["error_count"],
                "warning_count": report["warning_count"],
                "issues": report["issues"]
            }, f, indent=2)

        print(f"Manifests written: {manifest_file}, {issues_file}")

    def print_summary(self, report: Dict[str, Any]):
        """Print validation summary"""
        status_emoji = "✅" if report["validation_status"] == "PASS" else "❌"
        canonical_emoji = "✅" if report["canonical_15col_found"] else "❌"

        print(f"\n{status_emoji} Validation Status: {report['validation_status']}")
        print(f"{canonical_emoji} Canonical 15-col CSV present: {'YES' if report['canonical_15col_found'] else 'NO'}")
        print(f"📁 Files scanned: {report['files_scanned']}")
        print(f"🔍 Issues found: {report['issues_found']} ({report['error_count']} errors, {report['warning_count']} warnings)")

        if report["issues_found"] > 0:
            print(f"\nFirst 10 issues:")
            for i, issue in enumerate(report["issues"][:10]):
                severity_emoji = "🚨" if issue["severity"] == "ERROR" else "⚠️"
                print(f"  {severity_emoji} {issue['type']}: {issue.get('file', issue.get('stem', 'N/A'))}")
                if issue["type"] == "SCHEMA_DRIFT":
                    drift = issue["drift_details"]
                    if drift["missing_columns"]:
                        print(f"    Missing: {', '.join(drift['missing_columns'])}")
                    if drift["extra_columns"]:
                        print(f"    Extra: {', '.join(drift['extra_columns'])}")

def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(description="Scout v7 Export Validator")
    parser.add_argument("export_root", nargs="?", default="out/inquiries_filtered",
                       help="Export directory to validate (default: out/inquiries_filtered)")
    parser.add_argument("--strict", action="store_true",
                       help="Fail with non-zero exit code if any issues found")
    parser.add_argument("--quiet", action="store_true",
                       help="Suppress detailed output")

    args = parser.parse_args()

    # Initialize validator
    validator = ExportValidator(args.export_root, args.strict)

    # Run validation
    report = validator.scan_exports()

    # Write manifests
    validator.write_manifests(report)

    # Print summary unless quiet
    if not args.quiet:
        validator.print_summary(report)

    # Exit with appropriate code
    if args.strict and report["error_count"] > 0:
        print(f"\n❌ STRICT MODE: Failing due to {report['error_count']} errors")
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()