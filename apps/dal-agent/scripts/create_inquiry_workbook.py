#!/usr/bin/env python3

"""
Scout Inquiry Analytics Workbook Generator
Creates a comprehensive Excel workbook from all inquiry export CSVs
Organizes data into logical worksheets for business analysis
"""

import pandas as pd
import os
import glob
from datetime import datetime
import json

def clean_dataframe(df):
    """Clean SQL artifacts from dataframe"""
    if df.empty:
        return df

    # Remove SQL result messages
    for col in df.columns:
        if df[col].dtype == 'object':  # String columns
            df = df[~df[col].astype(str).str.contains('rows affected|Msg \d+|Level \d+|State \d+|Invalid column', case=False, na=False)]

    # Remove completely empty rows
    df = df.dropna(how='all')

    return df

def create_inquiry_workbook():
    """Create comprehensive Excel workbook from inquiry exports"""

    print("📊 Creating Scout Inquiry Analytics Workbook...")

    # Input and output paths
    input_dir = "out/inquiries_filtered"
    output_file = "out/Scout_Inquiry_Analytics_Workbook.xlsx"

    # Create Excel writer
    with pd.ExcelWriter(output_file, engine='openpyxl') as writer:

        # Track all data for summary
        summary_data = {
            'category': [],
            'worksheet': [],
            'rows': [],
            'key_metrics': []
        }

        # 1. OVERALL STORE ANALYTICS
        print("📈 Processing Overall Store Analytics...")

        # Store Profiles
        if os.path.exists(f"{input_dir}/overall/store_profiles.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/overall/store_profiles.csv.gz"))
            df.to_excel(writer, sheet_name='Store Profiles', index=False)
            summary_data['category'].append('Overall')
            summary_data['worksheet'].append('Store Profiles')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top store: {df.iloc[0]['store_name']} (₱{df.iloc[0]['total_amount']:,.2f})" if len(df) > 0 else "No data")

        # Sales by Week
        if os.path.exists(f"{input_dir}/overall/sales_by_week.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/overall/sales_by_week.csv.gz"))
            df['week_start'] = pd.to_datetime(df['week_start'])
            df.to_excel(writer, sheet_name='Weekly Sales', index=False)
            summary_data['category'].append('Overall')
            summary_data['worksheet'].append('Weekly Sales')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Peak week: {df.loc[df['total_amount'].idxmax(), 'week_start'].strftime('%b %d')} (₱{df['total_amount'].max():,.2f})" if len(df) > 0 else "No data")

        # Daypart by Category
        if os.path.exists(f"{input_dir}/overall/daypart_by_category.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/overall/daypart_by_category.csv.gz"))
            df.to_excel(writer, sheet_name='Daypart Analysis', index=False)
            summary_data['category'].append('Overall')
            summary_data['worksheet'].append('Daypart Analysis')
            summary_data['rows'].append(len(df))
            peak_daypart = df.loc[df['transactions'].idxmax()]
            summary_data['key_metrics'].append(f"Peak: {peak_daypart['daypart']} - {peak_daypart['category']} ({peak_daypart['transactions']} txns)" if len(df) > 0 else "No data")

        # Purchase Demographics
        if os.path.exists(f"{input_dir}/overall/purchase_demographics.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/overall/purchase_demographics.csv.gz"))
            df.to_excel(writer, sheet_name='Purchase Demographics', index=False)
            summary_data['category'].append('Overall')
            summary_data['worksheet'].append('Purchase Demographics')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top segment: {df.iloc[0]['payment_method']} - {df.iloc[0]['daypart']} ({df.iloc[0]['transactions']} txns)" if len(df) > 0 else "No data")

        # 2. TOBACCO ANALYTICS
        print("🚬 Processing Tobacco Analytics...")

        # Tobacco Demographics
        if os.path.exists(f"{input_dir}/tobacco/demo_gender_age_brand.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/tobacco/demo_gender_age_brand.csv.gz"))
            df.to_excel(writer, sheet_name='Tobacco Demographics', index=False)
            summary_data['category'].append('Tobacco')
            summary_data['worksheet'].append('Tobacco Demographics')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top brand: {df.iloc[0]['brand']} ({df.iloc[0]['share_pct']:.1f}%)" if len(df) > 0 else "No data")

        # Tobacco Purchase Patterns (Pecha de Peligro)
        if os.path.exists(f"{input_dir}/tobacco/purchase_profile_pdp.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/tobacco/purchase_profile_pdp.csv.gz"))
            df.to_excel(writer, sheet_name='Tobacco Purchase Patterns', index=False)
            summary_data['category'].append('Tobacco')
            summary_data['worksheet'].append('Tobacco Purchase Patterns')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Peak period: Day {df.loc[df['share_pct'].idxmax(), 'dom_bucket']} ({df['share_pct'].max():.1f}%)" if len(df) > 0 else "No data")

        # Tobacco Daily Sales
        if os.path.exists(f"{input_dir}/tobacco/sales_by_day_daypart.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/tobacco/sales_by_day_daypart.csv.gz"))
            # Clean data and convert dates safely
            df = df[~df['date'].astype(str).str.contains('rows affected|Msg')]
            try:
                df['date'] = pd.to_datetime(df['date'], errors='coerce')
                df = df.dropna(subset=['date'])
            except:
                pass  # Keep original format if conversion fails
            df.to_excel(writer, sheet_name='Tobacco Daily Sales', index=False)
            summary_data['category'].append('Tobacco')
            summary_data['worksheet'].append('Tobacco Daily Sales')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Total days analyzed: {df['date'].nunique()}, Peak daypart: {df.loc[df['transactions'].idxmax(), 'daypart']}" if len(df) > 0 else "No data")

        # Sticks per Visit Analysis
        if os.path.exists(f"{input_dir}/tobacco/sticks_per_visit.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/tobacco/sticks_per_visit.csv.gz"))
            df.to_excel(writer, sheet_name='Sticks Analysis', index=False)
            summary_data['category'].append('Tobacco')
            summary_data['worksheet'].append('Sticks Analysis')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Avg sticks/visit: {df['estimated_sticks'].mean():.1f}, Max: {df['estimated_sticks'].max()}" if len(df) > 0 else "No data")

        # Tobacco Co-purchase
        if os.path.exists(f"{input_dir}/tobacco/copurchase_categories.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/tobacco/copurchase_categories.csv.gz"))
            df.to_excel(writer, sheet_name='Tobacco Co-purchase', index=False)
            summary_data['category'].append('Tobacco')
            summary_data['worksheet'].append('Tobacco Co-purchase')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Categories analyzed: {len(df)}" if len(df) > 0 else "No data")

        # Tobacco Frequent Terms
        if os.path.exists(f"{input_dir}/tobacco/frequent_terms.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/tobacco/frequent_terms.csv.gz"))
            df.to_excel(writer, sheet_name='Tobacco Terms', index=False)
            summary_data['category'].append('Tobacco')
            summary_data['worksheet'].append('Tobacco Terms')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top term: {df.iloc[0]['term']} ({df.iloc[0]['frequency']} mentions)" if len(df) > 0 else "No data")

        # 3. LAUNDRY ANALYTICS
        print("🧼 Processing Laundry Analytics...")

        # Detergent Types
        if os.path.exists(f"{input_dir}/laundry/detergent_type.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/laundry/detergent_type.csv.gz"))
            df.to_excel(writer, sheet_name='Detergent Types', index=False)
            summary_data['category'].append('Laundry')
            summary_data['worksheet'].append('Detergent Types')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Types analyzed: {df['detergent_type'].nunique()}, Fabcon pairing: {df['with_fabcon'].sum()} cases" if len(df) > 0 else "No data")

        # Laundry Demographics
        if os.path.exists(f"{input_dir}/laundry/demo_gender_age_brand.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/laundry/demo_gender_age_brand.csv.gz"))
            df.to_excel(writer, sheet_name='Laundry Demographics', index=False)
            summary_data['category'].append('Laundry')
            summary_data['worksheet'].append('Laundry Demographics')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top brand: {df.iloc[0]['brand']} ({df.iloc[0]['share_pct']:.1f}%)" if len(df) > 0 else "No data")

        # Laundry Purchase Patterns
        if os.path.exists(f"{input_dir}/laundry/purchase_profile_pdp.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/laundry/purchase_profile_pdp.csv.gz"))
            df.to_excel(writer, sheet_name='Laundry Purchase Patterns', index=False)
            summary_data['category'].append('Laundry')
            summary_data['worksheet'].append('Laundry Purchase Patterns')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Peak period: Day {df.loc[df['share_pct'].idxmax(), 'dom_bucket']} ({df['share_pct'].max():.1f}%)" if len(df) > 0 else "No data")

        # Laundry Daily Sales
        if os.path.exists(f"{input_dir}/laundry/sales_by_day_daypart.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/laundry/sales_by_day_daypart.csv.gz"))
            # Clean data and convert dates safely
            df = df[~df['date'].astype(str).str.contains('rows affected|Msg')]
            try:
                df['date'] = pd.to_datetime(df['date'], errors='coerce')
                df = df.dropna(subset=['date'])
            except:
                pass  # Keep original format if conversion fails
            df.to_excel(writer, sheet_name='Laundry Daily Sales', index=False)
            summary_data['category'].append('Laundry')
            summary_data['worksheet'].append('Laundry Daily Sales')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Total days: {df['date'].nunique()}, Peak daypart: {df.loc[df['transactions'].idxmax(), 'daypart']}" if len(df) > 0 else "No data")

        # Laundry Co-purchase
        if os.path.exists(f"{input_dir}/laundry/copurchase_categories.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/laundry/copurchase_categories.csv.gz"))
            df.to_excel(writer, sheet_name='Laundry Co-purchase', index=False)
            summary_data['category'].append('Laundry')
            summary_data['worksheet'].append('Laundry Co-purchase')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top co-purchase: {df.iloc[0]['category']} ({df.iloc[0]['share_pct']:.1f}%)" if len(df) > 0 else "No data")

        # Laundry Frequent Terms
        if os.path.exists(f"{input_dir}/laundry/frequent_terms.csv.gz"):
            df = clean_dataframe(pd.read_csv(f"{input_dir}/laundry/frequent_terms.csv.gz"))
            df.to_excel(writer, sheet_name='Laundry Terms', index=False)
            summary_data['category'].append('Laundry')
            summary_data['worksheet'].append('Laundry Terms')
            summary_data['rows'].append(len(df))
            summary_data['key_metrics'].append(f"Top term: {df.iloc[0]['term']} ({df.iloc[0]['frequency']} mentions)" if len(df) > 0 else "No data")

        # 4. EXECUTIVE SUMMARY DASHBOARD
        print("📋 Creating Executive Summary...")

        summary_df = pd.DataFrame(summary_data)
        summary_df.to_excel(writer, sheet_name='📊 EXECUTIVE SUMMARY', index=False)

        # Create metadata sheet
        metadata = {
            'Generated': [datetime.now().strftime('%Y-%m-%d %H:%M:%S')],
            'Data Period': ['June 28 - September 26, 2025'],
            'Total Worksheets': [len(summary_data['worksheet'])],
            'Total Data Points': [sum(summary_data['rows'])],
            'Categories': ['Overall Store Analytics, Tobacco Analytics, Laundry Analytics'],
            'Source System': ['Scout v7 Analytics Platform'],
            'Database': ['SQL-TBWA-ProjectScout-Reporting-Prod'],
            'Export Method': ['Gold Layer ETL Pipeline']
        }
        metadata_df = pd.DataFrame(metadata)
        metadata_df.to_excel(writer, sheet_name='📄 Metadata', index=False)

    print(f"✅ Workbook created: {output_file}")
    print(f"📊 Total worksheets: {len(summary_data['worksheet']) + 2}")  # +2 for summary and metadata
    print(f"📈 Total data rows: {sum(summary_data['rows']):,}")

    return output_file

if __name__ == "__main__":
    workbook_file = create_inquiry_workbook()
    print(f"🎉 Scout Inquiry Analytics Workbook ready: {workbook_file}")