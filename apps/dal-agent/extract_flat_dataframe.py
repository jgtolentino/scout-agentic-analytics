#!/usr/bin/env python3
"""
Scout Analytics Flat Dataframe Extractor
Extracts complete flat dataframe with all cross-tab fields from Scout Azure SQL Database
Includes co-purchases and substitution patterns
"""

import pyodbc
import pandas as pd
import os
from datetime import datetime
import json

# Database connection configuration
DB_CONFIG = {
    'server': 'sqltbwaprojectscoutserver.database.windows.net',
    'database': 'SQL-TBWA-ProjectScout-Reporting-Prod',
    'username': 'TBWA',
    'password': 'R@nd0mPA$2025!',
    'driver': '{ODBC Driver 17 for SQL Server}'
}

def get_connection():
    """Create database connection"""
    conn_str = f"""
        DRIVER={DB_CONFIG['driver']};
        SERVER={DB_CONFIG['server']};
        DATABASE={DB_CONFIG['database']};
        UID={DB_CONFIG['username']};
        PWD={DB_CONFIG['password']};
        Encrypt=yes;
        TrustServerCertificate=no;
        Connection Timeout=30;
    """
    return pyodbc.connect(conn_str)

def format_time_of_transaction(timestamp):
    """Format timestamp as '8AM', '2PM', etc."""
    if pd.isna(timestamp):
        return ""
    try:
        dt = pd.to_datetime(timestamp)
        hour = dt.hour
        if hour == 0:
            return "12AM"
        elif hour < 12:
            return f"{hour}AM"
        elif hour == 12:
            return "12PM"
        else:
            return f"{hour-12}PM"
    except:
        return ""

def get_co_purchased_items(conn, transaction_id, primary_brand):
    """Get other products bought in the same transaction"""
    try:
        query = """
        SELECT DISTINCT
            COALESCE(ti.product_name, ti.sku_name, '') as product,
            COALESCE(ti.brand_detected, '') as brand,
            COALESCE(ti.category_detected, '') as category
        FROM dbo.TransItems ti
        INNER JOIN dbo.Transactions t ON ti.transaction_id = t.transaction_id
        WHERE t.canonical_tx_id = ?
        AND COALESCE(ti.brand_detected, '') != ?
        AND COALESCE(ti.product_name, ti.sku_name, '') != ''
        """

        df = pd.read_sql(query, conn, params=[transaction_id, primary_brand or ''])

        if df.empty:
            return ""

        # Format as "Brand (Category)" or just product name
        items = []
        for _, row in df.iterrows():
            if row['brand'] and row['category']:
                items.append(f"{row['brand']} ({row['category']})")
            elif row['brand']:
                items.append(row['brand'])
            elif row['product']:
                items.append(row['product'])

        return ", ".join(items[:5])  # Limit to 5 items
    except Exception as e:
        print(f"Warning: Could not get co-purchased items for {transaction_id}: {e}")
        return ""

def extract_flat_dataframe():
    """Extract the complete flat dataframe"""

    print("🔌 Connecting to Scout Azure SQL Database...")

    try:
        conn = get_connection()
        print("✅ Connected successfully!")

        print("📊 Extracting flat dataframe with all cross-tab fields...")

        # Main query to get transaction data with demographics and substitutions
        main_query = """
        WITH transaction_base AS (
            SELECT
                p.canonical_tx_id,
                p.transaction_id,
                p.txn_ts as transaction_timestamp,
                p.total_amount as transaction_value,
                p.total_items as basket_size,
                p.category,
                p.brand,
                p.daypart,
                p.weekday_weekend,
                p.store_name,
                DATEPART(HOUR, p.txn_ts) as hour_of_day
            FROM dbo.v_transactions_flat_production p
            WHERE p.total_amount > 0
        ),
        enriched_data AS (
            SELECT
                tb.*,
                vib.age_bracket,
                vib.gender,
                vib.customer_type,
                vib.substitution_event,
                vib.substitution_reason,
                vib.suggestion_accepted,
                -- Geographic info
                s.MunicipalityName,
                s.Region,
                s.ProvinceName
            FROM transaction_base tb
            LEFT JOIN dbo.v_insight_base vib ON tb.canonical_tx_id = vib.sessionId
            LEFT JOIN dbo.Stores s ON tb.canonical_tx_id IN (
                SELECT canonical_tx_id
                FROM dbo.Transactions t2
                WHERE t2.store_id = s.StoreID
            )
        )
        SELECT *
        FROM enriched_data
        ORDER BY transaction_timestamp
        """

        print("⏳ Executing main query...")
        df = pd.read_sql(main_query, conn)
        print(f"📈 Found {len(df)} transactions")

        if df.empty:
            print("❌ No data found!")
            return

        print("🔧 Processing and formatting data...")

        # Format Demographics (Age/Gender/Role)
        df['demographics'] = df.apply(lambda row: " ".join(filter(None, [
            str(row.get('age_bracket', '')).strip(),
            str(row.get('gender', '')).strip(),
            str(row.get('customer_type', '')).strip()
        ])).strip(), axis=1)

        # Format Time of transaction
        df['time_formatted'] = df['transaction_timestamp'].apply(format_time_of_transaction)

        # Format Location (prefer municipality, fallback to store_name)
        df['location'] = df.apply(lambda row:
            str(row.get('MunicipalityName', '') or row.get('store_name', '')).strip(), axis=1)

        # Format substitution flag
        df['was_substitution'] = df.apply(lambda row:
            "true" if str(row.get('substitution_event', '')).lower() in ['true', '1', 'yes'] or
                     str(row.get('substitution_reason', '')).strip() != '' else "false", axis=1)

        print("🛒 Extracting co-purchased products...")

        # Get co-purchased items (this will be slow but accurate)
        df['co_purchases'] = ""
        for idx, row in df.iterrows():
            if idx % 100 == 0:
                print(f"  Processing transaction {idx + 1}/{len(df)}")

            co_items = get_co_purchased_items(conn, row['canonical_tx_id'], row['brand'])
            df.at[idx, 'co_purchases'] = co_items

        print("📝 Finalizing dataframe structure...")

        # Create final dataframe with exact column names
        final_df = pd.DataFrame({
            'Transaction_ID': df['canonical_tx_id'],
            'Transaction_Value': df['transaction_value'].round(2),
            'Basket_Size': df['basket_size'].fillna(0).astype(int),
            'Category': df['category'].fillna(''),
            'Brand': df['brand'].fillna(''),
            'Daypart': df['daypart'].fillna(''),
            'Demographics (Age/Gender/Role)': df['demographics'],
            'Weekday_vs_Weekend': df['weekday_weekend'].fillna(''),
            'Time of transaction': df['time_formatted'],
            'Location': df['location'],
            'Were there other product bought with it? What? [NOT SURE IF KAYA BA NATIN TO?]': df['co_purchases'],
            'Was there substitution? [NOT SURE IF KAYA BA NATIN TO?]': df['was_substitution']
        })

        # Export to CSV
        output_file = '/Users/tbwa/scout-v7/apps/dal-agent/exports/flat_dataframe_complete.csv'
        os.makedirs(os.path.dirname(output_file), exist_ok=True)

        final_df.to_csv(output_file, index=False)

        print(f"🎉 Successfully exported {len(final_df)} transactions to {output_file}")
        print("\n📊 Data Summary:")
        print(f"  Total Transactions: {len(final_df):,}")
        print(f"  Total Revenue: ₱{final_df['Transaction_Value'].sum():,.2f}")
        print(f"  Unique Brands: {final_df['Brand'].nunique()}")
        print(f"  Unique Categories: {final_df['Category'].nunique()}")
        print(f"  Transactions with Co-purchases: {len(final_df[final_df['Were there other product bought with it? What? [NOT SURE IF KAYA BA NATIN TO?]'] != ''])}")
        print(f"  Transactions with Substitutions: {len(final_df[final_df['Was there substitution? [NOT SURE IF KAYA BA NATIN TO?]'] == 'true'])}")

        print("\n📋 Sample data (first 3 rows):")
        print(final_df.head(3).to_string())

        conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    extract_flat_dataframe()