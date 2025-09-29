#!/usr/bin/env python3
"""
Validate Inquiry Export System
Checks all 17 inquiry exports for SQL errors, empty results, and data quality issues
"""
import sys
import os
from pathlib import Path
from validate_flat_export import check_sql_errors, read_csv_file

# Expected inquiry exports (17 total)
EXPECTED_EXPORTS = {
    "overall": [
        "store_profiles.csv",
        "sales_by_week.csv",
        "daypart_by_category.csv",
        "purchase_demographics.csv"
    ],
    "tobacco": [
        "demo_gender_age_brand.csv",
        "purchase_profile_pdp.csv",
        "sales_by_day_daypart.csv",
        "sticks_per_visit.csv",
        "copurchase_categories.csv",
        "frequent_terms.csv"
    ],
    "laundry": [
        "detergent_type.csv",
        "demo_gender_age_brand.csv",
        "purchase_profile_pdp.csv",
        "sales_by_day_daypart.csv",
        "copurchase_categories.csv",
        "frequent_terms.csv"
    ]
}

def validate_inquiry_exports(export_dir="out/inquiries_filtered"):
    """
    Validate all inquiry exports for data quality
    Returns: (is_valid, validation_report)
    """
    export_path = Path(export_dir)

    report = {
        "export_dir": str(export_path),
        "checks": {},
        "summary": {"passed": 0, "failed": 0, "total": 0},
        "issues": []
    }

    all_valid = True

    # Check each expected export
    for category, files in EXPECTED_EXPORTS.items():
        for filename in files:
            file_path = export_path / category / filename
            gz_path = Path(str(file_path) + '.gz')

            # Try both .csv and .csv.gz versions
            check_path = None
            if gz_path.exists():
                check_path = gz_path
            elif file_path.exists():
                check_path = file_path
            else:
                report["issues"].append(f"Missing file: {category}/{filename}")
                report["summary"]["failed"] += 1
                all_valid = False
                continue

            report["summary"]["total"] += 1
            file_key = f"{category}/{filename}"

            # Check for SQL errors and empty results
            try:
                sql_issues = check_sql_errors(check_path)
                has_sql_errors = len(sql_issues) > 0

                if has_sql_errors:
                    report["checks"][file_key] = {
                        "passed": False,
                        "sql_issues": sql_issues,
                        "issue_count": len(sql_issues)
                    }
                    report["issues"].append(f"SQL errors in {file_key}: {len(sql_issues)} issues")
                    report["summary"]["failed"] += 1
                    all_valid = False
                else:
                    # Check row count (exclude header)
                    try:
                        df = read_csv_file(check_path)
                        row_count = len(df)

                        if row_count == 0:
                            report["checks"][file_key] = {
                                "passed": False,
                                "empty": True,
                                "row_count": 0
                            }
                            report["issues"].append(f"Empty data in {file_key}: 0 rows")
                            report["summary"]["failed"] += 1
                            all_valid = False
                        else:
                            report["checks"][file_key] = {
                                "passed": True,
                                "row_count": row_count
                            }
                            report["summary"]["passed"] += 1
                    except Exception as e:
                        report["checks"][file_key] = {
                            "passed": False,
                            "read_error": str(e)
                        }
                        report["issues"].append(f"Read error in {file_key}: {str(e)}")
                        report["summary"]["failed"] += 1
                        all_valid = False

            except Exception as e:
                report["checks"][file_key] = {
                    "passed": False,
                    "validation_error": str(e)
                }
                report["issues"].append(f"Validation error in {file_key}: {str(e)}")
                report["summary"]["failed"] += 1
                all_valid = False

    return all_valid, report

def main():
    if len(sys.argv) > 1:
        export_dir = sys.argv[1]
    else:
        export_dir = "out/inquiries_filtered"

    print(f"🔍 Validating inquiry exports in: {export_dir}")

    is_valid, report = validate_inquiry_exports(export_dir)

    # Print results
    print(f"\n📋 Inquiry Export Validation Results:")
    print(f"{'='*50}")

    total_files = report["summary"]["total"]
    passed_files = report["summary"]["passed"]
    failed_files = report["summary"]["failed"]

    print(f"📊 Files checked: {total_files}")
    print(f"✅ Passed: {passed_files}")
    print(f"❌ Failed: {failed_files}")

    if report["issues"]:
        print(f"\n🚨 Issues found:")
        for issue in report["issues"]:
            print(f"  • {issue}")

    # Show per-file details
    print(f"\n📄 File Details:")
    for file_key, result in report["checks"].items():
        status = "✅" if result["passed"] else "❌"
        print(f"{status} {file_key}")

        if not result["passed"]:
            if "sql_issues" in result:
                print(f"   SQL Issues: {result['issue_count']}")
            if "empty" in result:
                print(f"   Empty file (0 rows)")
            if "read_error" in result:
                print(f"   Read error: {result['read_error']}")
            if "validation_error" in result:
                print(f"   Validation error: {result['validation_error']}")
        else:
            if "row_count" in result:
                print(f"   Rows: {result['row_count']}")

    if is_valid:
        print(f"\n✅ All inquiry exports are valid")
        sys.exit(0)
    else:
        print(f"\n❌ Inquiry exports have issues")
        sys.exit(1)

if __name__ == "__main__":
    main()