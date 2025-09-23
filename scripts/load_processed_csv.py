#!/usr/bin/env python3
"""
Load processed CSV directly into database via pyodbc
"""
import csv
import pyodbc
import os
import sys

def load_csv_to_db():
    # Database connection
    server = os.environ.get('AZSQL_HOST')
    database = os.environ.get('AZSQL_DB')
    username = os.environ.get('AZSQL_USER_ADMIN')
    password = os.environ.get('AZSQL_PASS_ADMIN')

    csv_path = 'exports/processed_payload.csv'

    if not all([server, database, username, password]):
        print("❌ Missing database credentials in environment")
        sys.exit(1)

    if not os.path.exists(csv_path):
        print(f"❌ Processed CSV not found: {csv_path}")
        sys.exit(1)

    try:
        # Connection string for Azure SQL
        conn_str = f"DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password}"
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()

        print(f"📊 Loading {csv_path} into staging table...")

        # Clear staging table
        cursor.execute("TRUNCATE TABLE dbo.PayloadTransactionsStaging_csv")

        batch_size = 100
        batch = []
        total_inserted = 0

        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)

            for row in reader:
                if len(row) >= 5:
                    source_path, txn_id, device_id, store_id, payload = row[:5]

                    # Convert store_id to int if numeric
                    store_id_val = int(store_id) if store_id.isdigit() else None

                    batch.append((source_path, txn_id, device_id, store_id_val, payload))

                    if len(batch) >= batch_size:
                        # Execute batch insert
                        cursor.executemany(
                            "INSERT INTO dbo.PayloadTransactionsStaging_csv (source_path, transactionId, deviceId, storeId, payload_json) VALUES (?, ?, ?, ?, ?)",
                            batch
                        )
                        total_inserted += len(batch)
                        batch = []

                        if total_inserted % 1000 == 0:
                            print(f"📊 Inserted {total_inserted} records...")
                            conn.commit()

        # Insert remaining batch
        if batch:
            cursor.executemany(
                "INSERT INTO dbo.PayloadTransactionsStaging_csv (source_path, transactionId, deviceId, storeId, payload_json) VALUES (?, ?, ?, ?, ?)",
                batch
            )
            total_inserted += len(batch)

        conn.commit()
        print(f"✅ Successfully inserted {total_inserted} records into staging table")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error loading CSV: {e}")
        sys.exit(1)

if __name__ == "__main__":
    load_csv_to_db()