#!/usr/bin/env python3
"""
Quick Export Script - Simple flattened data export
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime

# Simple export based on your original script
def quick_export():
    """Quick export matching your ETL script pattern"""

    engine = sa.create_engine(
        "mssql+pyodbc://TBWA:R@nd0mPA$2025!@"
        "sqltbwaprojectscoutserver.database.windows.net/"
        "SQL-TBWA-ProjectScout-Reporting-Prod"
        "?driver=ODBC+Driver+18+for+SQL+Server&Encrypt=yes"
    )

    print("🔍 Extracting flattened transaction data...")

    # Your original query pattern
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

    # Store enrichment (your pattern)
    stores = pd.read_sql("""
      SELECT s.store_id, s.store_name, g.barangay, g.city, g.region_name, g.latitude, g.longitude
      FROM dbo.Stores s
      JOIN dbo.GeographicHierarchy g ON g.geo_id = s.geo_id
    """, engine)

    # Merge enrichment
    flat = raw.merge(stores, left_on="storeId", right_on="store_id", how="left")

    # Export timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Multiple export formats
    exports = {
        'parquet': f"scout_flat_{timestamp}.parquet",
        'csv': f"scout_flat_{timestamp}.csv",
        'json': f"scout_flat_{timestamp}.json"
    }

    for format_type, filename in exports.items():
        if format_type == 'parquet':
            flat.to_parquet(filename, index=False)
        elif format_type == 'csv':
            flat.to_csv(filename, index=False)
        elif format_type == 'json':
            flat.to_json(filename, orient='records', date_format='iso')

        print(f"✅ Exported {format_type.upper()}: {filename}")

    print(f"\n🎉 Export complete! {len(flat)} records exported")
    print(f"📊 Columns: {list(flat.columns)}")

    # Quick stats
    print(f"\n📈 Quick Stats:")
    print(f"  - Date range: {flat['timestamp'].min()} to {flat['timestamp'].max()}")
    print(f"  - Stores: {flat['storeId'].nunique()} unique stores")
    print(f"  - Total amount: ${flat['amount'].sum():,.2f}")

    return flat

if __name__ == "__main__":
    df = quick_export()