#!/usr/bin/env python3
"""
Test Azure SQL Connection
Quick test to verify Azure SQL connectivity and basic queries
"""

import os
import pyodbc
import pandas as pd
from datetime import datetime

def test_connection():
    """Test Azure SQL connection and basic queries"""

    # Load configuration
    config = {
        'server': os.getenv('AZSQL_HOST', 'scout-analytics-server.database.windows.net'),
        'database': os.getenv('AZSQL_DB', 'scout-analytics'),
        'username': os.getenv('AZSQL_USER', 'sqladmin'),
        'password': os.getenv('AZSQL_PASS', 'Azure_pw26'),
        'driver': '{ODBC Driver 18 for SQL Server}'
    }

    connection_string = (
        f"DRIVER={config['driver']};"
        f"SERVER={config['server']};"
        f"DATABASE={config['database']};"
        f"UID={config['username']};"
        f"PWD={config['password']};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=yes;"
        f"Connection Timeout=60;"
        f"LoginTimeout=60;"
    )

    try:
        print("🔌 Testing Azure SQL connection...")
        conn = pyodbc.connect(connection_string)
        print("✅ Connection successful!")

        # Test basic query
        print("🔍 Testing basic query...")
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()[0]
        print(f"📊 SQL Server Version: {version[:50]}...")

        # Test schema access
        print("🗂️  Testing schema access...")
        cursor.execute("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'gold'")
        gold_tables = cursor.fetchone()[0]
        print(f"📋 Gold schema tables: {gold_tables}")

        # Test flat export view if it exists
        try:
            cursor.execute("SELECT COUNT(*) FROM gold.v_flat_export_ready")
            record_count = cursor.fetchone()[0]
            print(f"📊 Flat export view records: {record_count:,}")
        except Exception as e:
            print(f"⚠️  Flat export view not accessible: {str(e)}")

        cursor.close()
        conn.close()
        print("✅ All tests passed!")
        return True

    except Exception as e:
        print(f"❌ Connection test failed: {str(e)}")
        return False

if __name__ == "__main__":
    success = test_connection()
    exit(0 if success else 1)