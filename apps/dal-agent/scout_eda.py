#!/usr/bin/env python3
"""
Scout Production Data - Exploratory Data Analysis & Summary Statistics
Comprehensive analysis of real Scout transaction data
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Set style for better plots
plt.style.use('default')
sns.set_palette("husl")

def load_production_data():
    """Load the latest production export"""

    print("📊 Loading Scout production data...")

    # Find the latest export file
    import glob
    parquet_files = glob.glob("scout_gold_production_*.parquet")

    if not parquet_files:
        print("❌ No production data files found")
        print("💡 Run final_production_export.py first")
        return None

    latest_file = max(parquet_files)
    print(f"✅ Loading: {latest_file}")

    df = pd.read_parquet(latest_file)
    print(f"📈 Loaded {len(df):,} records with {len(df.columns)} columns")

    return df

def basic_info_summary(df):
    """Generate basic dataset information"""

    print("\n" + "="*60)
    print("📋 BASIC DATASET INFORMATION")
    print("="*60)

    print(f"Dataset Shape: {df.shape[0]:,} rows × {df.shape[1]} columns")
    print(f"Memory Usage: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")

    print(f"\n📅 Date Range:")
    if 'timestamp' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        print(f"  From: {df['timestamp'].min()}")
        print(f"  To: {df['timestamp'].max()}")
        print(f"  Span: {(df['timestamp'].max() - df['timestamp'].min()).days} days")

    print(f"\n📊 Data Types:")
    for dtype in df.dtypes.value_counts().items():
        print(f"  {dtype[1]} columns: {dtype[0]}")

    print(f"\n🔍 Missing Values:")
    missing = df.isnull().sum()
    missing_pct = (missing / len(df) * 100).round(2)

    for col in df.columns:
        if missing[col] > 0:
            print(f"  {col}: {missing[col]:,} ({missing_pct[col]}%)")

    if missing.sum() == 0:
        print("  ✅ No missing values found!")

def financial_analysis(df):
    """Analyze financial/revenue metrics"""

    print("\n" + "="*60)
    print("💰 FINANCIAL ANALYSIS")
    print("="*60)

    amount_col = 'amount'  # or 'peso_value'

    if amount_col in df.columns:
        amounts = df[amount_col].dropna()

        print(f"📊 Transaction Values (₱):")
        print(f"  Total Revenue: ₱{amounts.sum():,.2f}")
        print(f"  Average Transaction: ₱{amounts.mean():.2f}")
        print(f"  Median Transaction: ₱{amounts.median():.2f}")
        print(f"  Standard Deviation: ₱{amounts.std():.2f}")
        print(f"  Min Transaction: ₱{amounts.min():.2f}")
        print(f"  Max Transaction: ₱{amounts.max():.2f}")

        print(f"\n📈 Transaction Value Distribution:")
        percentiles = [10, 25, 50, 75, 90, 95, 99]
        for p in percentiles:
            val = np.percentile(amounts, p)
            print(f"  {p}th percentile: ₱{val:.2f}")

        # Revenue by basket size if available
        if 'basket_size' in df.columns:
            basket_revenue = df.groupby('basket_size')[amount_col].agg(['count', 'sum', 'mean']).round(2)
            basket_revenue.columns = ['Transactions', 'Total_Revenue', 'Avg_Revenue']
            print(f"\n🛒 Revenue by Basket Size (Top 10):")
            print(basket_revenue.head(10))

    else:
        print("❌ No amount/revenue column found")

def geographic_analysis(df):
    """Analyze geographic distribution"""

    print("\n" + "="*60)
    print("🗺️  GEOGRAPHIC ANALYSIS")
    print("="*60)

    geo_cols = ['location_region', 'location_province', 'location_city', 'location_barangay', 'store_id']

    for col in geo_cols:
        if col in df.columns:
            counts = df[col].value_counts()
            print(f"\n📍 {col.replace('location_', '').title()} Distribution:")
            print(f"  Unique {col}: {counts.nunique()}")

            if len(counts) <= 20:  # Show all if not too many
                for location, count in counts.items():
                    pct = (count / len(df) * 100)
                    print(f"  {location}: {count:,} ({pct:.1f}%)")
            else:  # Show top 10
                print("  Top 10:")
                for location, count in counts.head(10).items():
                    pct = (count / len(df) * 100)
                    print(f"  {location}: {count:,} ({pct:.1f}%)")

    # Store performance analysis
    if 'store_id' in df.columns and 'amount' in df.columns:
        store_perf = df.groupby('store_id').agg({
            'amount': ['count', 'sum', 'mean'],
            'canonical_tx_id': 'nunique'
        }).round(2)

        store_perf.columns = ['Transactions', 'Revenue', 'Avg_Transaction', 'Unique_TXN_IDs']
        store_perf = store_perf.sort_values('Revenue', ascending=False)

        print(f"\n🏪 Store Performance Summary:")
        print(store_perf)

def brand_analysis(df):
    """Analyze brand performance and distribution"""

    print("\n" + "="*60)
    print("🏷️  BRAND ANALYSIS")
    print("="*60)

    if 'brand_name' in df.columns:
        brands = df['brand_name'].value_counts()

        print(f"📊 Brand Distribution:")
        print(f"  Total Unique Brands: {brands.nunique():,}")
        print(f"  Most Popular Brand: {brands.index[0]} ({brands.iloc[0]:,} transactions)")

        print(f"\n🔝 Top 20 Brands by Transaction Count:")
        for i, (brand, count) in enumerate(brands.head(20).items(), 1):
            pct = (count / len(df) * 100)
            print(f"  {i:2d}. {brand}: {count:,} ({pct:.1f}%)")

        # Brand revenue analysis
        if 'amount' in df.columns:
            brand_revenue = df.groupby('brand_name').agg({
                'amount': ['count', 'sum', 'mean'],
                'canonical_tx_id': 'nunique'
            }).round(2)

            brand_revenue.columns = ['Transactions', 'Revenue', 'Avg_Transaction', 'Unique_TXNs']
            brand_revenue = brand_revenue.sort_values('Revenue', ascending=False)

            print(f"\n💰 Top 15 Brands by Revenue:")
            for brand, row in brand_revenue.head(15).iterrows():
                print(f"  {brand}: ₱{row['Revenue']:,.2f} ({row['Transactions']:,} txns)")

    # Category analysis
    if 'product_category' in df.columns:
        categories = df['product_category'].value_counts()

        print(f"\n📦 Product Category Distribution:")
        print(f"  Total Categories: {categories.nunique()}")

        for category, count in categories.items():
            pct = (count / len(df) * 100)
            print(f"  {category}: {count:,} ({pct:.1f}%)")

def customer_analysis(df):
    """Analyze customer demographics and behavior"""

    print("\n" + "="*60)
    print("👥 CUSTOMER ANALYSIS")
    print("="*60)

    # Gender analysis
    if 'gender' in df.columns:
        gender_dist = df['gender'].value_counts(dropna=False)
        print(f"⚧️  Gender Distribution:")
        for gender, count in gender_dist.items():
            pct = (count / len(df) * 100)
            print(f"  {gender}: {count:,} ({pct:.1f}%)")

    # Age analysis
    if 'age_bracket' in df.columns:
        age_dist = df['age_bracket'].value_counts(dropna=False).sort_index()
        print(f"\n👶 Age Bracket Distribution:")
        for age, count in age_dist.items():
            pct = (count / len(df) * 100)
            print(f"  {age}: {count:,} ({pct:.1f}%)")

    # Payment method analysis
    if 'payment_method' in df.columns:
        payment_dist = df['payment_method'].value_counts(dropna=False)
        print(f"\n💳 Payment Method Distribution:")
        for method, count in payment_dist.items():
            pct = (count / len(df) * 100)
            print(f"  {method}: {count:,} ({pct:.1f}%)")

    # Customer type analysis
    if 'customer_type' in df.columns:
        customer_dist = df['customer_type'].value_counts(dropna=False)
        print(f"\n🏷️  Customer Type Distribution:")
        for ctype, count in customer_dist.items():
            pct = (count / len(df) * 100)
            print(f"  {ctype}: {count:,} ({pct:.1f}%)")

def temporal_analysis(df):
    """Analyze temporal patterns"""

    print("\n" + "="*60)
    print("⏰ TEMPORAL ANALYSIS")
    print("="*60)

    if 'timestamp' in df.columns:
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.day_name()
        df['date'] = df['timestamp'].dt.date

        # Hourly patterns
        hourly = df['hour'].value_counts().sort_index()
        print(f"🕐 Hourly Transaction Pattern:")
        for hour, count in hourly.items():
            pct = (count / len(df) * 100)
            bar = "█" * int(pct / 2)  # Simple bar chart
            print(f"  {hour:2d}:00 │{bar:<25} {count:,} ({pct:.1f}%)")

        # Daily patterns
        daily = df['day_of_week'].value_counts()
        print(f"\n📅 Day of Week Pattern:")
        days_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        for day in days_order:
            if day in daily.index:
                count = daily[day]
                pct = (count / len(df) * 100)
                print(f"  {day}: {count:,} ({pct:.1f}%)")

        # Date distribution
        date_dist = df['date'].value_counts().sort_index()
        print(f"\n📊 Transaction Volume by Date:")
        for date, count in date_dist.items():
            print(f"  {date}: {count:,} transactions")

    else:
        print("❌ No timestamp column found")

def correlation_analysis(df):
    """Analyze correlations between numeric variables"""

    print("\n" + "="*60)
    print("🔗 CORRELATION ANALYSIS")
    print("="*60)

    # Select numeric columns
    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()

    if len(numeric_cols) >= 2:
        corr_matrix = df[numeric_cols].corr()

        print(f"🔢 Correlation Matrix (Numeric Variables):")
        print(f"Variables: {', '.join(numeric_cols)}")
        print(f"\nCorrelation Matrix:")
        print(corr_matrix.round(3))

        # Find strong correlations
        strong_corr = []
        for i in range(len(corr_matrix.columns)):
            for j in range(i+1, len(corr_matrix.columns)):
                corr_val = corr_matrix.iloc[i, j]
                if abs(corr_val) > 0.5:  # Strong correlation threshold
                    strong_corr.append((
                        corr_matrix.columns[i],
                        corr_matrix.columns[j],
                        corr_val
                    ))

        if strong_corr:
            print(f"\n🎯 Strong Correlations (|r| > 0.5):")
            for var1, var2, corr_val in sorted(strong_corr, key=lambda x: abs(x[2]), reverse=True):
                direction = "positive" if corr_val > 0 else "negative"
                print(f"  {var1} ↔ {var2}: {corr_val:.3f} ({direction})")
        else:
            print(f"\n📊 No strong correlations found (|r| > 0.5)")

    else:
        print("❌ Not enough numeric variables for correlation analysis")

def data_quality_assessment(df):
    """Assess data quality issues"""

    print("\n" + "="*60)
    print("🔍 DATA QUALITY ASSESSMENT")
    print("="*60)

    total_records = len(df)

    # Duplicate analysis
    duplicates = df.duplicated()
    print(f"🔄 Duplicate Records:")
    print(f"  Total duplicates: {duplicates.sum():,} ({(duplicates.sum()/total_records*100):.2f}%)")

    if 'canonical_tx_id' in df.columns:
        tx_id_dups = df['canonical_tx_id'].duplicated()
        print(f"  Duplicate transaction IDs: {tx_id_dups.sum():,}")

    # Anomaly detection for amounts
    if 'amount' in df.columns:
        amounts = df['amount'].dropna()

        # Statistical outliers (using IQR method)
        Q1 = amounts.quantile(0.25)
        Q3 = amounts.quantile(0.75)
        IQR = Q3 - Q1
        lower_bound = Q1 - 1.5 * IQR
        upper_bound = Q3 + 1.5 * IQR

        outliers = amounts[(amounts < lower_bound) | (amounts > upper_bound)]

        print(f"\n💰 Transaction Amount Quality:")
        print(f"  Negative amounts: {(amounts < 0).sum():,}")
        print(f"  Zero amounts: {(amounts == 0).sum():,}")
        print(f"  Statistical outliers: {len(outliers):,} ({(len(outliers)/len(amounts)*100):.2f}%)")
        print(f"  Outlier range: < ₱{lower_bound:.2f} or > ₱{upper_bound:.2f}")

        if len(outliers) > 0:
            print(f"  Largest outlier: ₱{outliers.max():.2f}")
            print(f"  Smallest outlier: ₱{outliers.min():.2f}")

    # Missing value patterns
    missing_patterns = df.isnull().sum()
    if missing_patterns.sum() > 0:
        print(f"\n❓ Missing Value Patterns:")
        for col, missing in missing_patterns[missing_patterns > 0].items():
            pct = (missing / total_records * 100)
            print(f"  {col}: {missing:,} ({pct:.1f}%)")

def generate_executive_summary(df):
    """Generate executive summary of key insights"""

    print("\n" + "="*80)
    print("📋 EXECUTIVE SUMMARY")
    print("="*80)

    # Key metrics
    total_txns = len(df)

    if 'amount' in df.columns:
        total_revenue = df['amount'].sum()
        avg_transaction = df['amount'].mean()

        print(f"💼 Business Metrics:")
        print(f"  • Total Transactions: {total_txns:,}")
        print(f"  • Total Revenue: ₱{total_revenue:,.2f}")
        print(f"  • Average Transaction Value: ₱{avg_transaction:.2f}")

    # Geographic footprint
    if 'store_id' in df.columns:
        stores = df['store_id'].nunique()
        print(f"  • Active Stores: {stores}")

    if 'location_city' in df.columns:
        cities = df['location_city'].nunique()
        print(f"  • Cities Covered: {cities}")

    # Brand portfolio
    if 'brand_name' in df.columns:
        brands = df['brand_name'].nunique()
        top_brand = df['brand_name'].mode()[0]
        print(f"  • Brand Portfolio: {brands} unique brands")
        print(f"  • Leading Brand: {top_brand}")

    # Customer insights
    if 'gender' in df.columns:
        gender_split = df['gender'].value_counts(normalize=True).round(2)
        print(f"  • Customer Gender Split: {dict(gender_split)}")

    # Data quality
    missing_pct = (df.isnull().sum().sum() / (len(df) * len(df.columns)) * 100)
    print(f"  • Data Completeness: {100 - missing_pct:.1f}%")

    if 'timestamp' in df.columns:
        date_range = (pd.to_datetime(df['timestamp']).max() - pd.to_datetime(df['timestamp']).min()).days
        print(f"  • Data Time Span: {date_range} days")

def run_full_eda():
    """Run complete EDA analysis"""

    print("🔍 SCOUT PRODUCTION DATA - COMPREHENSIVE EDA")
    print(f"Analysis Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*80)

    # Load data
    df = load_production_data()
    if df is None:
        return

    # Run all analyses
    basic_info_summary(df)
    financial_analysis(df)
    geographic_analysis(df)
    brand_analysis(df)
    customer_analysis(df)
    temporal_analysis(df)
    correlation_analysis(df)
    data_quality_assessment(df)
    generate_executive_summary(df)

    print("\n" + "="*80)
    print("✅ EDA ANALYSIS COMPLETE")
    print("="*80)

    return df

if __name__ == "__main__":
    df = run_full_eda()