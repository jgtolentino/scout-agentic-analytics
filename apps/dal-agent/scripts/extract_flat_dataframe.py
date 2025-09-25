#!/usr/bin/env python3
"""
Scout Analytics Platform - Flat Dataframe Extractor
Purpose: Extract flattened, merged, enriched dataframe from Scout database
Usage: python extract_flat_dataframe.py --out flat_dataframe.csv

Requirements:
- pyodbc: pip install pyodbc
- pandas: pip install pandas
- AZURE_SQL_CONN_STR environment variable or --conn parameter

Author: Scout Analytics Platform
Version: 1.0
"""

import os
import argparse
import sys
import pandas as pd
import pyodbc
from datetime import datetime

# Exact 12 columns in specified order - DO NOT CHANGE
REQUIRED_COLUMNS = [
    "Transaction_ID",
    "Transaction_Value",
    "Basket_Size",
    "Category",
    "Brand",
    "Daypart",
    "Demographics (Age/Gender/Role)",
    "Weekday_vs_Weekend",
    "Time of transaction",
    "Location",
    "Other_Products",
    "Was_Substitution"
]

def validate_connection_string(conn_str):
    """Validate connection string format and required parameters"""
    if not conn_str:
        return False, "Connection string is empty"

    required_params = ['Server', 'Database']
    missing_params = []

    for param in required_params:
        if param.lower() not in conn_str.lower():
            missing_params.append(param)

    if missing_params:
        return False, f"Missing required connection parameters: {', '.join(missing_params)}"

    return True, "Connection string valid"

def extract_dataframe(connection_string, output_file, limit=None, validate_schema=True):
    """
    Extract flat dataframe from Scout database

    Args:
        connection_string: Azure SQL connection string
        output_file: Output CSV file path
        limit: Optional row limit for testing (default: None = all rows)
        validate_schema: Validate column schema against specification

    Returns:
        tuple: (success: bool, message: str, row_count: int)
    """

    print(f"🔍 Starting flat dataframe extraction...")
    print(f"📅 Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    try:
        # Validate connection string
        is_valid, validation_msg = validate_connection_string(connection_string)
        if not is_valid:
            return False, f"Connection validation failed: {validation_msg}", 0

        print(f"✅ Connection string validated")

        # Connect to database
        print(f"🔗 Connecting to Scout database...")
        connection = pyodbc.connect(connection_string)
        print(f"✅ Database connection established")

        # Build query with optional limit
        base_query = "SELECT * FROM dbo.v_flat_export_sheet"
        if limit:
            query = f"SELECT TOP ({limit}) * FROM dbo.v_flat_export_sheet ORDER BY Transaction_ID"
            print(f"📊 Extracting sample data (limit: {limit} rows)")
        else:
            query = base_query
            print(f"📊 Extracting complete dataset")

        # Execute query and load into pandas
        print(f"⚡ Executing query...")
        start_time = datetime.now()

        df = pd.read_sql(query, connection)

        execution_time = (datetime.now() - start_time).total_seconds()
        print(f"✅ Query executed in {execution_time:.2f} seconds")
        print(f"📈 Retrieved {len(df)} rows")

        # Validate schema if requested
        if validate_schema:
            print(f"🔍 Validating column schema...")

            # Check if all required columns are present
            missing_columns = []
            for col in REQUIRED_COLUMNS:
                if col not in df.columns:
                    missing_columns.append(col)

            if missing_columns:
                return False, f"Missing required columns: {', '.join(missing_columns)}", len(df)

            # Check for extra columns
            extra_columns = [col for col in df.columns if col not in REQUIRED_COLUMNS]
            if extra_columns:
                print(f"⚠️ Warning: Extra columns found: {', '.join(extra_columns)}")

            # Ensure correct column order
            df = df[REQUIRED_COLUMNS]
            print(f"✅ Schema validation passed - 12 columns in correct order")

        # Data quality summary
        print(f"📊 Data Quality Summary:")
        print(f"   • Total rows: {len(df)}")
        print(f"   • Unique transactions: {df['Transaction_ID'].nunique()}")
        print(f"   • Date range: {df['Transaction_ID'].min()} to {df['Transaction_ID'].max()}")

        # Check for critical null values
        critical_nulls = {
            'Transaction_ID': df['Transaction_ID'].isnull().sum(),
            'Transaction_Value': df['Transaction_Value'].isnull().sum(),
            'Category': df['Category'].isnull().sum() + (df['Category'] == '').sum(),
            'Brand': df['Brand'].isnull().sum() + (df['Brand'] == '').sum()
        }

        for field, null_count in critical_nulls.items():
            if null_count > 0:
                percentage = (null_count / len(df)) * 100
                print(f"   • {field} nulls/empty: {null_count} ({percentage:.1f}%)")

        # Write to CSV with exact column order
        print(f"💾 Writing to CSV: {output_file}")
        df.to_csv(output_file, index=False)

        # Verify file was created
        if os.path.exists(output_file):
            file_size = os.path.getsize(output_file)
            print(f"✅ File written successfully")
            print(f"   • File size: {file_size:,} bytes")
            print(f"   • File path: {os.path.abspath(output_file)}")
        else:
            return False, "File was not created", len(df)

        # Close connection
        connection.close()
        print(f"🔌 Database connection closed")

        return True, f"Successfully extracted {len(df)} rows", len(df)

    except pyodbc.Error as e:
        return False, f"Database error: {str(e)}", 0
    except pd.errors.DatabaseError as e:
        return False, f"Pandas database error: {str(e)}", 0
    except Exception as e:
        return False, f"Unexpected error: {str(e)}", 0

def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(
        description='Extract Scout Analytics flat dataframe to CSV',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python extract_flat_dataframe.py --out flat_dataframe.csv
    python extract_flat_dataframe.py --conn "Server=..." --out data.csv
    python extract_flat_dataframe.py --out sample.csv --limit 1000

Environment Variables:
    AZURE_SQL_CONN_STR    Azure SQL connection string (if --conn not provided)
        """
    )

    parser.add_argument(
        "--conn",
        default=os.environ.get("AZURE_SQL_CONN_STR"),
        help="Azure SQL connection string (default: AZURE_SQL_CONN_STR env var)"
    )

    parser.add_argument(
        "--out",
        required=True,
        help="Output CSV file path"
    )

    parser.add_argument(
        "--limit",
        type=int,
        help="Limit number of rows for testing (optional)"
    )

    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip column schema validation"
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )

    args = parser.parse_args()

    # Validate arguments
    if not args.conn:
        print("❌ Error: No connection string provided")
        print("   Set AZURE_SQL_CONN_STR environment variable or use --conn parameter")
        sys.exit(1)

    if not args.out:
        print("❌ Error: Output file path required (--out parameter)")
        sys.exit(1)

    # Create output directory if it doesn't exist
    output_dir = os.path.dirname(args.out)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"📁 Created output directory: {output_dir}")

    # Execute extraction
    print(f"🚀 Scout Analytics Flat Dataframe Extractor v1.0")
    print(f"=" * 60)

    success, message, row_count = extract_dataframe(
        connection_string=args.conn,
        output_file=args.out,
        limit=args.limit,
        validate_schema=not args.no_validate
    )

    # Print results
    print(f"=" * 60)
    if success:
        print(f"✅ EXTRACTION SUCCESSFUL")
        print(f"📊 {row_count:,} rows exported to {args.out}")

        # Show column summary
        if not args.no_validate:
            print(f"\n📋 Column Structure (12 columns):")
            for i, col in enumerate(REQUIRED_COLUMNS, 1):
                print(f"   {i:2d}. {col}")

        print(f"\n🎯 Ready for analysis and reporting!")

    else:
        print(f"❌ EXTRACTION FAILED")
        print(f"💥 Error: {message}")
        sys.exit(1)

if __name__ == "__main__":
    main()