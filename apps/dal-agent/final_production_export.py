#!/usr/bin/env python3
"""
Final Production Export - Real Scout production data with correct table names
"""

import pandas as pd
import sqlalchemy as sa
from datetime import datetime
import urllib.parse

def final_production_export():
    """Export real production data using correct table names from database exploration"""

    print("🔍 Connecting to Scout production database...")

    # Production database credentials
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

    try:
        # Test connection
        with engine.connect() as conn:
            test_result = conn.execute(sa.text("SELECT TOP 1 GETDATE() as server_time"))
            server_time = test_result.fetchone()[0]
            print(f"✅ Connected successfully! Server time: {server_time}")

        print("🔍 Extracting real production data...")

        # Option 1: Use the gold layer table (our DAL agent uses this)
        print("\n📊 Attempting to extract from gold.scout_dashboard_transactions...")
        try:
            gold_data = pd.read_sql("""
                SELECT TOP 5000
                       id as canonical_tx_id,
                       store_id,
                       timestamp,
                       location_city,
                       location_barangay,
                       location_province,
                       location_region,
                       brand_name,
                       product_category,
                       peso_value as amount,
                       basket_size,
                       gender,
                       age_bracket,
                       payment_method,
                       customer_type
                FROM gold.scout_dashboard_transactions
                WHERE timestamp >= DATEADD(DAY, -30, GETUTCDATE())
                ORDER BY timestamp DESC
            """, engine)

            print(f"✅ Retrieved {len(gold_data)} records from gold layer")

            if not gold_data.empty:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                exports = {
                    'parquet': f"scout_gold_production_{timestamp}.parquet",
                    'csv': f"scout_gold_production_{timestamp}.csv",
                    'json': f"scout_gold_production_{timestamp}.json"
                }

                for format_type, filename in exports.items():
                    if format_type == 'parquet':
                        gold_data.to_parquet(filename, index=False)
                    elif format_type == 'csv':
                        gold_data.to_csv(filename, index=False)
                    elif format_type == 'json':
                        gold_data.to_json(filename, orient='records', date_format='iso')

                    print(f"✅ Exported {format_type.upper()}: {filename}")

                print(f"\n🎉 Gold layer export complete! {len(gold_data)} records")
                print(f"📊 Columns: {list(gold_data.columns)}")

                # Stats
                print(f"\n📈 Production Data Stats:")
                print(f"  - Date range: {gold_data['timestamp'].min()} to {gold_data['timestamp'].max()}")
                print(f"  - Stores: {gold_data['store_id'].nunique()} unique stores")
                print(f"  - Brands: {gold_data['brand_name'].nunique()} unique brands")
                print(f"  - Total revenue: ₱{gold_data['amount'].sum():,.2f}")
                print(f"  - Avg transaction: ₱{gold_data['amount'].mean():.2f}")

                # Sample records
                print(f"\n📋 Sample Production Records:")
                sample_cols = ['canonical_tx_id', 'location_city', 'brand_name', 'amount', 'timestamp']
                print(gold_data[sample_cols].head())

                return gold_data

        except Exception as e:
            print(f"❌ Gold layer extraction failed: {e}")

        # Option 2: Raw PayloadTransactions with enrichment (fallback)
        print("\n📊 Attempting raw PayloadTransactions extraction...")
        try:
            raw_data = pd.read_sql("""
                SELECT TOP 2000
                       p.canonical_tx_id,
                       p.sessionId,
                       p.deviceId,
                       p.storeId,
                       p.amount,
                       p.payload_json,
                       si.InteractionID,
                       si.FacialID,
                       si.TransactionDate,
                       si.Age,
                       si.Sex as Gender
                FROM dbo.PayloadTransactions p
                LEFT JOIN dbo.SalesInteractions si
                  ON si.CanonicalTxID = p.canonical_tx_id
                ORDER BY p.canonical_tx_id DESC
            """, engine)

            print(f"✅ Retrieved {len(raw_data)} raw transaction records")

            # Add store information
            stores = pd.read_sql("""
                SELECT StoreID, StoreName, Region, ProvinceName, MunicipalityName, BarangayName, GeoLatitude, GeoLongitude
                FROM dbo.v_transactions_flat_v24
                GROUP BY StoreID, StoreName, Region, ProvinceName, MunicipalityName, BarangayName, GeoLatitude, GeoLongitude
            """, engine)

            # Merge store data
            enriched = raw_data.merge(
                stores,
                left_on='storeId',
                right_on='StoreID',
                how='left'
            )

            print(f"✅ Enriched with store data: {len(enriched)} records")

            if not enriched.empty:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                exports = {
                    'parquet': f"scout_raw_production_{timestamp}.parquet",
                    'csv': f"scout_raw_production_{timestamp}.csv",
                    'json': f"scout_raw_production_{timestamp}.json"
                }

                for format_type, filename in exports.items():
                    if format_type == 'parquet':
                        enriched.to_parquet(filename, index=False)
                    elif format_type == 'csv':
                        enriched.to_csv(filename, index=False)
                    elif format_type == 'json':
                        enriched.to_json(filename, orient='records', date_format='iso')

                    print(f"✅ Exported {format_type.upper()}: {filename}")

                print(f"\n🎉 Raw data export complete! {len(enriched)} records")
                return enriched

        except Exception as e:
            print(f"❌ Raw data extraction also failed: {e}")

        return None

    except Exception as e:
        print(f"❌ Production export failed: {e}")
        return None

    finally:
        engine.dispose()
        print("🔒 Database connection closed")

if __name__ == "__main__":
    df = final_production_export()