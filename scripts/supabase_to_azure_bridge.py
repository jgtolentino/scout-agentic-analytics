#!/usr/bin/env python3
"""
Supabase-to-Azure Data Bridge
Extract real production data from Supabase and format for Azure flat export
"""

import os
import pandas as pd
import psycopg2
from datetime import datetime, timezone
import json
import logging
from typing import Dict, Any, Optional

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SupabaseToAzureBridge:
    """Bridge real production data from Supabase to Azure flat export format"""

    def __init__(self):
        self.supabase_config = self._load_supabase_config()
        self.export_timestamp = datetime.now(timezone.utc)

    def _load_supabase_config(self) -> Dict[str, str]:
        """Load Supabase configuration"""
        return {
            'host': 'aws-0-ap-southeast-1.pooler.supabase.com',
            'port': '6543',
            'database': 'postgres',
            'user': 'postgres.cxzllzyxwpyptfretryc',
            'password': os.getenv('SUPABASE_PASS', 'Postgres_26'),
        }

    def connect_supabase(self):
        """Connect to Supabase production database"""
        try:
            connection_string = (
                f"host={self.supabase_config['host']} "
                f"port={self.supabase_config['port']} "
                f"dbname={self.supabase_config['database']} "
                f"user={self.supabase_config['user']} "
                f"password={self.supabase_config['password']}"
            )

            conn = psycopg2.connect(connection_string)
            logger.info("✅ Connected to Supabase production database")
            return conn

        except Exception as e:
            logger.error(f"❌ Supabase connection failed: {str(e)}")
            return None

    def extract_production_data(self, conn, limit: Optional[int] = None) -> pd.DataFrame:
        """Extract real production data from Supabase scout_gold_transactions_flat"""

        limit_clause = f"LIMIT {limit}" if limit else ""

        query = f"""
        SELECT
            canonical_tx_id,
            brand,
            store,
            CAST(storeid AS text) as storeid_text,
            device,
            deviceid,
            total_price,
            ts_ph,
            date_ph,
            transaction_id,
            source,
            confidence_score,
            age,
            gender,
            emotion
        FROM public.scout_gold_transactions_flat
        WHERE total_price IS NOT NULL
          AND total_price > 0
          AND ts_ph IS NOT NULL
        ORDER BY ts_ph DESC
        {limit_clause}
        """

        logger.info(f"🔍 Extracting production data from Supabase...")
        df = pd.read_sql(query, conn)
        logger.info(f"📊 Extracted {len(df):,} production records")

        return df

    def transform_to_flat_export_format(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform Supabase data to Azure flat export format (19 columns)"""

        logger.info("🔄 Transforming to flat export format...")

        # Create the 19-column flat export format
        transformed_df = pd.DataFrame()

        # Core transaction identifiers
        transformed_df['Transaction_ID'] = df['canonical_tx_id'].fillna(df['transaction_id'])
        transformed_df['Transaction_Value'] = df['total_price'].fillna(0.0)
        transformed_df['Basket_Size'] = 1  # Default, can be enhanced later

        # Product dimensions - USE REAL PRODUCTION DATA
        transformed_df['Category'] = self._categorize_brands(df['brand'])
        transformed_df['Brand'] = df['brand'].fillna('Unknown')

        # Time dimensions
        transformed_df['Daypart'] = df['ts_ph'].apply(self._calculate_daypart)
        transformed_df['Weekday_vs_Weekend'] = df['ts_ph'].apply(self._calculate_weekday_weekend)
        transformed_df['Time_of_transaction'] = df['ts_ph'].dt.strftime('%H:%M')

        # Demographics from production data
        transformed_df['Demographics (Age/Gender/Role)'] = self._format_demographics(df)
        transformed_df['Emotions'] = df['emotion'].fillna('Neutral')

        # Location from store mapping
        transformed_df['Location'] = df['store'].fillna('Unknown')

        # Product associations (simplified for now)
        transformed_df['Other_products_bought'] = transformed_df['Category']
        transformed_df['Was_there_substitution'] = 'No'  # Default, can be enhanced

        # Store and device information
        transformed_df['StoreID'] = df['storeid']
        transformed_df['Timestamp'] = df['ts_ph']
        transformed_df['FacialID'] = 'FACE_' + df['canonical_tx_id'].str[:8]
        transformed_df['DeviceID'] = df['deviceid'].fillna('UNKNOWN')

        # Quality and source metadata
        transformed_df['Data_Quality_Score'] = df['confidence_score'].fillna(75.0)
        transformed_df['Data_Source'] = 'Supabase_Production_Data'

        logger.info(f"✅ Transformed {len(transformed_df):,} records to flat export format")
        return transformed_df

    def _categorize_brands(self, brands: pd.Series) -> pd.Series:
        """Categorize brands based on real production patterns"""

        category_mapping = {
            # Real Filipino brands from production data
            'Safeguard': 'Body Care',
            'Jack \'n Jill': 'Snacks & Confectionery',
            'Piattos': 'Salty Snacks (Chichirya)',
            'Combi': 'Candies & Sweets',
            'Pantene': 'Hair Care',
            'Head & Shoulders': 'Hair Care',
            'Close Up': 'Oral Care',
            'Cream Silk': 'Hair Care',
            'Gatorade': 'Beverages',
            'C2': 'Non-Alcoholic',
            'Coca-Cola': 'Non-Alcoholic',
            # Add more mappings as needed
        }

        # Apply category mapping, default to 'Other Essentials'
        return brands.map(category_mapping).fillna('Other Essentials')

    def _calculate_daypart(self, timestamp) -> str:
        """Calculate daypart from timestamp"""
        if pd.isna(timestamp):
            return 'Unknown'

        hour = timestamp.hour
        if 5 <= hour <= 10:
            return 'Morning'
        elif 11 <= hour <= 14:
            return 'Midday'
        elif 15 <= hour <= 18:
            return 'Afternoon'
        elif 19 <= hour <= 22:
            return 'Evening'
        else:
            return 'LateNight'

    def _calculate_weekday_weekend(self, timestamp) -> str:
        """Calculate weekday vs weekend"""
        if pd.isna(timestamp):
            return 'Unknown'
        return 'Weekend' if timestamp.weekday() >= 5 else 'Weekday'

    def _format_demographics(self, df: pd.DataFrame) -> pd.Series:
        """Format demographics from age/gender data"""
        def format_demo(row):
            age = row.get('age', 'Unknown')
            gender = row.get('gender', 'Unknown')

            # Categorize age
            if pd.isna(age) or age == 'Unknown':
                age_cat = 'Unknown'
            elif age < 18:
                age_cat = 'Teen'
            elif age < 35:
                age_cat = 'Young Adult'
            elif age < 55:
                age_cat = 'Adult'
            else:
                age_cat = 'Senior'

            return f"{age_cat}/{gender}/Customer"

        return df.apply(format_demo, axis=1)

    def export_to_csv(self, df: pd.DataFrame, filename_prefix: str = "supabase_flat_export") -> Dict[str, Any]:
        """Export transformed data to CSV"""

        # Generate filename with timestamp
        timestamp_str = self.export_timestamp.strftime('%Y%m%d_%H%M%S')
        filename = f"{filename_prefix}_{timestamp_str}.csv"
        filepath = f"data/exports/{filename}"

        # Ensure export directory exists
        os.makedirs("data/exports", exist_ok=True)

        # Export to CSV
        df.to_csv(filepath, index=False, encoding='utf-8')

        # Calculate metrics
        file_size = os.path.getsize(filepath)

        export_result = {
            'filename': filename,
            'filepath': filepath,
            'record_count': len(df),
            'file_size_bytes': file_size,
            'export_timestamp': self.export_timestamp,
            'source': 'Supabase Production Database'
        }

        logger.info(f"✅ Exported to: {filepath}")
        logger.info(f"📊 Records: {len(df):,}")
        logger.info(f"💾 Size: {file_size / 1024 / 1024:.2f} MB")

        return export_result

    def run_bridge_export(self, limit: Optional[int] = 1000) -> Dict[str, Any]:
        """Main function to run Supabase-to-Azure bridge export"""

        logger.info("🌉 Starting Supabase-to-Azure Bridge Export")
        logger.info("=" * 50)

        try:
            # Connect to Supabase
            conn = self.connect_supabase()
            if not conn:
                return {'success': False, 'error': 'Failed to connect to Supabase'}

            # Extract production data
            production_df = self.extract_production_data(conn, limit)

            if production_df.empty:
                return {'success': False, 'error': 'No production data found'}

            # Transform to flat export format
            flat_df = self.transform_to_flat_export_format(production_df)

            # Export to CSV
            export_result = self.export_to_csv(flat_df)

            # Close connection
            conn.close()

            result = {
                'success': True,
                'export': export_result,
                'production_records': len(production_df),
                'brands_found': production_df['brand'].nunique(),
                'stores_found': production_df['storeid'].nunique(),
                'date_range': {
                    'earliest': production_df['ts_ph'].min().isoformat() if not production_df['ts_ph'].empty else None,
                    'latest': production_df['ts_ph'].max().isoformat() if not production_df['ts_ph'].empty else None
                }
            }

            logger.info("🎉 Supabase bridge export completed successfully!")
            logger.info(f"📁 File: {export_result['filename']}")
            logger.info(f"📊 Records: {export_result['record_count']:,}")
            logger.info(f"🏷️ Brands: {result['brands_found']}")
            logger.info(f"🏪 Stores: {result['stores_found']}")

            return result

        except Exception as e:
            logger.error(f"❌ Bridge export failed: {str(e)}")
            return {'success': False, 'error': str(e)}

def main():
    """Command line interface"""
    import argparse

    parser = argparse.ArgumentParser(description='Supabase-to-Azure Bridge Export')
    parser.add_argument('--limit', type=int, help='Limit number of records to export')
    parser.add_argument('--test', action='store_true', help='Run with 100 records for testing')

    args = parser.parse_args()

    limit = 100 if args.test else args.limit

    bridge = SupabaseToAzureBridge()
    result = bridge.run_bridge_export(limit=limit)

    if result['success']:
        print(f"✅ Bridge export successful!")
        print(f"File: {result['export']['filename']}")
        print(f"Records: {result['export']['record_count']:,}")
        if 'brands_found' in result:
            print(f"Brands: {result['brands_found']}")
            print(f"Stores: {result['stores_found']}")
    else:
        print(f"❌ Bridge export failed: {result['error']}")

if __name__ == "__main__":
    main()