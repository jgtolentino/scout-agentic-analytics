#!/usr/bin/env python3
"""
Fixed Export Script - Database export with proper timeout handling
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime
import urllib.parse

def create_robust_engine():
    """Create database engine with proper timeout and connection settings"""

    # Connection parameters with timeout settings
    params = urllib.parse.quote_plus(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        "SERVER=sqltbwaproductscoutserver.database.windows.net;"
        "DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;"
        "UID=TBWA;"
        "PWD=R@nd0mPA$2025!;"
        "Encrypt=yes;"
        "TrustServerCertificate=no;"
        "Connection Timeout=30;"
        "Command Timeout=60;"
        "Login Timeout=30"
    )

    connection_string = f"mssql+pyodbc:///?odbc_connect={params}"

    # Engine with connection pool settings
    engine = sa.create_engine(
        connection_string,
        pool_pre_ping=True,
        pool_recycle=3600,
        connect_args={
            "timeout": 30,
            "autocommit": True
        }
    )

    return engine

def test_connection():
    """Test database connection before attempting data export"""

    try:
        print("🔍 Testing database connection...")
        engine = create_robust_engine()

        # Simple test query
        with engine.connect() as conn:
            result = conn.execute(sa.text("SELECT TOP 1 GETDATE() as current_time"))
            row = result.fetchone()
            print(f"✅ Connection successful! Server time: {row[0]}")
            return engine

    except Exception as e:
        print(f"❌ Connection failed: {e}")
        print("\n💡 Try these solutions:")
        print("1. Check VPN connection if required")
        print("2. Verify firewall allows SQL Server connections")
        print("3. Confirm database credentials are correct")
        print("4. Use mock_export.py for testing instead")
        return None

def export_with_robust_connection():
    """Export data with robust error handling and connection management"""

    engine = test_connection()
    if not engine:
        print("❌ Cannot establish database connection. Use mock_export.py instead.")
        return None

    try:
        print("🔍 Extracting flattened transaction data...")

        # Use smaller batch for initial test
        query = """
        SELECT TOP 1000
               canonical_tx_id,
               session_id as sessionId,
               device_id as deviceId,
               store_id as storeId,
               payload_json,
               amount,
               transaction_timestamp as [timestamp],
               InteractionID,
               FacialID,
               TransactionDate
        FROM bronze.PayloadTransactions p
        LEFT JOIN dbo.SalesInteractions si
          ON si.CanonicalTxID = p.canonical_tx_id
        WHERE p.ingestion_timestamp >= DATEADD(DAY,-7,SYSUTCDATETIME())
        ORDER BY p.ingestion_timestamp DESC;
        """

        # Execute with timeout handling
        with engine.connect() as conn:
            raw = pd.read_sql(query, conn)

        print(f"✅ Retrieved {len(raw)} transaction records")

        # Store enrichment query
        store_query = """
        SELECT s.store_id, s.store_name, g.barangay, g.city, g.region_name, g.latitude, g.longitude
        FROM dbo.Stores s
        JOIN dbo.GeographicHierarchy g ON g.geo_id = s.geo_id
        """

        with engine.connect() as conn:
            stores = pd.read_sql(store_query, conn)

        print(f"✅ Retrieved {len(stores)} store records")

        # Merge enrichment
        flat = raw.merge(stores, left_on="storeId", right_on="store_id", how="left")

        # Export with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Export formats
        exports = {
            'parquet': f"scout_flat_real_{timestamp}.parquet",
            'csv': f"scout_flat_real_{timestamp}.csv",
            'json': f"scout_flat_real_{timestamp}.json"
        }

        for format_type, filename in exports.items():
            if format_type == 'parquet':
                flat.to_parquet(filename, index=False)
            elif format_type == 'csv':
                flat.to_csv(filename, index=False)
            elif format_type == 'json':
                flat.to_json(filename, orient='records', date_format='iso')

            print(f"✅ Exported {format_type.upper()}: {filename}")

        # Stats
        print(f"\n🎉 Export complete! {len(flat)} records exported")
        print(f"📊 Columns: {list(flat.columns)}")

        if not flat.empty:
            print(f"\n📈 Quick Stats:")
            print(f"  - Date range: {flat['timestamp'].min()} to {flat['timestamp'].max()}")
            print(f"  - Stores: {flat['storeId'].nunique()} unique stores")
            print(f"  - Total amount: ₱{flat['amount'].sum():,.2f}")

        return flat

    except Exception as e:
        print(f"❌ Export failed: {e}")
        print("💡 Falling back to mock data generation...")

        # Import and run mock export as fallback
        from mock_export import export_mock_data
        return export_mock_data()

    finally:
        if engine:
            engine.dispose()

if __name__ == "__main__":
    df = export_with_robust_connection()