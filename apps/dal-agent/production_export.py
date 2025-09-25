#!/usr/bin/env python3
"""
Production Export Script - Real Scout production data export
Uses correct production database credentials
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime
import urllib.parse

def production_export():
    """Export real production data with correct credentials"""

    print("🔍 Connecting to Scout production database...")

    # Production database credentials (correct server and password)
    params = urllib.parse.quote_plus(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        "SERVER=sqltbwaprojectscoutserver.database.windows.net;"
        "DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;"
        "UID=TBWA;"
        "PWD=R@nd0mPA$$2025!;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
        "Connection Timeout=30;"
    )

    engine = sa.create_engine(
        f"mssql+pyodbc:///?odbc_connect={params}",
        pool_pre_ping=True,
        pool_recycle=3600
    )

    print("✅ Engine created, testing connection...")

    try:
        # Test connection first
        with engine.connect() as conn:
            test_result = conn.execute(sa.text("SELECT TOP 1 GETDATE() as server_time"))
            server_time = test_result.fetchone()[0]
            print(f"✅ Connected successfully! Server time: {server_time}")

        print("🔍 Extracting flattened transaction data...")

        # Your original query pattern with production data
        raw = pd.read_sql("""
          SELECT TOP 5000
                 canonical_tx_id, session_id as sessionId, device_id as deviceId,
                 store_id as storeId, payload_json, amount,
                 transaction_timestamp as [timestamp],
                 InteractionID, FacialID, TransactionDate
          FROM bronze.PayloadTransactions p
          LEFT JOIN dbo.SalesInteractions si
            ON si.CanonicalTxID = p.canonical_tx_id
          WHERE p.ingestion_timestamp >= DATEADD(DAY,-30,SYSUTCDATETIME())
          ORDER BY p.ingestion_timestamp DESC;
        """, engine)

        print(f"✅ Retrieved {len(raw)} transaction records")

        # Store enrichment (your pattern)
        stores = pd.read_sql("""
          SELECT s.store_id, s.store_name, g.barangay, g.city, g.region_name, g.latitude, g.longitude
          FROM dbo.Stores s
          JOIN dbo.GeographicHierarchy g ON g.geo_id = s.geo_id
        """, engine)

        print(f"✅ Retrieved {len(stores)} store records")

        # Merge enrichment
        flat = raw.merge(stores, left_on="storeId", right_on="store_id", how="left")

        print(f"✅ Merged data: {len(flat)} final records")

        # Export timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Multiple export formats
        exports = {
            'parquet': f"scout_production_{timestamp}.parquet",
            'csv': f"scout_production_{timestamp}.csv",
            'json': f"scout_production_{timestamp}.json"
        }

        for format_type, filename in exports.items():
            if format_type == 'parquet':
                flat.to_parquet(filename, index=False)
            elif format_type == 'csv':
                flat.to_csv(filename, index=False)
            elif format_type == 'json':
                flat.to_json(filename, orient='records', date_format='iso')

            print(f"✅ Exported {format_type.upper()}: {filename}")

        print(f"\n🎉 Production export complete! {len(flat)} records exported")
        print(f"📊 Columns: {list(flat.columns)}")

        # Production data stats
        if not flat.empty:
            print(f"\n📈 Production Data Stats:")
            print(f"  - Date range: {flat['timestamp'].min()} to {flat['timestamp'].max()}")
            print(f"  - Stores: {flat['storeId'].nunique()} unique stores")
            print(f"  - Total amount: ₱{flat['amount'].sum():,.2f}")
            print(f"  - Avg transaction: ₱{flat['amount'].mean():.2f}")

            # Sample records
            print(f"\n📋 Sample Production Records:")
            sample_cols = ['canonical_tx_id', 'store_name', 'amount', 'timestamp']
            if all(col in flat.columns for col in sample_cols):
                print(flat[sample_cols].head())

        return flat

    except Exception as e:
        print(f"❌ Production export failed: {e}")
        print("\n💡 Possible solutions:")
        print("- Check VPN connection if required")
        print("- Verify firewall allows outbound SQL Server connections")
        print("- Confirm server name is correct (sqltbwaprojectscoutserver.database.windows.net)")
        print("- Test connection with SQL Server Management Studio first")
        return None

    finally:
        engine.dispose()
        print("🔒 Database connection closed")

if __name__ == "__main__":
    df = production_export()