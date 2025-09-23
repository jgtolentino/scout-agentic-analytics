#!/usr/bin/env python3
"""
Comprehensive EDA Analysis for Scout v7 Transaction Dataset
12,192 canonical transactions from NCR Metro Manila Sari-Sari stores
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Set plotting style
plt.style.use('default')
sns.set_palette("husl")

def load_and_clean_data():
    """Load and initial cleaning of the dataset"""
    print("📊 Loading Scout v7 Transaction Dataset...")

    # Load the clean dataset
    df = pd.read_csv('/Users/tbwa/scout-v7/exports/clean_12k_dataset.csv',
                     quoting=1,   # Handle quotes properly
                     on_bad_lines='skip')  # Skip problematic lines

    print(f"Dataset Shape: {df.shape}")
    print(f"Memory Usage: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")

    return df

def data_quality_assessment(df):
    """Comprehensive data quality analysis"""
    print("\n🔍 DATA QUALITY ASSESSMENT")
    print("=" * 50)

    # Basic info
    print(f"Total Records: {len(df):,}")
    print(f"Total Columns: {len(df.columns)}")

    # Missing data analysis
    print("\n📋 Missing Data Analysis:")
    missing_data = df.isnull().sum()
    missing_pct = (missing_data / len(df) * 100).round(2)

    missing_summary = pd.DataFrame({
        'Missing_Count': missing_data,
        'Missing_Percentage': missing_pct
    }).sort_values('Missing_Count', ascending=False)

    print(missing_summary[missing_summary['Missing_Count'] > 0])

    # Data types
    print("\n📊 Data Types:")
    print(df.dtypes.value_counts())

    # Unique values per column
    print("\n🔢 Unique Values per Column:")
    unique_counts = df.nunique().sort_values(ascending=False)
    print(unique_counts)

    return missing_summary

def transaction_value_analysis(df):
    """Analyze transaction amounts and patterns"""
    print("\n💰 TRANSACTION VALUE ANALYSIS")
    print("=" * 50)

    # Convert Amount to numeric, handle any issues
    df['Amount'] = pd.to_numeric(df['Amount'], errors='coerce')

    # Basic statistics
    print("Transaction Amount Statistics:")
    print(df['Amount'].describe())

    # Value distribution
    print(f"\nZero-value transactions: {(df['Amount'] == 0).sum():,} ({(df['Amount'] == 0).mean()*100:.1f}%)")
    print(f"Transactions > ₱500: {(df['Amount'] > 500).sum():,} ({(df['Amount'] > 500).mean()*100:.1f}%)")
    print(f"Transactions > ₱1000: {(df['Amount'] > 1000).sum():,} ({(df['Amount'] > 1000).mean()*100:.1f}%)")

    # Top transaction values
    print(f"\nTop 10 Transaction Values:")
    top_amounts = df['Amount'].value_counts().head(10)
    print(top_amounts)

    return df

def brand_category_analysis(df):
    """Analyze brand and category patterns"""
    print("\n🏷️ BRAND & CATEGORY ANALYSIS")
    print("=" * 50)

    # Category analysis
    print("Top 15 Categories:")
    category_counts = df['category'].value_counts().head(15)
    print(category_counts)

    print(f"\nTotal unique categories: {df['category'].nunique()}")
    print(f"NULL/Missing categories: {df['category'].isnull().sum()}")

    # Brand analysis
    print("\nTop 15 Brands:")
    brand_counts = df['brand'].value_counts().head(15)
    print(brand_counts)

    print(f"\nTotal unique brands: {df['brand'].nunique()}")
    print(f"NULL/Missing brands: {df['brand'].isnull().sum()}")

    return category_counts, brand_counts

def store_device_analysis(df):
    """Analyze store and device distribution"""
    print("\n🏪 STORE & DEVICE ANALYSIS")
    print("=" * 50)

    # Store analysis
    print("Store Distribution:")
    store_counts = df['StoreID'].value_counts().sort_index()
    print(store_counts)

    print(f"\nTotal unique stores: {df['StoreID'].nunique()}")

    # Device analysis
    print("\nDevice Distribution:")
    device_counts = df['DeviceID'].value_counts()
    print(device_counts)

    print(f"\nTotal unique devices: {df['DeviceID'].nunique()}")

    # Store-Device mapping
    print("\nStore-Device Combinations:")
    store_device = df.groupby(['StoreID', 'DeviceID']).size().reset_index(name='transaction_count')
    print(store_device.head(10))

    return store_counts, device_counts

def basket_analysis(df):
    """Analyze basket size and composition"""
    print("\n🛒 BASKET ANALYSIS")
    print("=" * 50)

    # Convert to numeric
    df['Basket_Item_Count'] = pd.to_numeric(df['Basket_Item_Count'], errors='coerce')

    print("Basket Size Statistics:")
    print(df['Basket_Item_Count'].describe())

    print("\nBasket Size Distribution:")
    basket_dist = df['Basket_Item_Count'].value_counts().sort_index()
    print(basket_dist.head(10))

    # Single vs multi-item transactions
    single_item = (df['Basket_Item_Count'] == 1).sum()
    multi_item = (df['Basket_Item_Count'] > 1).sum()
    zero_item = (df['Basket_Item_Count'] == 0).sum()

    print(f"\nSingle-item transactions: {single_item:,} ({single_item/len(df)*100:.1f}%)")
    print(f"Multi-item transactions: {multi_item:,} ({multi_item/len(df)*100:.1f}%)")
    print(f"Zero-item transactions: {zero_item:,} ({zero_item/len(df)*100:.1f}%)")

    return basket_dist

def timestamp_analysis(df):
    """Analyze timestamp patterns and temporal data"""
    print("\n⏰ TIMESTAMP ANALYSIS")
    print("=" * 50)

    # Check timestamp availability
    has_timestamp = df['Txn_TS'].notna().sum()
    print(f"Records with timestamps: {has_timestamp:,} ({has_timestamp/len(df)*100:.1f}%)")
    print(f"Records without timestamps: {len(df)-has_timestamp:,} ({(len(df)-has_timestamp)/len(df)*100:.1f}%)")

    if has_timestamp > 0:
        # Convert timestamps
        df['Txn_TS_parsed'] = pd.to_datetime(df['Txn_TS'], errors='coerce')

        print("\nTimestamp Range:")
        print(f"Earliest: {df['Txn_TS_parsed'].min()}")
        print(f"Latest: {df['Txn_TS_parsed'].max()}")

        # Daypart analysis
        print("\nDaypart Distribution:")
        daypart_dist = df['daypart'].value_counts()
        print(daypart_dist)

        # Weekday vs Weekend
        print("\nWeekday vs Weekend:")
        weekday_dist = df['weekday_weekend'].value_counts()
        print(weekday_dist)

    return has_timestamp

def audio_transcript_analysis(df):
    """Analyze audio transcript data"""
    print("\n🎤 AUDIO TRANSCRIPT ANALYSIS")
    print("=" * 50)

    # Check transcript availability
    has_transcript = df['audio_transcript'].notna().sum()
    non_empty_transcript = df['audio_transcript'].str.strip().ne('').sum()

    print(f"Records with transcripts: {has_transcript:,} ({has_transcript/len(df)*100:.1f}%)")
    print(f"Non-empty transcripts: {non_empty_transcript:,} ({non_empty_transcript/len(df)*100:.1f}%)")

    if non_empty_transcript > 0:
        # Sample transcripts
        print("\nSample Audio Transcripts:")
        sample_transcripts = df[df['audio_transcript'].notna() & (df['audio_transcript'].str.strip() != '')]['audio_transcript'].head(10)
        for i, transcript in enumerate(sample_transcripts, 1):
            print(f"{i}. {transcript}")

        # Transcript length analysis
        df['transcript_length'] = df['audio_transcript'].str.len()
        print(f"\nTranscript Length Statistics:")
        print(df['transcript_length'].describe())

    return has_transcript

def business_insights(df):
    """Generate key business insights"""
    print("\n💡 KEY BUSINESS INSIGHTS")
    print("=" * 50)

    # Revenue analysis
    total_revenue = df['Amount'].sum()
    avg_transaction = df['Amount'].mean()

    print(f"Total Revenue: ₱{total_revenue:,.2f}")
    print(f"Average Transaction Value: ₱{avg_transaction:.2f}")

    # Category performance
    category_revenue = df.groupby('category')['Amount'].agg(['sum', 'mean', 'count']).sort_values('sum', ascending=False)
    print(f"\nTop 10 Categories by Revenue:")
    print(category_revenue.head(10))

    # Brand performance
    brand_revenue = df.groupby('brand')['Amount'].agg(['sum', 'mean', 'count']).sort_values('sum', ascending=False)
    print(f"\nTop 10 Brands by Revenue:")
    print(brand_revenue.head(10))

    # Store performance
    store_performance = df.groupby('StoreID').agg({
        'Amount': ['sum', 'mean', 'count'],
        'Basket_Item_Count': 'mean'
    }).round(2)
    store_performance.columns = ['Total_Revenue', 'Avg_Transaction', 'Transaction_Count', 'Avg_Basket_Size']
    print(f"\nStore Performance:")
    print(store_performance)

    return category_revenue, brand_revenue, store_performance

def generate_summary_report(df, missing_summary, category_revenue, brand_revenue, store_performance):
    """Generate executive summary report"""
    print("\n📈 EXECUTIVE SUMMARY REPORT")
    print("=" * 60)

    # Dataset overview
    print("DATASET OVERVIEW:")
    print(f"• Total Transactions: {len(df):,}")
    print(f"• Date Range: NCR Metro Manila Sari-Sari Stores")
    print(f"• Unique Stores: {df['StoreID'].nunique()}")
    print(f"• Unique Brands: {df['brand'].nunique()}")
    print(f"• Unique Categories: {df['category'].nunique()}")

    # Revenue summary
    print(f"\nREVENUE SUMMARY:")
    print(f"• Total Revenue: ₱{df['Amount'].sum():,.2f}")
    print(f"• Average Transaction: ₱{df['Amount'].mean():.2f}")
    print(f"• Median Transaction: ₱{df['Amount'].median():.2f}")
    print(f"• Revenue per Store: ₱{df['Amount'].sum()/df['StoreID'].nunique():,.2f}")

    # Data completeness
    print(f"\nDATA COMPLETENESS:")
    complete_records = (df.notna().all(axis=1)).sum()
    print(f"• Complete Records: {complete_records:,} ({complete_records/len(df)*100:.1f}%)")
    print(f"• Records with Timestamps: {df['Txn_TS'].notna().sum():,} ({df['Txn_TS'].notna().mean()*100:.1f}%)")
    print(f"• Records with Audio: {df['audio_transcript'].notna().sum():,} ({df['audio_transcript'].notna().mean()*100:.1f}%)")

    # Top performers
    print(f"\nTOP PERFORMERS:")
    print(f"• Best Category: {category_revenue.index[0]} (₱{category_revenue.iloc[0]['sum']:,.2f})")
    print(f"• Best Brand: {brand_revenue.index[0]} (₱{brand_revenue.iloc[0]['sum']:,.2f})")
    print(f"• Most Active Store: {store_performance.sort_values('Transaction_Count', ascending=False).index[0]}")

def main():
    """Main EDA execution"""
    print("🚀 STARTING COMPREHENSIVE EDA ANALYSIS")
    print("="*60)

    # Load data
    df = load_and_clean_data()

    # Run all analyses
    missing_summary = data_quality_assessment(df)
    df = transaction_value_analysis(df)
    category_counts, brand_counts = brand_category_analysis(df)
    store_counts, device_counts = store_device_analysis(df)
    basket_dist = basket_analysis(df)
    has_timestamp = timestamp_analysis(df)
    has_transcript = audio_transcript_analysis(df)
    category_revenue, brand_revenue, store_performance = business_insights(df)

    # Generate summary
    generate_summary_report(df, missing_summary, category_revenue, brand_revenue, store_performance)

    print(f"\n✅ EDA ANALYSIS COMPLETE")
    print(f"Analysis timestamp: {datetime.now()}")

    return df

if __name__ == "__main__":
    df = main()