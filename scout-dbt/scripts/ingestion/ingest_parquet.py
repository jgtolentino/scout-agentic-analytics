#!/usr/bin/env python3
"""
Dual-target Parquet ingestion for Scout dbt
Loads from Azure Blob Storage to both Supabase and Azure SQL
"""

import os
import sys
import pandas as pd
import pyarrow.parquet as pq
from azure.storage.blob import BlobServiceClient
import psycopg2
import pyodbc
from datetime import datetime
import hashlib
import json

def get_canonical_id(row):
    """Generate canonical transaction ID using MD5 hash"""
    key = f"{row['transaction_id']}_{row['store_id']}_{row['transaction_date']}"
    return hashlib.md5(key.encode()).hexdigest()

def load_parquet_from_blob(container_name, blob_pattern):
    """Load Parquet files from Azure Blob Storage"""
    blob_service = BlobServiceClient.from_connection_string(
        os.environ['AZURE_STORAGE_CONNECTION_STRING']
    )

    container = blob_service.get_container_client(container_name)
    blobs = container.list_blobs(name_starts_with=blob_pattern)

    dfs = []
    for blob in blobs:
        blob_client = container.get_blob_client(blob.name)
        stream = blob_client.download_blob().readall()
        df = pd.read_parquet(stream)
        df['_source_file'] = blob.name
        df['_ingested_at'] = datetime.utcnow()
        dfs.append(df)

    if dfs:
        return pd.concat(dfs, ignore_index=True)
    return pd.DataFrame()

def load_to_supabase(df, table_name):
    """Load DataFrame to Supabase PostgreSQL"""
    conn = psycopg2.connect(
        host=os.environ['SUPABASE_HOST'],
        port=6543,
        database='postgres',
        user=os.environ['SUPABASE_USER'],
        password=os.environ['SUPABASE_PASS']
    )

    cur = conn.cursor()

    # Create staging table
    cur.execute(f"""
        CREATE TEMP TABLE staging_{table_name} (LIKE bronze.{table_name} INCLUDING ALL);
    """)

    # Bulk insert using COPY
    from io import StringIO
    output = StringIO()
    df.to_csv(output, sep='\\t', header=False, index=False, na_rep='\\N')
    output.seek(0)
    cur.copy_from(output, f'staging_{table_name}', null='\\N')

    # Merge into target
    cur.execute(f"""
        INSERT INTO bronze.{table_name}
        SELECT * FROM staging_{table_name}
        ON CONFLICT (canonical_id) DO UPDATE
        SET _ingested_at = EXCLUDED._ingested_at;
    """)

    conn.commit()
    cur.close()
    conn.close()

    print(f"✅ Loaded {len(df)} rows to Supabase bronze.{table_name}")

def load_to_azure(df, table_name):
    """Load DataFrame to Azure SQL Server"""
    conn = pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={os.environ['AZURE_SERVER']};"
        f"DATABASE={os.environ['AZURE_DATABASE']};"
        f"UID={os.environ['AZURE_USERNAME']};"
        f"PWD={os.environ['AZURE_PASSWORD']}"
    )

    cursor = conn.cursor()

    # Batch insert with proper type conversion
    for _, row in df.iterrows():
        cursor.execute(f"""
            MERGE bronze.{table_name} AS target
            USING (VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?))
                AS source (canonical_id, transaction_id, store_id, device_id,
                           transaction_date, transaction_time, basket_size,
                           total_amount, payment_method, customer_type,
                           municipality, barangay, latitude, longitude,
                           data_source, _ingested_at)
            ON target.canonical_id = source.canonical_id
            WHEN MATCHED THEN
                UPDATE SET _ingested_at = source._ingested_at
            WHEN NOT MATCHED THEN
                INSERT (canonical_id, transaction_id, store_id, device_id,
                       transaction_date, transaction_time, basket_size,
                       total_amount, payment_method, customer_type,
                       municipality, barangay, latitude, longitude,
                       data_source, _ingested_at)
                VALUES (source.canonical_id, source.transaction_id,
                       source.store_id, source.device_id,
                       source.transaction_date, source.transaction_time,
                       source.basket_size, source.total_amount,
                       source.payment_method, source.customer_type,
                       source.municipality, source.barangay,
                       source.latitude, source.longitude,
                       source.data_source, source._ingested_at);
        """, row['canonical_id'], row['transaction_id'], row['store_id'],
        row['device_id'], row['transaction_date'], row['transaction_time'],
        row['basket_size'], row['total_amount'], row['payment_method'],
        row['customer_type'], row['municipality'], row['barangay'],
        row['latitude'], row['longitude'], row['data_source'],
        row['_ingested_at'])

    conn.commit()
    cursor.close()
    conn.close()

    print(f"✅ Loaded {len(df)} rows to Azure SQL bronze.{table_name}")

def main():
    """Main ingestion orchestration"""
    print("🚀 Starting dual-target Parquet ingestion...")

    # Load data from blob
    df = load_parquet_from_blob('bronze', 'transactions/')

    if df.empty:
        print("⚠️ No new data to process")
        return

    # Add canonical ID
    df['canonical_id'] = df.apply(get_canonical_id, axis=1)

    # Load to both targets
    try:
        load_to_supabase(df, 'transactions')
        load_to_azure(df, 'transactions')
        print("✅ Dual-target ingestion complete")
    except Exception as e:
        print(f"❌ Ingestion failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
