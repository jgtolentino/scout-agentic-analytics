#!/usr/bin/env python3
"""
Canonical Schema Compliance Validator for Scout v7
Validates database schema, file structure, and export compliance
Created: 2025-09-26
"""

import os
import json
import csv
import re
import hashlib
import gzip
from pathlib import Path
from typing import Dict, List, Any, Optional, Set
from datetime import datetime
import logging

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class CanonicalValidator:
    """Validates Scout v7 system against canonical schema patterns"""

    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.validation_results = {}
        self.errors = []
        self.warnings = []

    def scan_directory(self) -> Dict[str, Any]:
        """Scan project directory and create manifest"""
        logger.info("Scanning project directory...")

        manifest = {
            "scan_timestamp": datetime.now().isoformat(),
            "project_root": str(self.project_root),
            "files": [],
            "by_extension": {},
            "sql_objects": [],
            "csv_headers": {},
            "schema_analysis": {}
        }

        # Scan all files
        for file_path in self.project_root.rglob("*"):
            if file_path.is_file() and not self._should_ignore(file_path):
                file_info = self._analyze_file(file_path)
                manifest["files"].append(file_info)

                # Group by extension
                ext = file_info["extension"]
                if ext not in manifest["by_extension"]:
                    manifest["by_extension"][ext] = []
                manifest["by_extension"][ext].append(file_info["relative_path"])

        logger.info(f"Scanned {len(manifest['files'])} files")
        return manifest

    def _should_ignore(self, path: Path) -> bool:
        """Check if file should be ignored"""
        ignore_patterns = [
            "node_modules", ".git", "__pycache__", ".next",
            "out/", ".DS_Store", "*.log", "*.tmp"
        ]

        path_str = str(path)
        return any(pattern in path_str for pattern in ignore_patterns)

    def _analyze_file(self, file_path: Path) -> Dict[str, Any]:
        """Analyze individual file"""
        relative_path = file_path.relative_to(self.project_root)

        file_info = {
            "relative_path": str(relative_path),
            "extension": file_path.suffix.lower(),
            "size_bytes": file_path.stat().st_size,
            "modified": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat()
        }

        # Calculate SHA-1 hash
        try:
            with open(file_path, 'rb') as f:
                file_info["sha1"] = hashlib.sha1(f.read()).hexdigest()
        except Exception as e:
            file_info["sha1"] = f"ERROR: {e}"

        # Analyze based on file type
        if file_path.suffix.lower() == '.sql':
            file_info.update(self._analyze_sql_file(file_path))
        elif file_path.suffix.lower() in ['.csv', '.csv.gz']:
            file_info.update(self._analyze_csv_file(file_path))
        elif file_path.suffix.lower() == '.json':
            file_info.update(self._analyze_json_file(file_path))

        return file_info

    def _analyze_sql_file(self, file_path: Path) -> Dict[str, Any]:
        """Analyze SQL file for schema objects"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Extract SQL objects
            objects = []

            # Tables
            table_pattern = r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+\.\w+|\w+)'
            for match in re.finditer(table_pattern, content, re.IGNORECASE):
                objects.append(f"TABLE: {match.group(1)}")

            # Views
            view_pattern = r'CREATE\s+(?:OR\s+ALTER\s+)?VIEW\s+(\w+\.\w+|\w+)'
            for match in re.finditer(view_pattern, content, re.IGNORECASE):
                objects.append(f"VIEW: {match.group(1)}")

            # Procedures
            proc_pattern = r'CREATE\s+(?:OR\s+ALTER\s+)?PROCEDURE\s+(\w+\.\w+|\w+)'
            for match in re.finditer(proc_pattern, content, re.IGNORECASE):
                objects.append(f"PROCEDURE: {match.group(1)}")

            # Functions
            func_pattern = r'CREATE\s+(?:OR\s+ALTER\s+)?FUNCTION\s+(\w+\.\w+|\w+)'
            for match in re.finditer(func_pattern, content, re.IGNORECASE):
                objects.append(f"FUNCTION: {match.group(1)}")

            return {
                "sql_objects": objects,
                "sql_content_preview": content[:500] + "..." if len(content) > 500 else content
            }

        except Exception as e:
            return {"sql_error": str(e)}

    def _analyze_csv_file(self, file_path: Path) -> Dict[str, Any]:
        """Analyze CSV file for headers"""
        try:
            if file_path.suffix == '.gz':
                with gzip.open(file_path, 'rt', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    header = next(reader)
            else:
                with open(file_path, 'r', encoding='utf-8') as f:
                    reader = csv.reader(f)
                    header = next(reader)

            return {
                "csv_header": header,
                "column_count": len(header)
            }

        except Exception as e:
            return {"csv_error": str(e)}

    def _analyze_json_file(self, file_path: Path) -> Dict[str, Any]:
        """Analyze JSON file structure"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            return {
                "json_structure": {
                    "type": type(data).__name__,
                    "keys": list(data.keys()) if isinstance(data, dict) else None,
                    "length": len(data) if hasattr(data, '__len__') else None
                }
            }

        except Exception as e:
            return {"json_error": str(e)}

    def validate_canonical_compliance(self, manifest: Dict[str, Any]) -> Dict[str, Any]:
        """Validate system against canonical schema patterns"""
        logger.info("Running canonical compliance validation...")

        validation = {
            "timestamp": datetime.now().isoformat(),
            "schema_compliance": self._validate_schema_compliance(manifest),
            "file_structure": self._validate_file_structure(manifest),
            "export_compliance": self._validate_export_compliance(manifest),
            "naming_conventions": self._validate_naming_conventions(manifest),
            "analytics_coverage": self._validate_analytics_coverage(manifest),
            "summary": {}
        }

        # Generate summary
        validation["summary"] = self._generate_validation_summary(validation)

        return validation

    def _validate_schema_compliance(self, manifest: Dict[str, Any]) -> Dict[str, Any]:
        """Validate database schema compliance"""
        schema_validation = {
            "required_schemas": [],
            "canonical_objects": [],
            "dimension_tables": [],
            "fact_tables": [],
            "analytics_views": []
        }

        # Extract SQL objects from manifest
        sql_objects = []
        for file_info in manifest["files"]:
            if "sql_objects" in file_info:
                sql_objects.extend(file_info["sql_objects"])

        # Check for required canonical schemas
        required_schemas = ["canonical", "intel", "ref"]
        canonical_objects = [
            "canonical.SalesInteractionFact",
            "canonical.v_export_canonical_13col",
            "intel.BasketItems",
            "intel.SubstitutionEvents",
            "ref.NielsenHierarchy"
        ]

        for schema in required_schemas:
            schema_found = any(schema in obj for obj in sql_objects)
            schema_validation["required_schemas"].append({
                "schema": schema,
                "found": schema_found,
                "status": "✅" if schema_found else "❌"
            })

        # Check for canonical objects
        for obj in canonical_objects:
            obj_found = any(obj in sql_obj for sql_obj in sql_objects)
            schema_validation["canonical_objects"].append({
                "object": obj,
                "found": obj_found,
                "status": "✅" if obj_found else "❌"
            })

        return schema_validation

    def _validate_file_structure(self, manifest: Dict[str, Any]) -> Dict[str, Any]:
        """Validate file structure organization"""
        structure_validation = {
            "required_directories": [],
            "sql_organization": [],
            "script_organization": [],
            "documentation": []
        }

        # Check required directories
        required_dirs = [
            "sql/schema",
            "sql/analytics",
            "scripts",
            "out",
            "data"
        ]

        existing_dirs = set()
        for file_info in manifest["files"]:
            path_parts = Path(file_info["relative_path"]).parts
            if len(path_parts) > 1:
                existing_dirs.add("/".join(path_parts[:-1]))

        for req_dir in required_dirs:
            dir_exists = req_dir in existing_dirs
            structure_validation["required_directories"].append({
                "directory": req_dir,
                "exists": dir_exists,
                "status": "✅" if dir_exists else "❌"
            })

        return structure_validation

    def _validate_export_compliance(self, manifest: Dict[str, Any]) -> Dict[str, Any]:
        """Validate export file compliance"""
        export_validation = {
            "canonical_13col": [],
            "analytics_exports": [],
            "file_formats": []
        }

        # Check for 13-column canonical exports
        canonical_headers = [
            "Transaction_ID", "Store_Name", "Region", "Amount", "Date",
            "Daypart", "Basket_Size", "Category", "Brand", "Product",
            "Demographics (Age/Gender/Role)", "Quantity", "Enhanced_Payload"
        ]

        for file_info in manifest["files"]:
            if "csv_header" in file_info and "canonical" in file_info["relative_path"]:
                header_match = file_info["csv_header"] == canonical_headers
                export_validation["canonical_13col"].append({
                    "file": file_info["relative_path"],
                    "headers_match": header_match,
                    "actual_headers": file_info["csv_header"],
                    "status": "✅" if header_match else "❌"
                })

        return export_validation

    def _validate_naming_conventions(self, manifest: Dict[str, Any]) -> Dict[str, Any]:
        """Validate naming convention compliance"""
        naming_validation = {
            "table_naming": [],
            "file_naming": [],
            "schema_naming": []
        }

        # Extract table names from SQL objects
        tables = []
        for file_info in manifest["files"]:
            if "sql_objects" in file_info:
                for obj in file_info["sql_objects"]:
                    if "TABLE:" in obj:
                        table_name = obj.replace("TABLE:", "").strip()
                        tables.append(table_name)

        # Validate table naming patterns
        for table in tables:
            pascal_case = re.match(r'^[A-Z][a-zA-Z0-9]*$', table.split('.')[-1])
            no_spaces = ' ' not in table
            meaningful = len(table.split('.')[-1]) > 3

            naming_validation["table_naming"].append({
                "table": table,
                "pascal_case": bool(pascal_case),
                "no_spaces": no_spaces,
                "meaningful": meaningful,
                "compliant": bool(pascal_case) and no_spaces and meaningful
            })

        return naming_validation

    def _validate_analytics_coverage(self, manifest: Dict[str, Any]) -> Dict[str, Any]:
        """Validate analytics coverage"""
        analytics_validation = {
            "required_analytics": [],
            "export_files": [],
            "comprehensive_coverage": []
        }

        # Check for required analytics files
        required_analytics = [
            "store_demographics.sql",
            "tobacco_analytics.sql",
            "laundry_analytics.sql",
            "all_categories_analytics.sql",
            "conversation_intelligence.sql",
            "enhanced_full_scale_analytics.sql"
        ]

        analytics_files = [f["relative_path"] for f in manifest["files"]
                          if "analytics" in f["relative_path"] and f["extension"] == ".sql"]

        for req_file in required_analytics:
            file_exists = any(req_file in af for af in analytics_files)
            analytics_validation["required_analytics"].append({
                "file": req_file,
                "exists": file_exists,
                "status": "✅" if file_exists else "❌"
            })

        return analytics_validation

    def _generate_validation_summary(self, validation: Dict[str, Any]) -> Dict[str, Any]:
        """Generate validation summary"""
        summary = {
            "total_checks": 0,
            "passed_checks": 0,
            "failed_checks": 0,
            "warnings": 0,
            "compliance_score": 0.0,
            "status": "UNKNOWN"
        }

        # Count checks across all validation categories
        for category, results in validation.items():
            if isinstance(results, dict) and category != "summary":
                for subcategory, items in results.items():
                    if isinstance(items, list):
                        for item in items:
                            if isinstance(item, dict) and "status" in item:
                                summary["total_checks"] += 1
                                if item["status"] == "✅":
                                    summary["passed_checks"] += 1
                                else:
                                    summary["failed_checks"] += 1

        # Calculate compliance score
        if summary["total_checks"] > 0:
            summary["compliance_score"] = (summary["passed_checks"] / summary["total_checks"]) * 100

        # Determine overall status
        if summary["compliance_score"] >= 90:
            summary["status"] = "EXCELLENT"
        elif summary["compliance_score"] >= 75:
            summary["status"] = "GOOD"
        elif summary["compliance_score"] >= 50:
            summary["status"] = "NEEDS_IMPROVEMENT"
        else:
            summary["status"] = "CRITICAL"

        return summary

    def generate_reports(self, manifest: Dict[str, Any], validation: Dict[str, Any], output_dir: Path):
        """Generate validation reports"""
        output_dir.mkdir(parents=True, exist_ok=True)

        # Save manifest
        manifest_file = output_dir / "scout_v7_manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        logger.info(f"Manifest saved: {manifest_file}")

        # Save validation results
        validation_file = output_dir / "canonical_validation_results.json"
        with open(validation_file, 'w') as f:
            json.dump(validation, f, indent=2)
        logger.info(f"Validation results saved: {validation_file}")

        # Generate summary report
        summary_file = output_dir / "validation_summary.txt"
        self._generate_text_summary(validation, summary_file)
        logger.info(f"Summary report saved: {summary_file}")

    def _generate_text_summary(self, validation: Dict[str, Any], output_file: Path):
        """Generate human-readable summary report"""
        summary = validation["summary"]

        with open(output_file, 'w') as f:
            f.write("Scout v7 Canonical Schema Validation Report\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Generated: {validation['timestamp']}\n")
            f.write(f"Compliance Score: {summary['compliance_score']:.1f}%\n")
            f.write(f"Overall Status: {summary['status']}\n\n")

            f.write(f"Summary Statistics:\n")
            f.write(f"- Total Checks: {summary['total_checks']}\n")
            f.write(f"- Passed: {summary['passed_checks']}\n")
            f.write(f"- Failed: {summary['failed_checks']}\n\n")

            # Detailed results by category
            for category, results in validation.items():
                if category not in ["timestamp", "summary"]:
                    f.write(f"\n{category.upper().replace('_', ' ')}:\n")
                    f.write("-" * 30 + "\n")

                    if isinstance(results, dict):
                        for subcategory, items in results.items():
                            if isinstance(items, list) and items:
                                f.write(f"\n{subcategory.replace('_', ' ').title()}:\n")
                                for item in items:
                                    if isinstance(item, dict):
                                        status = item.get("status", "❓")
                                        name = item.get("file", item.get("object", item.get("schema", item.get("table", "Unknown"))))
                                        f.write(f"  {status} {name}\n")

def main():
    """Main execution function"""
    import argparse

    parser = argparse.ArgumentParser(description="Scout v7 Canonical Schema Validator")
    parser.add_argument("--project-root", default=".", help="Project root directory")
    parser.add_argument("--output-dir", default="out/validation", help="Output directory for reports")
    parser.add_argument("--run-checks", action="store_true", help="Run comprehensive validation checks")

    args = parser.parse_args()

    # Initialize validator
    validator = CanonicalValidator(args.project_root)

    # Scan directory
    manifest = validator.scan_directory()

    # Run validation if requested
    if args.run_checks:
        validation = validator.validate_canonical_compliance(manifest)

        # Generate reports
        output_dir = Path(args.output_dir)
        validator.generate_reports(manifest, validation, output_dir)

        # Print summary
        summary = validation["summary"]
        print(f"\n🎯 Validation Complete!")
        print(f"Compliance Score: {summary['compliance_score']:.1f}%")
        print(f"Status: {summary['status']}")
        print(f"Checks: {summary['passed_checks']}/{summary['total_checks']} passed")
        print(f"Reports saved to: {output_dir}")

    else:
        # Just save manifest
        output_dir = Path(args.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)

        manifest_file = output_dir / "scout_v7_manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        print(f"Manifest saved: {manifest_file}")

if __name__ == "__main__":
    main()