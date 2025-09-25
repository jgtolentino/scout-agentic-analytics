#!/usr/bin/env python3
"""
Mock Flattened Dataset Export
Creates sample data matching your ETL structure for testing
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import random

def create_mock_flattened_data(num_records=5000):
    """Create mock flattened transaction data"""

    print(f"🔍 Creating mock flattened dataset with {num_records} records...")

    # Generate date range (last 30 days)
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)

    # Mock data generation
    np.random.seed(42)  # For reproducible results

    # Sample brands (mix of owned and competitor)
    brands = [
        'Alaska', 'Nestlé', 'San Miguel', 'Coca-Cola', 'Pepsi',
        'Unilever', 'P&G', 'Colgate', 'Johnson & Johnson', 'Dove',
        'Pantene', 'Head & Shoulders', 'Surf', 'Tide', 'Ariel'
    ]

    # Sample store IDs and locations
    store_data = [
        {'store_id': 'ST001', 'store_name': 'SM Mall of Asia', 'barangay': 'Bay City', 'city': 'Pasay', 'region_name': 'NCR', 'latitude': 14.5352, 'longitude': 120.9761},
        {'store_id': 'ST002', 'store_name': 'Ayala Makati', 'barangay': 'Poblacion', 'city': 'Makati', 'region_name': 'NCR', 'latitude': 14.5547, 'longitude': 121.0244},
        {'store_id': 'ST003', 'store_name': 'Robinsons Galleria', 'barangay': 'Ortigas Center', 'city': 'Quezon City', 'region_name': 'NCR', 'latitude': 14.6196, 'longitude': 121.0565},
        {'store_id': 'ST004', 'store_name': 'Gateway Mall', 'barangay': 'Cubao', 'city': 'Quezon City', 'region_name': 'NCR', 'latitude': 14.6225, 'longitude': 121.0532},
        {'store_id': 'ST005', 'store_name': 'Trinoma', 'barangay': 'North Triangle', 'city': 'Quezon City', 'region_name': 'NCR', 'latitude': 14.6563, 'longitude': 121.0327}
    ]

    records = []

    for i in range(num_records):
        # Random timestamp within date range
        random_timestamp = start_date + timedelta(
            seconds=random.randint(0, int((end_date - start_date).total_seconds()))
        )

        # Random store
        store = random.choice(store_data)

        # Generate transaction data
        record = {
            'canonical_tx_id': f'TX{random.randint(100000, 999999)}_{i:06d}',
            'sessionId': f'SES_{random.randint(10000, 99999)}',
            'deviceId': f'DEV_{random.randint(1000, 9999)}',
            'storeId': store['store_id'],
            'amount': round(random.uniform(50.0, 2500.0), 2),  # PHP 50 to 2500
            'timestamp': random_timestamp,
            'InteractionID': f'INT_{random.randint(1000, 9999)}' if random.random() > 0.3 else None,
            'FacialID': f'FACE_{random.randint(100, 999)}' if random.random() > 0.7 else None,
            'TransactionDate': random_timestamp.date(),

            # Store enrichment
            'store_id': store['store_id'],
            'store_name': store['store_name'],
            'barangay': store['barangay'],
            'city': store['city'],
            'region_name': store['region_name'],
            'latitude': store['latitude'],
            'longitude': store['longitude'],

            # Add some product/brand data for realism
            'brand_name': random.choice(brands),
            'product_category': random.choice(['Food', 'Beverages', 'Personal Care', 'Household', 'Health']),

            # Mock payload_json structure
            'payload_json': json.dumps({
                'transaction_id': f'TX{random.randint(100000, 999999)}_{i:06d}',
                'items': [
                    {
                        'product_id': f'PRD_{random.randint(1000, 9999)}',
                        'brand': random.choice(brands),
                        'category': random.choice(['Food', 'Beverages', 'Personal Care']),
                        'price': round(random.uniform(25.0, 500.0), 2),
                        'quantity': random.randint(1, 5)
                    }
                ],
                'payment_method': random.choice(['Cash', 'Card', 'GCash', 'PayMaya']),
                'customer_type': random.choice(['Regular', 'Member', 'VIP'])
            })
        }

        records.append(record)

    df = pd.DataFrame(records)

    print(f"✅ Created {len(df)} mock transaction records")
    return df

def export_mock_data():
    """Export mock flattened data in multiple formats"""

    # Create mock dataset
    df = create_mock_flattened_data(5000)

    # Export timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Export formats
    exports = {
        'parquet': f"scout_flat_mock_{timestamp}.parquet",
        'csv': f"scout_flat_mock_{timestamp}.csv",
        'json': f"scout_flat_mock_{timestamp}.json"
    }

    for format_type, filename in exports.items():
        if format_type == 'parquet':
            df.to_parquet(filename, index=False)
        elif format_type == 'csv':
            df.to_csv(filename, index=False)
        elif format_type == 'json':
            df.to_json(filename, orient='records', date_format='iso')

        print(f"✅ Exported {format_type.upper()}: {filename}")

    # Generate quick stats
    print(f"\n🎉 Export complete! {len(df)} records exported")
    print(f"📊 Columns: {list(df.columns)}")

    print(f"\n📈 Quick Stats:")
    print(f"  - Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
    print(f"  - Stores: {df['storeId'].nunique()} unique stores")
    print(f"  - Brands: {df['brand_name'].nunique()} unique brands")
    print(f"  - Total amount: ₱{df['amount'].sum():,.2f}")
    print(f"  - Avg transaction: ₱{df['amount'].mean():.2f}")

    # Sample records
    print(f"\n📋 Sample Records:")
    print(df[['canonical_tx_id', 'store_name', 'brand_name', 'amount', 'timestamp']].head())

    return df

if __name__ == "__main__":
    df = export_mock_data()