#!/usr/bin/env python3
"""
Verify Scout Fact Table Structure
Validate that the generated dataframe matches screenshot requirements exactly
"""

import pandas as pd
import os

def verify_fact_table_structure(csv_path: str):
    """Verify the fact table structure matches screenshot requirements"""

    print("🔍 Verifying Scout Fact Table Structure")
    print("=" * 45)

    # Load the dataframe
    df = pd.read_csv(csv_path)

    # Expected columns from screenshots (exact order and names)
    expected_columns = [
        "Transaction_ID",
        "Transaction_Value",
        "Basket_Size",
        "Category",
        "Brand",
        "Daypart",
        "Weekday_vs_Weekend",
        "Time_of_transaction",
        "Demographics (Age/Gender/Role)",
        "Emotions",
        "Location",
        "Other_products_bought",
        "Was_there_substitution",
        "StoreID",
        "Timestamp",
        "FacialID",
        "DeviceID"
    ]

    actual_columns = df.columns.tolist()

    print(f"📊 Structure Validation:")
    print(f"Expected columns: {len(expected_columns)}")
    print(f"Actual columns: {len(actual_columns)}")
    print(f"Records: {len(df):,}")

    # Check column presence
    missing_columns = set(expected_columns) - set(actual_columns)
    extra_columns = set(actual_columns) - set(expected_columns)

    if missing_columns:
        print(f"❌ Missing columns: {missing_columns}")
    else:
        print("✅ All expected columns present")

    if extra_columns:
        print(f"➕ Extra columns: {extra_columns}")

    # Check data completeness
    null_counts = df.isnull().sum()
    total_nulls = null_counts.sum()

    print(f"\n📈 Data Completeness:")
    print(f"Total null values: {total_nulls}")
    if total_nulls == 0:
        print("✅ 100% Data Completeness Achieved!")
    else:
        print("❌ Null values found:")
        for col, nulls in null_counts[null_counts > 0].items():
            print(f"  - {col}: {nulls} nulls")

    # Validate key column values
    print(f"\n🎯 Value Validation:")

    # Categories should be exactly: Snacks, Beverages, Canned Goods, Toiletries
    expected_categories = {'Snacks', 'Beverages', 'Canned Goods', 'Toiletries'}
    actual_categories = set(df['Category'].unique())
    if actual_categories == expected_categories:
        print("✅ Categories match screenshot requirements")
    else:
        print(f"❌ Category mismatch: {actual_categories}")

    # Brands should be: Brand A, B, C, Local Brand
    expected_brands = {'Brand A', 'Brand B', 'Brand C', 'Local Brand'}
    actual_brands = set(df['Brand'].unique())
    if actual_brands == expected_brands:
        print("✅ Brands match screenshot requirements")
    else:
        print(f"❌ Brand mismatch: {actual_brands}")

    # Locations should be: Los Baños, Quezon City, Manila, Pateros
    expected_locations = {'Los Baños', 'Quezon City', 'Manila', 'Pateros'}
    actual_locations = set(df['Location'].unique())
    if actual_locations == expected_locations:
        print("✅ Locations match screenshot requirements")
    else:
        print(f"❌ Location mismatch: {actual_locations}")

    # Store IDs should be: 102, 103, 104, 109, 110, 112
    expected_store_ids = {102, 103, 104, 109, 110, 112}
    actual_store_ids = set(df['StoreID'].unique())
    if actual_store_ids == expected_store_ids:
        print("✅ Store IDs match Scout store requirements")
    else:
        print(f"❌ Store ID mismatch: {actual_store_ids}")

    # Check substitution values
    expected_substitution = {'Yes', 'No'}
    actual_substitution = set(df['Was_there_substitution'].unique())
    if actual_substitution == expected_substitution:
        print("✅ Substitution values correct (Yes/No)")
    else:
        print(f"❌ Substitution mismatch: {actual_substitution}")

    print(f"\n📋 Sample Record Validation:")
    sample_record = df.iloc[0]
    print("First record structure:")
    for col in expected_columns:
        if col in df.columns:
            value = sample_record[col]
            print(f"  {col}: {value} ({type(value).__name__})")

    # Summary
    print(f"\n🎉 VERIFICATION SUMMARY:")
    all_columns_present = len(missing_columns) == 0
    no_nulls = total_nulls == 0
    correct_categories = actual_categories == expected_categories
    correct_brands = actual_brands == expected_brands
    correct_locations = actual_locations == expected_locations
    correct_stores = actual_store_ids == expected_store_ids

    validation_score = sum([
        all_columns_present,
        no_nulls,
        correct_categories,
        correct_brands,
        correct_locations,
        correct_stores
    ])

    print(f"Validation Score: {validation_score}/6")

    if validation_score == 6:
        print("✅ PERFECT! Fact table matches screenshot requirements exactly")
        print("🚀 Ready for dimensional analysis and business intelligence")
    else:
        print("⚠️  Some requirements not met. Review validation details above.")

    return {
        'validation_score': validation_score,
        'all_columns_present': all_columns_present,
        'data_complete': no_nulls,
        'categories_correct': correct_categories,
        'brands_correct': correct_brands,
        'locations_correct': correct_locations,
        'stores_correct': correct_stores,
        'total_records': len(df),
        'total_columns': len(actual_columns)
    }

def main():
    """Find and verify the latest fact table file"""

    data_dir = "/Users/tbwa/scout-v7/data"

    # Find the latest CSV file
    csv_files = [f for f in os.listdir(data_dir) if f.startswith('scout_sample_fact_table_') and f.endswith('.csv')]

    if not csv_files:
        print("❌ No fact table CSV files found")
        return

    # Get the most recent file
    latest_file = sorted(csv_files)[-1]
    csv_path = os.path.join(data_dir, latest_file)

    print(f"📁 Verifying file: {latest_file}")
    print()

    result = verify_fact_table_structure(csv_path)

    return result

if __name__ == "__main__":
    main()