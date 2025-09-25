#!/usr/bin/env python3
"""
Scout Data Export Utility
Exports flattened transaction data in multiple formats
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime, timedelta
import json
import os
from pathlib import Path

# Database connection
def get_engine():
    """Create database engine with Scout production credentials"""
    connection_string = (
        "mssql+pyodbc://TBWA:R@nd0mPA$2025!@"
        "sqltbwaprojectscoutserver.database.windows.net/"
        "SQL-TBWA-ProjectScout-Reporting-Prod"
        "?driver=ODBC+Driver+18+for+SQL+Server&Encrypt=yes"
    )
    return sa.create_engine(connection_string)

def export_flattened_data(days_back=30, limit=10000, export_formats=['parquet', 'csv', 'json']):
    """
    Export flattened Scout transaction data

    Args:
        days_back (int): Number of days to look back
        limit (int): Maximum number of records
        export_formats (list): List of formats to export ['parquet', 'csv', 'json', 'xlsx']
    """

    engine = get_engine()

    print(f"🔍 Extracting {limit} records from last {days_back} days...")

    # Query flattened data from gold layer if available, otherwise raw + flatten
    try:
        # First try gold layer
        query_gold = """
        SELECT TOP {limit}
               id as canonical_tx_id,
               peso_value as amount,
               timestamp,
               store_id,
               brand_name,
               product_category,
               longitude,
               latitude,
               location_city
        FROM gold.scout_dashboard_transactions
        WHERE timestamp >= DATEADD(DAY, -{days}, GETUTCDATE())
        ORDER BY timestamp DESC
        """.format(limit=limit, days=days_back)

        df = pd.read_sql(query_gold, engine)
        print(f"✅ Retrieved {len(df)} records from gold.scout_dashboard_transactions")

    except Exception as e:
        print(f"⚠️  Gold layer not available ({e}), using raw data...")

        # Fallback to raw data with flattening
        query_raw = """
        SELECT TOP {limit}
               p.canonical_tx_id,
               p.session_id as sessionId,
               p.device_id as deviceId,
               p.store_id,
               p.payload_json,
               p.amount,
               p.transaction_timestamp as timestamp,
               si.InteractionID,
               si.FacialID,
               si.TransactionDate,
               s.store_name,
               g.barangay,
               g.city,
               g.region_name as location_city,
               g.latitude,
               g.longitude
        FROM bronze.PayloadTransactions p
        LEFT JOIN dbo.SalesInteractions si ON si.CanonicalTxID = p.canonical_tx_id
        LEFT JOIN dbo.Stores s ON s.store_id = p.store_id
        LEFT JOIN dbo.GeographicHierarchy g ON g.geo_id = s.geo_id
        WHERE p.ingestion_timestamp >= DATEADD(DAY, -{days}, GETUTCDATE())
        ORDER BY p.ingestion_timestamp DESC
        """.format(limit=limit, days=days_back)

        df = pd.read_sql(query_raw, engine)
        print(f"✅ Retrieved {len(df)} records from bronze layer with enrichments")

    # Create exports directory
    export_dir = Path("exports")
    export_dir.mkdir(exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base_filename = f"scout_flattened_data_{timestamp}"

    exported_files = []

    # Export in requested formats
    if 'parquet' in export_formats:
        parquet_file = export_dir / f"{base_filename}.parquet"
        df.to_parquet(parquet_file, index=False)
        exported_files.append(str(parquet_file))
        print(f"📦 Exported Parquet: {parquet_file}")

    if 'csv' in export_formats:
        csv_file = export_dir / f"{base_filename}.csv"
        df.to_csv(csv_file, index=False)
        exported_files.append(str(csv_file))
        print(f"📊 Exported CSV: {csv_file}")

    if 'json' in export_formats:
        json_file = export_dir / f"{base_filename}.json"
        df.to_json(json_file, orient='records', date_format='iso')
        exported_files.append(str(json_file))
        print(f"📄 Exported JSON: {json_file}")

    if 'xlsx' in export_formats:
        xlsx_file = export_dir / f"{base_filename}.xlsx"
        df.to_excel(xlsx_file, index=False)
        exported_files.append(str(xlsx_file))
        print(f"📈 Exported Excel: {xlsx_file}")

    # Export summary stats
    summary_file = export_dir / f"{base_filename}_summary.json"
    summary = {
        'export_timestamp': datetime.now().isoformat(),
        'total_records': len(df),
        'date_range': {
            'from': df['timestamp'].min().isoformat() if not df.empty else None,
            'to': df['timestamp'].max().isoformat() if not df.empty else None
        },
        'columns': list(df.columns),
        'data_types': df.dtypes.astype(str).to_dict(),
        'null_counts': df.isnull().sum().to_dict(),
        'exported_files': exported_files
    }

    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2, default=str)

    print(f"📋 Export summary: {summary_file}")
    print(f"\n🎉 Successfully exported {len(df)} records to {len(exported_files)} files")

    return df, exported_files

def export_brand_analysis():
    """Export brand performance analysis"""

    engine = get_engine()

    print("🏷️  Exporting brand analysis...")

    # Brand performance with ownership flags
    brand_query = """
    SELECT
           b.brand_name,
           CAST(CASE WHEN br.is_owned = 1 THEN 1 ELSE 0 END AS bit) AS is_owned,
           COUNT(*) as transaction_count,
           SUM(t.peso_value) as total_revenue,
           AVG(t.peso_value) as avg_transaction,
           MIN(t.timestamp) as first_transaction,
           MAX(t.timestamp) as last_transaction
    FROM gold.scout_dashboard_transactions t
    JOIN (SELECT DISTINCT brand_name FROM gold.scout_dashboard_transactions WHERE brand_name IS NOT NULL) b
         ON b.brand_name = t.brand_name
    LEFT JOIN dbo.brands_ref br ON br.brand_name = b.brand_name
    WHERE t.timestamp >= DATEADD(DAY, -30, GETUTCDATE())
    GROUP BY b.brand_name, br.is_owned
    ORDER BY total_revenue DESC
    """

    brands_df = pd.read_sql(brand_query, engine)

    # Export brand analysis
    export_dir = Path("exports")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    brand_file = export_dir / f"scout_brand_analysis_{timestamp}.csv"
    brands_df.to_csv(brand_file, index=False)

    print(f"🏷️  Brand analysis exported: {brand_file}")
    return brands_df

if __name__ == "__main__":
    # Export flattened data in multiple formats
    df, files = export_flattened_data(
        days_back=30,
        limit=10000,
        export_formats=['parquet', 'csv', 'json']
    )

    # Export brand analysis
    brands_df = export_brand_analysis()

    print("\n📊 Export Complete!")
    print(f"Transaction records: {len(df)}")
    print(f"Brand records: {len(brands_df)}")
    print(f"Files created: {len(files) + 1}")