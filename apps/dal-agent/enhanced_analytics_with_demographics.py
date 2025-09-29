#!/usr/bin/env python3
"""
Enhanced Scout Analytics with Demographics - Excel Report Generator
Combines facial recognition demographics with tobacco and laundry analytics
"""

import pandas as pd
from datetime import datetime
import json

def create_enhanced_excel_report():
    """Create comprehensive Excel report with real demographics data"""

    print("📊 ENHANCED SCOUT ANALYTICS WITH DEMOGRAPHICS")
    print("=" * 60)

    # Load the generated CSV files
    files_to_load = {
        'Store Demographics': 'out/enhanced_analytics/store_demographics_facial.csv',
        'Tobacco Demographics': 'out/enhanced_analytics/tobacco_demographics.csv',
        'Laundry Demographics': 'out/enhanced_analytics/laundry_demographics.csv',
        'Category Analysis': 'out/enhanced_analytics/category_analysis.csv',
        'NCR Stores': 'out/enhanced_analytics/ncr_stores_demographics.csv'
    }

    # Create Excel writer
    output_file = 'out/enhanced_analytics/dan_ryan_enhanced_demographics_report.xlsx'

    with pd.ExcelWriter(output_file, engine='xlsxwriter') as writer:
        workbook = writer.book

        # Define formats
        header_format = workbook.add_format({
            'bold': True,
            'text_wrap': True,
            'valign': 'top',
            'fg_color': '#4472C4',
            'font_color': 'white',
            'border': 1
        })

        data_format = workbook.add_format({
            'text_wrap': True,
            'valign': 'top',
            'border': 1
        })

        number_format = workbook.add_format({
            'num_format': '#,##0.00',
            'border': 1
        })

        # Load and write each dataset
        for sheet_name, file_path in files_to_load.items():
            try:
                df = pd.read_csv(file_path)
                if not df.empty:
                    # Write to Excel
                    df.to_excel(writer, sheet_name=sheet_name, index=False)

                    # Get worksheet and format
                    worksheet = writer.sheets[sheet_name]

                    # Format headers
                    for col_num, value in enumerate(df.columns.values):
                        worksheet.write(0, col_num, value, header_format)

                    # Auto-adjust column widths
                    for i, col in enumerate(df.columns):
                        max_len = max(
                            df[col].astype(str).map(len).max(),
                            len(str(col))
                        ) + 2
                        worksheet.set_column(i, i, min(max_len, 50))

                    print(f"✅ {sheet_name}: {len(df)} rows")
                else:
                    print(f"⚠️  {sheet_name}: No data available")

            except FileNotFoundError:
                print(f"❌ {sheet_name}: File not found - {file_path}")
            except Exception as e:
                print(f"❌ {sheet_name}: Error - {str(e)}")

        # Add summary dashboard
        summary_data = {
            'Metric': [
                'Total NCR Stores',
                'Active Stores with Data',
                'Tobacco Products Tracked',
                'Laundry Products Tracked',
                'Demographics Source',
                'Report Generated'
            ],
            'Value': [
                '20 NCR Stores',
                'Variable (see Store Demographics tab)',
                'Variable (see Tobacco Demographics tab)',
                'Variable (see Laundry Demographics tab)',
                'Facial Recognition (dbo.SalesInteractions)',
                datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            ],
            'Description': [
                'All active stores in NCR region from dbo.Stores',
                'Stores with transaction data and facial recognition',
                'Tobacco products with age/gender demographics',
                'Laundry products with age/gender demographics',
                'Real demographic data from facial ID system',
                'Auto-generated enhanced analytics report'
            ]
        }

        summary_df = pd.DataFrame(summary_data)
        summary_df.to_excel(writer, sheet_name='Dashboard', index=False)

        dashboard_sheet = writer.sheets['Dashboard']
        for col_num, value in enumerate(summary_df.columns.values):
            dashboard_sheet.write(0, col_num, value, header_format)

        # Auto-adjust dashboard columns
        for i, col in enumerate(summary_df.columns):
            max_len = max(
                summary_df[col].astype(str).map(len).max(),
                len(str(col))
            ) + 2
            dashboard_sheet.set_column(i, i, min(max_len, 60))

    print(f"\n🎉 ENHANCED DEMOGRAPHICS REPORT COMPLETE!")
    print(f"📁 Output: {output_file}")
    print(f"📊 Includes: Facial recognition demographics, NCR store data, tobacco/laundry analytics")

    return output_file

if __name__ == "__main__":
    create_enhanced_excel_report()