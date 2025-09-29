#!/usr/bin/env python3
"""
Revenue Analysis by Category and Subcategory
Professional Excel report with revenue breakdowns
"""

import pandas as pd
import subprocess
import json
from datetime import datetime

def execute_sql_query(query):
    """Execute SQL query using scripts/sql.sh wrapper"""
    try:
        result = subprocess.run([
            './scripts/sql.sh', '-Q', query
        ], capture_output=True, text=True, check=True)

        if result.returncode == 0 and result.stdout.strip():
            # Parse CSV output
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                headers = [h.strip() for h in lines[0].split(',')]
                data = []
                for line in lines[1:]:
                    if line.strip():
                        row = [cell.strip() for cell in line.split(',')]
                        data.append(row)

                return pd.DataFrame(data, columns=headers)
        return None
    except Exception as e:
        print(f"❌ SQL Query failed: {str(e)}")
        return None

def create_revenue_analysis_excel():
    """Create comprehensive revenue analysis Excel report"""

    print("💰 REVENUE BY CATEGORY AND SUBCATEGORY ANALYSIS")
    print("=" * 60)

    # Define queries
    queries = {
        'category_summary': """
        SELECT
            category,
            COUNT(*) as transaction_count,
            FORMAT(SUM(transaction_value), 'N2') as total_revenue,
            FORMAT(AVG(transaction_value), 'N2') as avg_transaction_value,
            COUNT(DISTINCT store_id) as active_stores
        FROM gold.v_export_projection
        WHERE category IS NOT NULL
            AND transaction_value > 0
            AND canonical_tx_id IS NOT NULL
        GROUP BY category
        ORDER BY SUM(transaction_value) DESC
        """,

        'subcategory_breakdown': """
        SELECT
            category,
            subcategory,
            COUNT(*) as transaction_count,
            FORMAT(SUM(transaction_value), 'N2') as total_revenue,
            FORMAT(AVG(transaction_value), 'N2') as avg_transaction_value,
            CAST(ROUND((SUM(transaction_value) * 100.0 / SUM(SUM(transaction_value)) OVER()), 2) AS DECIMAL(10,2)) as revenue_percentage
        FROM gold.v_export_projection
        WHERE category IS NOT NULL
            AND subcategory IS NOT NULL
            AND transaction_value > 0
            AND canonical_tx_id IS NOT NULL
        GROUP BY category, subcategory
        ORDER BY SUM(transaction_value) DESC
        """,

        'top_performers': """
        SELECT TOP 15
            category,
            subcategory,
            FORMAT(SUM(transaction_value), 'N2') as total_revenue,
            COUNT(*) as transaction_count,
            FORMAT(AVG(transaction_value), 'N2') as avg_transaction_value
        FROM gold.v_export_projection
        WHERE category IS NOT NULL
            AND subcategory IS NOT NULL
            AND transaction_value > 0
            AND canonical_tx_id IS NOT NULL
        GROUP BY category, subcategory
        ORDER BY SUM(transaction_value) DESC
        """
    }

    # Execute queries and collect data
    datasets = {}
    for name, query in queries.items():
        print(f"📊 Executing {name} query...")
        df = execute_sql_query(query)
        if df is not None and not df.empty:
            datasets[name] = df
            print(f"✅ {name}: {len(df)} records")
        else:
            print(f"❌ {name}: No data returned")

    if not datasets:
        print("❌ No data available - database may be offline")
        return None

    # Create Excel report
    output_file = 'out/enhanced_analytics/revenue_by_category_analysis.xlsx'

    try:
        with pd.ExcelWriter(output_file, engine='xlsxwriter') as writer:
            workbook = writer.book

            # Define professional formats
            title_format = workbook.add_format({
                'bold': True,
                'font_size': 16,
                'font_color': '#2E5594',
                'align': 'center'
            })

            header_format = workbook.add_format({
                'bold': True,
                'text_wrap': True,
                'valign': 'top',
                'fg_color': '#2E5594',
                'font_color': 'white',
                'border': 2,
                'border_color': '#1F4E79',
                'font_size': 11
            })

            data_format = workbook.add_format({
                'text_wrap': False,
                'valign': 'top',
                'border': 1,
                'border_color': '#D0D0D0',
                'font_size': 10
            })

            currency_format = workbook.add_format({
                'num_format': '₱#,##0.00',
                'border': 1,
                'border_color': '#D0D0D0',
                'font_size': 10
            })

            percentage_format = workbook.add_format({
                'num_format': '0.00%',
                'border': 1,
                'border_color': '#D0D0D0',
                'font_size': 10
            })

            # Write each dataset to a worksheet
            worksheet_names = {
                'category_summary': 'Category Summary',
                'subcategory_breakdown': 'Subcategory Breakdown',
                'top_performers': 'Top Performers'
            }

            for dataset_name, df in datasets.items():
                sheet_name = worksheet_names.get(dataset_name, dataset_name)

                # Write data
                df.to_excel(writer, sheet_name=sheet_name, index=False, startrow=2)
                worksheet = writer.sheets[sheet_name]

                # Add title
                title = f"REVENUE ANALYSIS - {sheet_name.upper()}"
                worksheet.merge_range(0, 0, 0, len(df.columns)-1, title, title_format)

                # Format headers
                for col_num, value in enumerate(df.columns.values):
                    worksheet.write(2, col_num, value, header_format)

                # Format data
                for row_num in range(len(df)):
                    for col_num in range(len(df.columns)):
                        cell_value = df.iloc[row_num, col_num]

                        # Apply appropriate formatting
                        if 'revenue' in df.columns[col_num].lower() and 'percentage' not in df.columns[col_num].lower():
                            worksheet.write(row_num + 3, col_num, cell_value, currency_format)
                        elif 'percentage' in df.columns[col_num].lower():
                            worksheet.write(row_num + 3, col_num, float(cell_value)/100 if str(cell_value).replace('.','').isdigit() else cell_value, percentage_format)
                        else:
                            worksheet.write(row_num + 3, col_num, cell_value, data_format)

                # Auto-adjust column widths
                for i, col in enumerate(df.columns):
                    max_len = max(
                        df[col].astype(str).map(len).max() if df[col].notna().any() else 0,
                        len(str(col))
                    ) + 2
                    worksheet.set_column(i, i, min(max_len, 25))

        print(f"\n🎉 REVENUE ANALYSIS EXCEL GENERATED!")
        print(f"📁 Output: {output_file}")
        print(f"📊 Worksheets created:")
        for dataset_name in datasets.keys():
            sheet_name = worksheet_names.get(dataset_name, dataset_name)
            print(f"   • {sheet_name}")

        return output_file

    except Exception as e:
        print(f"❌ Error creating Excel: {str(e)}")
        return None

if __name__ == "__main__":
    create_revenue_analysis_excel()