#!/usr/bin/env python3
"""
Cost-Effective Scout Data Factory - No Additional Azure Costs
Uses existing Scout infrastructure to deliver Dan Ryan's enhanced analytics
"""

import os
import pandas as pd
import sqlite3
from datetime import datetime, timedelta
import json

class ScoutDataFactory:
    """
    Cost-effective data factory using existing Scout database and local processing
    Generates enhanced analytics without additional Azure service costs
    """

    def __init__(self, connection_string=None):
        self.connection_string = connection_string or os.getenv('SCOUT_CONNECTION_STRING')
        self.output_dir = os.getenv('OUTPUT_DIR', './out/enhanced_analytics')
        os.makedirs(self.output_dir, exist_ok=True)

        # Analytics metadata
        self.analytics_catalog = {
            "generated_at": datetime.now().isoformat(),
            "period": "Last 3 months",
            "categories": ["Overall", "Tobacco", "Laundry"],
            "analyses": []
        }

    def generate_overall_store_analytics(self):
        """Overall store demographic analysis"""
        print("📊 Generating Overall Store Demographics...")

        # Store profiles query
        store_profiles_query = """
        WITH store_summary AS (
            SELECT
                store_id,
                store_name,
                region,
                COUNT(DISTINCT canonical_tx_id) as total_transactions,
                SUM(transaction_value) as total_revenue,
                AVG(transaction_value) as avg_transaction_value,
                AVG(basket_size) as avg_basket_size,
                COUNT(DISTINCT CASE
                    WHEN demographics LIKE '%Male%' THEN canonical_tx_id
                END) as male_transactions,
                COUNT(DISTINCT CASE
                    WHEN demographics LIKE '%Female%' THEN canonical_tx_id
                END) as female_transactions
            FROM gold.v_export_projection
            WHERE transaction_date >= DATEADD(MONTH, -3, GETDATE())
            GROUP BY store_id, store_name, region
        )
        SELECT *,
            CASE
                WHEN total_revenue > 100000 THEN 'High Volume'
                WHEN total_revenue > 50000 THEN 'Medium Volume'
                ELSE 'Low Volume'
            END as store_tier,
            ROUND(male_transactions * 100.0 / NULLIF(total_transactions, 0), 1) as male_percentage,
            ROUND(female_transactions * 100.0 / NULLIF(total_transactions, 0), 1) as female_percentage
        FROM store_summary
        ORDER BY total_revenue DESC
        """

        # Sales spread across week and month
        temporal_analysis_query = """
        SELECT
            DATENAME(WEEKDAY, transaction_date) as day_of_week,
            DATEPART(HOUR, transaction_date) as hour_of_day,
            daypart,
            region,
            COUNT(canonical_tx_id) as transaction_count,
            SUM(transaction_value) as total_revenue,
            AVG(transaction_value) as avg_transaction_value
        FROM gold.v_export_projection
        WHERE transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY DATENAME(WEEKDAY, transaction_date), DATEPART(HOUR, transaction_date),
                 daypart, region
        ORDER BY day_of_week, hour_of_day
        """

        # Category spread by time
        category_temporal_query = """
        SELECT
            p.category,
            DATENAME(WEEKDAY, t.transaction_date) as day_of_week,
            t.daypart,
            COUNT(t.canonical_tx_id) as transactions,
            SUM(p.line_total) as category_revenue,
            AVG(p.line_total) as avg_revenue_per_transaction
        FROM gold.v_export_projection t
        LEFT JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
            AND p.category IS NOT NULL
        GROUP BY p.category, DATENAME(WEEKDAY, t.transaction_date), t.daypart
        ORDER BY category_revenue DESC
        """

        # Save queries for execution
        analyses = [
            {"name": "store_profiles", "query": store_profiles_query, "description": "Store performance and demographics"},
            {"name": "temporal_analysis", "query": temporal_analysis_query, "description": "Sales patterns across time"},
            {"name": "category_temporal", "query": category_temporal_query, "description": "Category performance by time"}
        ]

        self.analytics_catalog["analyses"].extend([
            {"section": "Overall", "analyses": analyses}
        ])

        return analyses

    def generate_tobacco_analytics(self):
        """Enhanced tobacco category analysis"""
        print("🚬 Generating Enhanced Tobacco Analytics...")

        # Demographics with brand breakdown
        tobacco_demographics_query = """
        SELECT
            p.brand,
            p.product_name,
            t.store_name,
            t.region,
            CASE
                WHEN t.demographics LIKE '%Male%' THEN 'Male'
                WHEN t.demographics LIKE '%Female%' THEN 'Female'
                ELSE 'Unknown'
            END as gender,
            CASE
                WHEN t.demographics LIKE '%16-19%' THEN '16-19'
                WHEN t.demographics LIKE '%20-29%' THEN '20-29'
                WHEN t.demographics LIKE '%30-39%' THEN '30-39'
                WHEN t.demographics LIKE '%40-49%' THEN '40-49'
                WHEN t.demographics LIKE '%50-59%' THEN '50-59'
                ELSE 'Unknown'
            END as age_group,
            COUNT(t.canonical_tx_id) as transactions,
            SUM(p.quantity) as total_sticks,
            AVG(p.quantity) as avg_sticks_per_visit,
            SUM(p.line_total) as total_revenue,
            AVG(p.line_total) as avg_revenue_per_transaction,
            AVG(p.unit_price) as avg_price_per_stick
        FROM gold.v_export_projection t
        INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE p.category = 'Tobacco Products'
            AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY p.brand, p.product_name, t.store_name, t.region,
                 CASE WHEN t.demographics LIKE '%Male%' THEN 'Male' WHEN t.demographics LIKE '%Female%' THEN 'Female' ELSE 'Unknown' END,
                 CASE WHEN t.demographics LIKE '%16-19%' THEN '16-19' WHEN t.demographics LIKE '%20-29%' THEN '20-29' WHEN t.demographics LIKE '%30-39%' THEN '30-39' WHEN t.demographics LIKE '%40-49%' THEN '40-49' WHEN t.demographics LIKE '%50-59%' THEN '50-59' ELSE 'Unknown' END
        ORDER BY total_revenue DESC
        """

        # Purchase profile with "pecha de peligro"
        tobacco_pecha_analysis_query = """
        SELECT
            p.brand,
            DATENAME(WEEKDAY, t.transaction_date) as day_of_week,
            t.daypart,
            DAY(t.transaction_date) as day_of_month,
            CASE
                WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro (15-31)'
                ELSE 'First Half (1-14)'
            END as month_period,
            COUNT(t.canonical_tx_id) as transactions,
            SUM(p.quantity) as total_sticks,
            AVG(p.quantity) as avg_sticks_per_visit,
            SUM(p.line_total) as total_sales,
            AVG(p.line_total) as avg_transaction_value
        FROM gold.v_export_projection t
        INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE p.category = 'Tobacco Products'
            AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY p.brand, DATENAME(WEEKDAY, t.transaction_date), t.daypart,
                 DAY(t.transaction_date),
                 CASE WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro (15-31)' ELSE 'First Half (1-14)' END
        ORDER BY total_sales DESC
        """

        # Basket analysis - what's purchased with cigarettes
        tobacco_basket_query = """
        WITH tobacco_transactions AS (
            SELECT DISTINCT canonical_tx_id, brand
            FROM silver.transaction_products
            WHERE category = 'Tobacco Products'
        ),
        companion_products AS (
            SELECT
                tt.brand as tobacco_brand,
                p.category as companion_category,
                p.product_name as companion_product,
                COUNT(DISTINCT p.canonical_tx_id) as co_purchase_count,
                AVG(p.quantity) as avg_companion_quantity,
                SUM(p.line_total) as total_companion_revenue
            FROM tobacco_transactions tt
            INNER JOIN silver.transaction_products p ON tt.canonical_tx_id = p.canonical_tx_id
            WHERE p.category != 'Tobacco Products'
            GROUP BY tt.brand, p.category, p.product_name
            HAVING COUNT(DISTINCT p.canonical_tx_id) >= 5
        )
        SELECT *,
            co_purchase_count * 100.0 / (
                SELECT COUNT(DISTINCT canonical_tx_id)
                FROM silver.transaction_products
                WHERE category = 'Tobacco Products'
            ) as co_purchase_percentage
        FROM companion_products
        ORDER BY co_purchase_percentage DESC
        """

        # Purchase terms analysis
        tobacco_terms_query = """
        SELECT
            p.brand,
            p.product_name,
            CASE
                WHEN t.audio_transcript LIKE '%yosi%' THEN 'yosi'
                WHEN t.audio_transcript LIKE '%sigarilyo%' THEN 'sigarilyo'
                WHEN t.audio_transcript LIKE '%cigarette%' THEN 'cigarette'
                WHEN t.audio_transcript LIKE '%stick%' THEN 'stick'
                WHEN t.audio_transcript LIKE '%pack%' THEN 'pack'
                ELSE 'other'
            END as purchase_term,
            COUNT(t.canonical_tx_id) as usage_count,
            STRING_AGG(LEFT(t.audio_transcript, 100), '; ') as sample_transcripts
        FROM gold.v_export_projection t
        INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE p.category = 'Tobacco Products'
            AND t.audio_transcript IS NOT NULL
            AND LEN(t.audio_transcript) > 5
            AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY p.brand, p.product_name,
                 CASE WHEN t.audio_transcript LIKE '%yosi%' THEN 'yosi' WHEN t.audio_transcript LIKE '%sigarilyo%' THEN 'sigarilyo' WHEN t.audio_transcript LIKE '%cigarette%' THEN 'cigarette' WHEN t.audio_transcript LIKE '%stick%' THEN 'stick' WHEN t.audio_transcript LIKE '%pack%' THEN 'pack' ELSE 'other' END
        ORDER BY usage_count DESC
        """

        analyses = [
            {"name": "tobacco_demographics", "query": tobacco_demographics_query, "description": "Demographics by brand and age/gender"},
            {"name": "tobacco_pecha_analysis", "query": tobacco_pecha_analysis_query, "description": "Purchase patterns with pecha de peligro analysis"},
            {"name": "tobacco_basket", "query": tobacco_basket_query, "description": "Products purchased with cigarettes"},
            {"name": "tobacco_terms", "query": tobacco_terms_query, "description": "Common terms used for tobacco purchases"}
        ]

        self.analytics_catalog["analyses"].extend([
            {"section": "Tobacco", "analyses": analyses}
        ])

        return analyses

    def generate_laundry_analytics(self):
        """Enhanced laundry category analysis"""
        print("🧺 Generating Enhanced Laundry Analytics...")

        # Demographics with product type breakdown
        laundry_demographics_query = """
        SELECT
            p.brand,
            p.product_name,
            CASE
                WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap'
                WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent'
                WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
                ELSE 'Other Laundry'
            END as product_type,
            t.store_name,
            t.region,
            CASE
                WHEN t.demographics LIKE '%Male%' THEN 'Male'
                WHEN t.demographics LIKE '%Female%' THEN 'Female'
                ELSE 'Unknown'
            END as gender,
            CASE
                WHEN t.demographics LIKE '%16-19%' THEN '16-19'
                WHEN t.demographics LIKE '%20-29%' THEN '20-29'
                WHEN t.demographics LIKE '%30-39%' THEN '30-39'
                WHEN t.demographics LIKE '%40-49%' THEN '40-49'
                WHEN t.demographics LIKE '%50-59%' THEN '50-59'
                ELSE 'Unknown'
            END as age_group,
            COUNT(t.canonical_tx_id) as transactions,
            SUM(p.quantity) as total_units,
            AVG(p.quantity) as avg_units_per_visit,
            SUM(p.line_total) as total_revenue,
            AVG(p.line_total) as avg_revenue_per_transaction
        FROM gold.v_export_projection t
        INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE (p.category LIKE '%Laundry%' OR p.category LIKE '%Detergent%' OR p.category LIKE '%Soap%')
            AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY p.brand, p.product_name,
                 CASE WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
                 t.store_name, t.region,
                 CASE WHEN t.demographics LIKE '%Male%' THEN 'Male' WHEN t.demographics LIKE '%Female%' THEN 'Female' ELSE 'Unknown' END,
                 CASE WHEN t.demographics LIKE '%16-19%' THEN '16-19' WHEN t.demographics LIKE '%20-29%' THEN '20-29' WHEN t.demographics LIKE '%30-39%' THEN '30-39' WHEN t.demographics LIKE '%40-49%' THEN '40-49' WHEN t.demographics LIKE '%50-59%' THEN '50-59' ELSE 'Unknown' END
        ORDER BY total_revenue DESC
        """

        # Pecha de peligro analysis for laundry
        laundry_pecha_analysis_query = """
        SELECT
            p.brand,
            CASE
                WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap'
                WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent'
                WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
                ELSE 'Other Laundry'
            END as product_type,
            DATENAME(WEEKDAY, t.transaction_date) as day_of_week,
            t.daypart,
            DAY(t.transaction_date) as day_of_month,
            CASE
                WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro (15-31)'
                ELSE 'First Half (1-14)'
            END as month_period,
            COUNT(t.canonical_tx_id) as transactions,
            SUM(p.quantity) as total_units,
            AVG(p.quantity) as avg_units_per_visit,
            SUM(p.line_total) as total_sales,
            AVG(p.line_total) as avg_transaction_value
        FROM gold.v_export_projection t
        INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE (p.category LIKE '%Laundry%' OR p.category LIKE '%Detergent%' OR p.category LIKE '%Soap%')
            AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY p.brand,
                 CASE WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
                 DATENAME(WEEKDAY, t.transaction_date), t.daypart,
                 DAY(t.transaction_date),
                 CASE WHEN DAY(t.transaction_date) BETWEEN 15 AND 31 THEN 'Pecha de Peligro (15-31)' ELSE 'First Half (1-14)' END
        ORDER BY total_sales DESC
        """

        # Fabcon co-purchase analysis
        laundry_fabcon_query = """
        WITH laundry_transactions AS (
            SELECT DISTINCT canonical_tx_id, brand, product_name
            FROM silver.transaction_products
            WHERE category LIKE '%Laundry%' OR category LIKE '%Detergent%' OR category LIKE '%Soap%'
        ),
        fabcon_purchases AS (
            SELECT
                lt.brand as laundry_brand,
                CASE
                    WHEN lt.product_name LIKE '%bar%' OR lt.product_name LIKE '%soap%' THEN 'Bar Soap'
                    WHEN lt.product_name LIKE '%powder%' OR lt.product_name LIKE '%detergent%' THEN 'Powder Detergent'
                    WHEN lt.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
                    ELSE 'Other Laundry'
                END as laundry_type,
                p.brand as fabcon_brand,
                p.product_name as fabcon_product,
                COUNT(DISTINCT p.canonical_tx_id) as co_purchase_count,
                AVG(p.quantity) as avg_fabcon_quantity,
                SUM(p.line_total) as total_fabcon_revenue
            FROM laundry_transactions lt
            INNER JOIN silver.transaction_products p ON lt.canonical_tx_id = p.canonical_tx_id
            WHERE (p.product_name LIKE '%fabcon%' OR p.product_name LIKE '%fabric%' OR p.product_name LIKE '%conditioner%')
            GROUP BY lt.brand,
                     CASE WHEN lt.product_name LIKE '%bar%' OR lt.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN lt.product_name LIKE '%powder%' OR lt.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN lt.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
                     p.brand, p.product_name
            HAVING COUNT(DISTINCT p.canonical_tx_id) >= 3
        )
        SELECT *,
            co_purchase_count * 100.0 / (
                SELECT COUNT(DISTINCT canonical_tx_id)
                FROM silver.transaction_products
                WHERE category LIKE '%Laundry%'
            ) as co_purchase_percentage
        FROM fabcon_purchases
        ORDER BY co_purchase_percentage DESC
        """

        # Purchase terms for laundry
        laundry_terms_query = """
        SELECT
            p.brand,
            p.product_name,
            CASE
                WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap'
                WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent'
                WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent'
                ELSE 'Other Laundry'
            END as product_type,
            CASE
                WHEN t.audio_transcript LIKE '%sabon%' THEN 'sabon'
                WHEN t.audio_transcript LIKE '%detergent%' THEN 'detergent'
                WHEN t.audio_transcript LIKE '%labada%' THEN 'labada'
                WHEN t.audio_transcript LIKE '%washing%' THEN 'washing'
                WHEN t.audio_transcript LIKE '%powder%' THEN 'powder'
                WHEN t.audio_transcript LIKE '%bar%' THEN 'bar'
                WHEN t.audio_transcript LIKE '%fabcon%' THEN 'fabcon'
                ELSE 'other'
            END as purchase_term,
            COUNT(t.canonical_tx_id) as usage_count,
            STRING_AGG(LEFT(t.audio_transcript, 100), '; ') as sample_transcripts
        FROM gold.v_export_projection t
        INNER JOIN silver.transaction_products p ON t.canonical_tx_id = p.canonical_tx_id
        WHERE (p.category LIKE '%Laundry%' OR p.category LIKE '%Detergent%' OR p.category LIKE '%Soap%')
            AND t.audio_transcript IS NOT NULL
            AND LEN(t.audio_transcript) > 5
            AND t.transaction_date >= DATEADD(MONTH, -3, GETDATE())
        GROUP BY p.brand, p.product_name,
                 CASE WHEN p.product_name LIKE '%bar%' OR p.product_name LIKE '%soap%' THEN 'Bar Soap' WHEN p.product_name LIKE '%powder%' OR p.product_name LIKE '%detergent%' THEN 'Powder Detergent' WHEN p.product_name LIKE '%liquid%' THEN 'Liquid Detergent' ELSE 'Other Laundry' END,
                 CASE WHEN t.audio_transcript LIKE '%sabon%' THEN 'sabon' WHEN t.audio_transcript LIKE '%detergent%' THEN 'detergent' WHEN t.audio_transcript LIKE '%labada%' THEN 'labada' WHEN t.audio_transcript LIKE '%washing%' THEN 'washing' WHEN t.audio_transcript LIKE '%powder%' THEN 'powder' WHEN t.audio_transcript LIKE '%bar%' THEN 'bar' WHEN t.audio_transcript LIKE '%fabcon%' THEN 'fabcon' ELSE 'other' END
        ORDER BY usage_count DESC
        """

        analyses = [
            {"name": "laundry_demographics", "query": laundry_demographics_query, "description": "Demographics by product type (bar/powder/liquid)"},
            {"name": "laundry_pecha_analysis", "query": laundry_pecha_analysis_query, "description": "Purchase patterns with pecha de peligro analysis"},
            {"name": "laundry_fabcon", "query": laundry_fabcon_query, "description": "Detergent + Fabcon co-purchase patterns"},
            {"name": "laundry_terms", "query": laundry_terms_query, "description": "Common terms used for laundry purchases"}
        ]

        self.analytics_catalog["analyses"].extend([
            {"section": "Laundry", "analyses": analyses}
        ])

        return analyses

    def export_sql_files(self):
        """Export all queries as executable SQL files"""
        print("💾 Exporting SQL queries for direct execution...")

        all_analyses = []
        all_analyses.extend(self.generate_overall_store_analytics())
        all_analyses.extend(self.generate_tobacco_analytics())
        all_analyses.extend(self.generate_laundry_analytics())

        # Create combined SQL file
        combined_sql_path = os.path.join(self.output_dir, 'dan_ryan_enhanced_analytics.sql')
        with open(combined_sql_path, 'w', encoding='utf-8') as f:
            f.write("-- Enhanced Scout Analytics - Dan Ryan's Requirements\n")
            f.write(f"-- Generated: {datetime.now().isoformat()}\n")
            f.write("-- Period: Last 3 months\n\n")

            for analysis in all_analyses:
                f.write(f"-- {analysis['name'].upper()}: {analysis['description']}\n")
                f.write("-" * 70 + "\n\n")
                f.write(analysis['query'])
                f.write("\n\n")

        # Export metadata
        catalog_path = os.path.join(self.output_dir, 'analytics_catalog.json')
        with open(catalog_path, 'w') as f:
            json.dump(self.analytics_catalog, f, indent=2)

        print(f"✅ SQL queries exported to: {combined_sql_path}")
        print(f"✅ Analytics catalog saved: {catalog_path}")

        return combined_sql_path, catalog_path

    def generate_excel_template(self):
        """Generate Excel template for enhanced analytics"""
        print("📊 Creating Excel template for enhanced insights...")

        excel_path = os.path.join(self.output_dir, 'enhanced_scout_analytics_template.xlsx')

        # Create sample data structure
        sample_data = {
            'Overall_Store_Profiles': pd.DataFrame({
                'store_id': ['ST001', 'ST002', 'ST003'],
                'store_name': ['Store A', 'Store B', 'Store C'],
                'region': ['NCR', 'NCR', 'Visayas'],
                'total_transactions': [1500, 1200, 800],
                'total_revenue': [180000, 150000, 95000],
                'avg_transaction_value': [120.00, 125.00, 118.75],
                'store_tier': ['High Volume', 'Medium Volume', 'Low Volume'],
                'male_percentage': [78.5, 80.2, 75.8],
                'female_percentage': [21.5, 19.8, 24.2]
            }),

            'Tobacco_Demographics': pd.DataFrame({
                'brand': ['Marlboro', 'Philip Morris', 'Fortune'],
                'product_name': ['Marlboro Red', 'Philip Morris Blue', 'Fortune Red'],
                'gender': ['Male', 'Male', 'Male'],
                'age_group': ['30-39', '30-39', '40-49'],
                'transactions': [150, 120, 95],
                'total_sticks': [248, 216, 142],
                'avg_sticks_per_visit': [1.65, 1.8, 1.49],
                'total_revenue': [37800, 36000, 14250],
                'avg_price_per_stick': [152.4, 166.7, 100.4]
            }),

            'Tobacco_Pecha_Analysis': pd.DataFrame({
                'brand': ['Marlboro', 'Philip Morris', 'Fortune'],
                'day_of_week': ['Sunday', 'Monday', 'Friday'],
                'daypart': ['Morning', 'Morning', 'Afternoon'],
                'month_period': ['Pecha de Peligro (15-31)', 'First Half (1-14)', 'Pecha de Peligro (15-31)'],
                'transactions': [45, 38, 28],
                'total_sticks': [74, 68, 42],
                'avg_sticks_per_visit': [1.64, 1.79, 1.5],
                'total_sales': [11340, 11424, 4200],
                'avg_transaction_value': [252.0, 300.6, 150.0]
            }),

            'Laundry_Demographics': pd.DataFrame({
                'brand': ['Ariel', 'Tide', 'Surf'],
                'product_type': ['Powder Detergent', 'Powder Detergent', 'Bar Soap'],
                'gender': ['Male', 'Male', 'Female'],
                'age_group': ['30-39', '30-39', '30-39'],
                'transactions': [280, 245, 185],
                'total_units': [420, 368, 185],
                'avg_units_per_visit': [1.5, 1.5, 1.0],
                'total_revenue': [12600, 12250, 5550],
                'avg_revenue_per_transaction': [45.0, 50.0, 30.0]
            }),

            'Laundry_Fabcon_Analysis': pd.DataFrame({
                'laundry_brand': ['Ariel', 'Tide', 'Surf'],
                'laundry_type': ['Powder Detergent', 'Powder Detergent', 'Bar Soap'],
                'fabcon_brand': ['Downy', 'Downy', 'Comfort'],
                'fabcon_product': ['Downy Sunrise Fresh', 'Downy Ocean Mist', 'Comfort Pure'],
                'co_purchase_count': [45, 38, 22],
                'co_purchase_percentage': [16.1, 15.5, 11.9],
                'avg_fabcon_quantity': [1.2, 1.3, 1.0],
                'total_fabcon_revenue': [1350, 1520, 660]
            })
        }

        # Write to Excel with multiple sheets
        with pd.ExcelWriter(excel_path, engine='xlsxwriter') as writer:
            for sheet_name, df in sample_data.items():
                df.to_excel(writer, sheet_name=sheet_name, index=False)

                # Format sheets
                workbook = writer.book
                worksheet = writer.sheets[sheet_name]

                # Add header formatting
                header_format = workbook.add_format({
                    'bold': True,
                    'text_wrap': True,
                    'valign': 'top',
                    'fg_color': '#D7E4BC',
                    'border': 1
                })

                # Apply header format
                for col_num, value in enumerate(df.columns.values):
                    worksheet.write(0, col_num, value, header_format)

                # Auto-fit columns
                worksheet.set_column(0, len(df.columns) - 1, 15)

        print(f"✅ Excel template created: {excel_path}")
        return excel_path

def main():
    """Main execution function"""
    print("🏭 COST-EFFECTIVE SCOUT DATA FACTORY")
    print("=" * 60)
    print("Generating enhanced analytics without additional Azure costs")
    print()

    factory = ScoutDataFactory()

    # Generate all analytics
    sql_file, catalog_file = factory.export_sql_files()
    excel_template = factory.generate_excel_template()

    print("\n🎉 DATA FACTORY COMPLETE!")
    print("=" * 60)
    print("✅ Enhanced SQL queries ready for execution")
    print("✅ Excel template created for presentation")
    print("✅ Analytics catalog generated")
    print()
    print("📁 Output Files:")
    print(f"   - SQL: {sql_file}")
    print(f"   - Excel: {excel_template}")
    print(f"   - Catalog: {catalog_file}")
    print()
    print("🚀 Next Steps:")
    print("   1. Execute SQL queries against Scout database")
    print("   2. Export results to Excel using template structure")
    print("   3. Share enhanced pivot tables with Dan Ryan & Jaymie")

if __name__ == "__main__":
    main()