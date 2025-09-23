#!/usr/bin/env python3
"""
Export complete Scout Analytics data to CSV files
Uses Azure SQL connection to generate flat dataframe and crosstab exports
"""

import pyodbc
import pandas as pd
import os
from datetime import datetime

# Database connection configuration for flat_scratch database
conn_str = (
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=sqltbwaprojectscoutserver.database.windows.net;'
    'DATABASE=flat_scratch;'
    'UID=TBWA;'
    'PWD=R%40nd0mPA%24%242025%21'
)

def export_to_csv(query, filename, description):
    """Execute query and export results to CSV"""
    try:
        print(f"🔄 {description}")
        print(f"📊 Executing query...")

        # Connect and execute query
        conn = pyodbc.connect(conn_str)
        df = pd.read_sql(query, conn)
        conn.close()

        # Ensure exports directory exists
        os.makedirs('exports', exist_ok=True)

        # Export to CSV
        filepath = f"exports/{filename}"
        df.to_csv(filepath, index=False)

        print(f"✅ Exported {len(df)} rows to {filepath}")
        print(f"📝 Columns: {list(df.columns)}")

        return len(df), list(df.columns)

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return 0, []

def main():
    """Export complete Scout Analytics datasets"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    print("🚀 Scout Analytics Complete Data Export")
    print("=" * 50)

    # 1. Complete Flat Dataframe (all 12,075 records expected)
    flat_query = """
    SELECT *
    FROM gold.v_transactions_flat
    ORDER BY Txn_TS DESC
    """

    flat_filename = f"scout_flat_complete_{timestamp}.csv"
    flat_rows, flat_cols = export_to_csv(
        flat_query,
        flat_filename,
        "Complete Flat Dataframe (Transaction Detail)"
    )

    print()

    # 2. Complete Crosstab (all aggregated data)
    crosstab_query = """
    SELECT *
    FROM gold.v_transactions_crosstab
    ORDER BY [date] DESC, store_id, daypart, brand
    """

    crosstab_filename = f"scout_crosstab_complete_{timestamp}.csv"
    crosstab_rows, crosstab_cols = export_to_csv(
        crosstab_query,
        crosstab_filename,
        "Complete Crosstab (Aggregated Analysis)"
    )

    # Summary
    print("\n" + "=" * 50)
    print("📋 Export Summary:")
    print(f"  Flat Dataframe: {flat_rows} rows, {len(flat_cols)} columns")
    print(f"  Crosstab: {crosstab_rows} rows, {len(crosstab_cols)} columns")
    print(f"  Files: exports/{flat_filename}, exports/{crosstab_filename}")

    # Validation
    if flat_rows == 12075:
        print("✅ Flat dataframe: Expected 12,075 records - MATCH")
    else:
        print(f"⚠️  Flat dataframe: Expected 12,075 records, got {flat_rows}")

    if len(flat_cols) == 24:
        print("✅ Flat dataframe: Expected 24 columns - MATCH")
    else:
        print(f"⚠️  Flat dataframe: Expected 24 columns, got {len(flat_cols)}")

    if len(crosstab_cols) == 10:
        print("✅ Crosstab: Expected 10 columns - MATCH")
    else:
        print(f"⚠️  Crosstab: Expected 10 columns, got {len(crosstab_cols)}")

if __name__ == "__main__":
    main()