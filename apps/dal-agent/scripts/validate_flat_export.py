#!/usr/bin/env python3
"""
Validate flat dataframe export against canonical schemas
Implements 6-check validation framework for bulletproof exports
"""
import sys
import os
import pandas as pd
import gzip
import io
from pathlib import Path

# Canonical schemas (13-col default, 14-col with transcript)
SCHEMA_13 = "transaction_id,transaction_date,store_id,store_name,region,category,brand,total_items,total_amount,payment_method,daypart,inferred_role,role_confidence"
SCHEMA_14 = "transaction_id,transaction_date,store_id,store_name,region,category,brand,total_items,total_amount,payment_method,daypart,audio_transcript,inferred_role,role_confidence"

def read_csv_file(filepath):
    """Read CSV file (handles both .csv and .csv.gz)"""
    p = Path(filepath)

    if p.suffix == '.gz':
        with gzip.open(p, 'rb') as fh:
            return pd.read_csv(io.BytesIO(fh.read()), dtype=str)
    elif p.exists():
        return pd.read_csv(p, dtype=str)
    elif Path(str(p) + '.gz').exists():
        with gzip.open(str(p) + '.gz', 'rb') as fh:
            return pd.read_csv(io.BytesIO(fh.read()), dtype=str)
    else:
        raise FileNotFoundError(f"File not found: {filepath} (or .gz variant)")

def get_header(filepath):
    """Get header line from CSV file (handles both .csv and .csv.gz)"""
    p = Path(filepath)

    if p.suffix == '.gz':
        with gzip.open(p, 'rt') as f:
            return f.readline().strip('\r\n')
    elif p.exists():
        with open(p, 'r') as f:
            return f.readline().strip('\r\n')
    elif Path(str(p) + '.gz').exists():
        with gzip.open(str(p) + '.gz', 'rt') as f:
            return f.readline().strip('\r\n')
    else:
        raise FileNotFoundError(f"File not found: {filepath} (or .gz variant)")

def check_sql_errors(filepath):
    """Check for SQL error messages leaked into data"""
    p = Path(filepath)

    if p.suffix == '.gz':
        with gzip.open(p, 'rt') as f:
            content = f.read()
    elif p.exists():
        with open(p, 'r') as f:
            content = f.read()
    elif Path(str(p) + '.gz').exists():
        with gzip.open(str(p) + '.gz', 'rt') as f:
            content = f.read()
    else:
        raise FileNotFoundError(f"File not found: {filepath} (or .gz variant)")

    # Look for SQL error messages (but not informational "rows affected")
    import re
    sql_errors = re.findall(r'^Msg \d+', content, re.MULTILINE)

    # Only flag "(0 rows affected)" as an issue, not other row counts
    zero_results = re.findall(r'\(0 rows affected\)', content)

    all_issues = sql_errors + zero_results
    return all_issues

def validate_flat_export(filepath, db_name=None):
    """
    Validate flat dataframe export using 6-check framework
    Returns: (is_valid, validation_report)
    """
    report = {
        "file": str(filepath),
        "checks": {},
        "summary": {"passed": 0, "failed": 0, "total": 6}
    }

    try:
        # Check 1: Header validation (13 or 14 schema)
        try:
            header = get_header(filepath)
            header_valid = header in [SCHEMA_13, SCHEMA_14]
            schema_type = "13-col" if header == SCHEMA_13 else "14-col" if header == SCHEMA_14 else "unknown"

            report["checks"]["header"] = {
                "passed": header_valid,
                "actual": header,
                "expected": f"{SCHEMA_13} OR {SCHEMA_14}",
                "schema_type": schema_type
            }
            if header_valid:
                report["summary"]["passed"] += 1
            else:
                report["summary"]["failed"] += 1
        except Exception as e:
            report["checks"]["header"] = {"passed": False, "error": str(e)}
            report["summary"]["failed"] += 1

        # Check 2: No SQL error lines in data
        try:
            sql_errors = check_sql_errors(filepath)
            no_sql_errors = len(sql_errors) == 0

            report["checks"]["sql_errors"] = {
                "passed": no_sql_errors,
                "sql_errors_found": sql_errors,
                "count": len(sql_errors)
            }
            if no_sql_errors:
                report["summary"]["passed"] += 1
            else:
                report["summary"]["failed"] += 1
        except Exception as e:
            report["checks"]["sql_errors"] = {"passed": False, "error": str(e)}
            report["summary"]["failed"] += 1

        # Check 3: Row count parity with DB (if db_name provided)
        if db_name:
            try:
                # Get CSV row count
                df = read_csv_file(filepath)
                csv_rows = len(df)

                # Get DB row count
                db_command = f'./scripts/sql.sh -d "{db_name}" -Q "SELECT COUNT(*) FROM dbo.v_transactions_flat_production"'
                import subprocess
                result = subprocess.run(db_command, shell=True, capture_output=True, text=True)
                if result.returncode == 0:
                    db_rows = int(result.stdout.strip().replace('\r', ''))
                    parity_check = csv_rows == db_rows

                    report["checks"]["row_parity"] = {
                        "passed": parity_check,
                        "csv_rows": csv_rows,
                        "db_rows": db_rows,
                        "difference": abs(csv_rows - db_rows)
                    }
                    if parity_check:
                        report["summary"]["passed"] += 1
                    else:
                        report["summary"]["failed"] += 1
                else:
                    report["checks"]["row_parity"] = {"passed": False, "error": "DB query failed"}
                    report["summary"]["failed"] += 1
            except Exception as e:
                report["checks"]["row_parity"] = {"passed": False, "error": str(e)}
                report["summary"]["failed"] += 1
        else:
            report["checks"]["row_parity"] = {"passed": True, "skipped": "no db_name provided"}
            report["summary"]["passed"] += 1

        # Check 4: Key constraints (transaction_id unique and non-null)
        try:
            df = read_csv_file(filepath)
            nulls = df['transaction_id'].isna().sum()
            dups = df['transaction_id'].duplicated().sum()
            keys_valid = nulls == 0 and dups == 0

            report["checks"]["key_constraints"] = {
                "passed": keys_valid,
                "null_transaction_ids": int(nulls),
                "duplicate_transaction_ids": int(dups),
                "total_rows": len(df)
            }
            if keys_valid:
                report["summary"]["passed"] += 1
            else:
                report["summary"]["failed"] += 1
        except Exception as e:
            report["checks"]["key_constraints"] = {"passed": False, "error": str(e)}
            report["summary"]["failed"] += 1

        # Check 5: Type sanity on core numerics/datetimes
        try:
            df = read_csv_file(filepath)

            # Test numeric conversions
            total_items = pd.to_numeric(df['total_items'], errors='coerce')
            total_amount = pd.to_numeric(df['total_amount'], errors='coerce')
            transaction_date = pd.to_datetime(df['transaction_date'], errors='coerce')

            bad_items = int(total_items.isna().sum())
            bad_amount = int(total_amount.isna().sum())
            bad_date = int(transaction_date.isna().sum())

            types_valid = bad_items == 0 and bad_amount == 0 and bad_date == 0

            report["checks"]["type_sanity"] = {
                "passed": types_valid,
                "bad_total_items": bad_items,
                "bad_total_amount": bad_amount,
                "bad_transaction_date": bad_date
            }
            if types_valid:
                report["summary"]["passed"] += 1
            else:
                report["summary"]["failed"] += 1
        except Exception as e:
            report["checks"]["type_sanity"] = {"passed": False, "error": str(e)}
            report["summary"]["failed"] += 1

        # Check 6: Manifest presence (optional but recommended)
        try:
            manifest_path = Path("out/inquiries_filtered/_MANIFEST.json")
            manifest_exists = manifest_path.exists()

            report["checks"]["manifest"] = {
                "passed": True,  # This is always a pass (optional check)
                "manifest_present": manifest_exists,
                "manifest_path": str(manifest_path)
            }
            report["summary"]["passed"] += 1
        except Exception as e:
            report["checks"]["manifest"] = {"passed": True, "error": str(e)}
            report["summary"]["passed"] += 1

        # Overall validation result
        is_valid = report["summary"]["failed"] == 0
        return is_valid, report

    except Exception as e:
        report["error"] = str(e)
        return False, report

def main():
    if len(sys.argv) < 2:
        print("Usage: python validate_flat_export.py <csv_file> [db_name]")
        print("Examples:")
        print("  python validate_flat_export.py out/flat_mart.csv")
        print("  python validate_flat_export.py out/flat_mart.csv.gz SQL-TBWA-ProjectScout-Reporting-Prod")
        sys.exit(1)

    filepath = sys.argv[1]
    db_name = sys.argv[2] if len(sys.argv) > 2 else None

    print(f"🔍 Validating flat export: {filepath}")
    if db_name:
        print(f"📊 DB parity check: {db_name}")

    is_valid, report = validate_flat_export(filepath, db_name)

    # Print results
    print(f"\n📋 Validation Results:")
    print(f"{'='*50}")

    for check_name, check_result in report["checks"].items():
        status = "✅" if check_result["passed"] else "❌"
        print(f"{status} {check_name.replace('_', ' ').title()}")

        if not check_result["passed"] and "error" not in check_result:
            if check_name == "header":
                print(f"   Expected: 13-col or 14-col schema")
                print(f"   Actual:   {check_result.get('actual', 'unknown')}")
            elif check_name == "sql_errors":
                print(f"   SQL errors found: {check_result.get('count', 0)}")
            elif check_name == "row_parity":
                print(f"   CSV rows: {check_result.get('csv_rows', 'unknown')}")
                print(f"   DB rows:  {check_result.get('db_rows', 'unknown')}")
            elif check_name == "key_constraints":
                print(f"   Null IDs: {check_result.get('null_transaction_ids', 'unknown')}")
                print(f"   Duplicate IDs: {check_result.get('duplicate_transaction_ids', 'unknown')}")
            elif check_name == "type_sanity":
                print(f"   Bad items: {check_result.get('bad_total_items', 'unknown')}")
                print(f"   Bad amounts: {check_result.get('bad_total_amount', 'unknown')}")
                print(f"   Bad dates: {check_result.get('bad_transaction_date', 'unknown')}")

    print(f"\n📊 Summary: {report['summary']['passed']}/{report['summary']['total']} checks passed")

    if is_valid:
        schema_type = None
        if "header" in report["checks"]:
            schema_type = report["checks"]["header"].get("schema_type", "unknown")
        print(f"✅ Flat export VALID ({schema_type})")
        sys.exit(0)
    else:
        print(f"❌ Flat export INVALID")
        sys.exit(1)

if __name__ == "__main__":
    main()