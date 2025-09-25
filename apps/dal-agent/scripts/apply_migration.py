#!/usr/bin/env python3
"""
Scout Analytics Platform - Migration Executor
Purpose: Apply SQL migrations to Scout database
Usage: python apply_migration.py --migration 006_fix_join_multiplication_final.sql
"""

import os
import argparse
import pyodbc
import sys
from pathlib import Path

def get_connection():
    """Get database connection using same settings as extract script"""
    conn_str = (
        "Driver={ODBC Driver 18 for SQL Server};"
        "Server=scout-analytics-server.database.windows.net;"
        "Database=SQL-TBWA-ProjectScout-Reporting-Prod;"
        "UID=sqladmin;"
        "PWD=Azure_pw26;"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        "Connection Timeout=30;"
    )

    try:
        conn = pyodbc.connect(conn_str)
        print("✅ Database connection successful")
        return conn
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return None

def execute_migration(conn, migration_file):
    """Execute SQL migration file"""
    try:
        with open(migration_file, 'r', encoding='utf-8') as f:
            sql_content = f.read()

        # Split by GO statements and execute each batch
        sql_batches = sql_content.split('GO')

        cursor = conn.cursor()

        for i, batch in enumerate(sql_batches):
            batch = batch.strip()
            if not batch:
                continue

            print(f"📝 Executing batch {i+1}/{len(sql_batches)}")
            try:
                cursor.execute(batch)
                conn.commit()
                print(f"✅ Batch {i+1} completed")
            except Exception as e:
                print(f"❌ Batch {i+1} failed: {e}")
                conn.rollback()
                return False

        cursor.close()
        print("✅ Migration completed successfully")
        return True

    except Exception as e:
        print(f"❌ Migration failed: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Apply SQL migration')
    parser.add_argument('--migration', required=True, help='Migration file name')

    args = parser.parse_args()

    # Build full path to migration file
    migration_file = Path(__file__).parent.parent / "sql" / "migrations" / args.migration

    if not migration_file.exists():
        print(f"❌ Migration file not found: {migration_file}")
        sys.exit(1)

    print(f"🚀 Applying migration: {args.migration}")

    # Get database connection
    conn = get_connection()
    if not conn:
        sys.exit(1)

    # Execute migration
    success = execute_migration(conn, migration_file)

    conn.close()

    if success:
        print("✅ Migration applied successfully")
        sys.exit(0)
    else:
        print("❌ Migration failed")
        sys.exit(1)

if __name__ == "__main__":
    main()