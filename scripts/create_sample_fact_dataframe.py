#!/usr/bin/env python3
"""
Create Sample Scout Fact Table Dataframe
Generate clean sample data matching screenshot structure with 100% completeness
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import uuid

class SampleFactDataframeGenerator:
    """Generate clean sample fact table dataframe with no nulls"""

    def __init__(self):
        # Exact categories from screenshots
        self.categories = ['Snacks', 'Beverages', 'Canned Goods', 'Toiletries']
        self.brands = ['Brand A', 'Brand B', 'Brand C', 'Local Brand']
        self.locations = ['Los Baños', 'Quezon City', 'Manila', 'Pateros']
        self.store_ids = [102, 103, 104, 109, 110, 112]
        self.demographics = [
            'Adult Female', 'Adult Male', 'Teen', 'Senior',
            'Young Adult Female', 'Young Adult Male', 'Adult'
        ]
        self.emotions = ['Happy', 'Stressed', 'Neutral', 'Tired']
        self.dayparts = ['Morning', 'Afternoon', 'Evening']
        self.weekday_weekend = ['Weekday', 'Weekend']

        # Store-Location mapping
        self.store_location_map = {
            102: 'Los Baños',
            103: 'Quezon City',
            104: 'Manila',
            109: 'Pateros',
            110: 'Manila',
            112: 'Quezon City'
        }

        # Category-based pricing
        self.category_pricing = {
            'Snacks': (25, 75),
            'Beverages': (20, 60),
            'Canned Goods': (40, 120),
            'Toiletries': (80, 200)
        }

        # Other products mapping
        self.other_products_map = {
            'Snacks': 'Beverages, Canned Goods',
            'Beverages': 'Snacks, Ice',
            'Canned Goods': 'Rice, Condiments',
            'Toiletries': 'Personal Care'
        }

    def generate_sample_data(self, num_records: int = 1000) -> pd.DataFrame:
        """Generate sample fact table data with exact screenshot structure"""

        print(f"Generating {num_records} sample records...")

        data = []

        for i in range(num_records):
            # Generate timestamp (last 30 days)
            timestamp = datetime.now() - timedelta(
                days=random.randint(0, 30),
                hours=random.randint(6, 22),
                minutes=random.randint(0, 59)
            )

            # Select category and derive related fields
            category = random.choice(self.categories)
            brand = random.choice(self.brands)
            store_id = random.choice(self.store_ids)
            location = self.store_location_map[store_id]

            # Generate transaction value based on category
            min_price, max_price = self.category_pricing[category]
            transaction_value = round(random.uniform(min_price, max_price), 2)

            # Calculate basket size based on transaction value
            if transaction_value < 50:
                basket_size = 1
            elif transaction_value < 150:
                basket_size = random.randint(2, 3)
            elif transaction_value < 300:
                basket_size = random.randint(3, 4)
            else:
                basket_size = random.randint(4, 6)

            # Determine daypart from timestamp
            hour = timestamp.hour
            if 6 <= hour <= 11:
                daypart = 'Morning'
            elif 12 <= hour <= 17:
                daypart = 'Afternoon'
            else:
                daypart = 'Evening'

            # Weekend vs Weekday
            weekday_vs_weekend = 'Weekend' if timestamp.weekday() >= 5 else 'Weekday'

            # Time of transaction
            if hour <= 12:
                time_of_transaction = f"{hour}AM"
            else:
                time_of_transaction = f"{hour-12}PM"

            # Demographics with intelligent patterns
            if daypart == 'Morning' and weekday_vs_weekend == 'Weekday':
                demographics = random.choice(['Adult Female', 'Adult Male'])
            elif daypart == 'Afternoon' and transaction_value < 75:
                demographics = 'Teen'
            elif daypart == 'Evening' and transaction_value > 150:
                demographics = random.choice(['Adult Male', 'Adult Female'])
            elif weekday_vs_weekend == 'Weekend' and hour < 10:
                demographics = 'Senior'
            else:
                demographics = random.choice(self.demographics)

            # Emotions based on patterns
            if daypart == 'Morning' and weekday_vs_weekend == 'Weekday':
                emotions = 'Stressed'
            elif daypart == 'Evening' and transaction_value > 150:
                emotions = 'Happy'
            elif weekday_vs_weekend == 'Weekend' and 10 <= hour <= 16:
                emotions = 'Happy'
            elif hour > 21:
                emotions = 'Tired'
            else:
                emotions = 'Neutral'

            # Other products bought
            other_products_bought = self.other_products_map[category]

            # Substitution logic
            if 15 <= hour <= 17:
                was_there_substitution = 'Yes'
            elif hour > 19 and transaction_value > 100:
                was_there_substitution = 'Yes'
            else:
                was_there_substitution = 'No'

            # Generate IDs
            transaction_id = f"TXN_{store_id}_{timestamp.strftime('%Y%m%d%H%M%S')}_{i:04d}"
            facial_id = f"FACE_{random.randint(1, 999):03d}"
            device_id = f"DEVICE_{store_id}"

            # Create record
            record = {
                'Transaction_ID': transaction_id,
                'Transaction_Value': transaction_value,
                'Basket_Size': basket_size,
                'Category': category,
                'Brand': brand,
                'Daypart': daypart,
                'Weekday_vs_Weekend': weekday_vs_weekend,
                'Time_of_transaction': time_of_transaction,
                'Demographics (Age/Gender/Role)': demographics,
                'Emotions': emotions,
                'Location': location,
                'Other_products_bought': other_products_bought,
                'Was_there_substitution': was_there_substitution,
                'StoreID': store_id,
                'Timestamp': timestamp,
                'FacialID': facial_id,
                'DeviceID': device_id
            }

            data.append(record)

        # Create DataFrame
        df = pd.DataFrame(data)

        # Sort by timestamp descending (most recent first)
        df = df.sort_values('Timestamp', ascending=False).reset_index(drop=True)

        return df

    def validate_completeness(self, df: pd.DataFrame) -> dict:
        """Validate 100% data completeness"""

        null_counts = df.isnull().sum()
        total_nulls = null_counts.sum()
        total_cells = len(df) * len(df.columns)

        completeness_pct = ((total_cells - total_nulls) / total_cells * 100) if total_cells > 0 else 100

        # Check unique values for key columns
        unique_stats = {}
        key_columns = ['Category', 'Brand', 'Location', 'Demographics (Age/Gender/Role)', 'Emotions']
        for col in key_columns:
            if col in df.columns:
                unique_stats[col] = df[col].unique().tolist()

        return {
            'total_records': len(df),
            'total_columns': len(df.columns),
            'total_nulls': total_nulls,
            'completeness_percentage': completeness_pct,
            'unique_stats': unique_stats,
            'null_counts': null_counts[null_counts > 0].to_dict()
        }

    def export_dataframe(self, df: pd.DataFrame, base_filename: str = "scout_sample_fact_table") -> dict:
        """Export dataframe to multiple formats"""

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        # CSV export
        csv_file = f"/Users/tbwa/scout-v7/data/{base_filename}_{timestamp}.csv"
        df.to_csv(csv_file, index=False)

        # Excel export
        excel_file = f"/Users/tbwa/scout-v7/data/{base_filename}_{timestamp}.xlsx"
        df.to_excel(excel_file, index=False, sheet_name='Scout_Sample_Data')

        # Parquet export (for analytics)
        parquet_file = f"/Users/tbwa/scout-v7/data/{base_filename}_{timestamp}.parquet"
        df.to_parquet(parquet_file, index=False)

        return {
            'csv': csv_file,
            'excel': excel_file,
            'parquet': parquet_file
        }

def main():
    """Main execution"""
    generator = SampleFactDataframeGenerator()

    print("🚀 Creating Scout Sample Fact Table Dataframe")
    print("=" * 55)

    # Generate sample data
    print("\n1. Generating sample data...")
    df = generator.generate_sample_data(num_records=1000)

    print(f"✅ Generated {len(df)} sample records")

    # Validate completeness
    print("\n2. Validating data completeness...")
    validation = generator.validate_completeness(df)

    print("📊 Data Quality Report:")
    print(f"Total records: {validation['total_records']:,}")
    print(f"Total columns: {validation['total_columns']}")
    print(f"Total null values: {validation['total_nulls']}")
    print(f"✅ Data completeness: {validation['completeness_percentage']:.1f}%")

    if validation['total_nulls'] == 0:
        print("🎉 100% DATA COMPLETENESS ACHIEVED!")

    # Show unique values for key columns
    print("\n📈 Data Summary:")
    for col, values in validation['unique_stats'].items():
        print(f"{col}: {values}")

    # Export files
    print("\n3. Exporting dataframe...")
    files = generator.export_dataframe(df)

    print("💾 Files created:")
    for file_type, filepath in files.items():
        print(f"  - {file_type.upper()}: {filepath}")

    # Show sample data
    print("\n📄 Sample Data (first 5 rows):")
    sample_df = df.head(5)

    # Display key columns for readability
    key_columns = [
        'Transaction_ID', 'Transaction_Value', 'Category', 'Brand',
        'Demographics (Age/Gender/Role)', 'Location', 'Emotions', 'StoreID'
    ]

    for idx, row in sample_df.iterrows():
        print(f"\nRow {idx + 1}:")
        for col in key_columns:
            if col in sample_df.columns:
                print(f"  {col}: {row[col]}")

    print(f"\n🎉 SUCCESS! Sample fact table created with {validation['completeness_percentage']:.1f}% completeness")
    print("📋 All 15 columns from screenshots implemented with intelligent data generation")
    print("🔍 Ready for dimensional analysis and business intelligence queries")

    return {
        'success': True,
        'dataframe': df,
        'validation': validation,
        'files': files
    }

if __name__ == "__main__":
    result = main()