#!/usr/bin/env python3
"""
Real Active Stores Report - Only stores with canonical_tx_id transaction data
Professional Excel format with data quality audit
"""

import pandas as pd
from datetime import datetime
import json

def create_real_active_stores_report():
    """Create professional report with only real active stores"""

    print("🏪 REAL ACTIVE STORES WITH TRANSACTION DATA")
    print("=" * 60)
    print("📊 Only stores with canonical_tx_id matches included")

    # Load real active stores data
    stores_file = 'out/enhanced_analytics/real_active_stores.csv'

    try:
        # Read real active stores data with proper column names
        column_names = ['StoreID', 'StoreName', 'Location', 'Region', 'MunicipalityName', 'BarangayName',
                       'Size', 'GeoLatitude', 'GeoLongitude', 'ManagerName', 'ManagerContactInfo', 'DeviceName', 'DeviceID',
                       'TotalTransactions', 'UniqueCustomers', 'AvgTransactionValue', 'FirstTransaction', 'LastTransaction',
                       'TobaccoTransactions', 'LaundryTransactions', 'MaleCustomers', 'FemaleCustomers', 'AvgCustomerAge']

        df = pd.read_csv(stores_file, names=column_names, skiprows=1, on_bad_lines='skip')

        # Clean data - remove SQL output noise
        df = df[~df['StoreID'].astype(str).str.contains('Warning|rows affected|NULL', na=False)]
        df = df.dropna(subset=['StoreName'])
        df = df[df['TotalTransactions'].notna()]

        # Convert numeric columns
        numeric_cols = ['StoreID', 'TotalTransactions', 'UniqueCustomers', 'AvgTransactionValue',
                       'TobaccoTransactions', 'LaundryTransactions', 'MaleCustomers', 'FemaleCustomers', 'AvgCustomerAge']

        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')

        print(f"✅ Loaded {len(df)} REAL active stores with transaction data")

        # Data Quality Audit for REAL data
        print("\n🔍 REAL DATA QUALITY AUDIT")
        print("-" * 30)

        total_transactions = df['TotalTransactions'].sum()
        total_customers = df['UniqueCustomers'].sum()

        data_quality = {
            'real_active_stores': len(df),
            'total_transactions': total_transactions,
            'total_unique_customers': total_customers,
            'avg_transactions_per_store': df['TotalTransactions'].mean(),
            'stores_with_coordinates': len(df[(df['GeoLatitude'].notna()) & (df['GeoLongitude'].notna())]),
            'stores_with_barangay': len(df[df['BarangayName'].notna()]),
            'stores_with_customers': len(df[df['UniqueCustomers'] > 0]),
            'tobacco_active_stores': len(df[df['TobaccoTransactions'] > 0]),
            'laundry_active_stores': len(df[df['LaundryTransactions'] > 0]),
            'avg_customer_age': df['AvgCustomerAge'].mean()
        }

        for key, value in data_quality.items():
            if isinstance(value, float):
                print(f"  {key.replace('_', ' ').title()}: {value:.1f}")
            else:
                print(f"  {key.replace('_', ' ').title()}: {value:,}")

        # Handle NaN values for Excel export
        df = df.replace([pd.NA, pd.NaT, float('inf'), float('-inf')], None)
        df = df.fillna('')

        # Create Excel with professional formatting
        output_file = 'out/enhanced_analytics/scout_real_active_stores_professional.xlsx'

        with pd.ExcelWriter(output_file, engine='xlsxwriter') as writer:
            workbook = writer.book
            workbook.nan_inf_to_errors = True

            # Define professional formats
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

            high_activity_format = workbook.add_format({
                'text_wrap': False,
                'valign': 'top',
                'border': 1,
                'border_color': '#D0D0D0',
                'fg_color': '#E6F7FF',
                'font_size': 10
            })

            number_format = workbook.add_format({
                'num_format': '#,##0',
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

            coordinate_format = workbook.add_format({
                'num_format': '0.0000',
                'border': 1,
                'border_color': '#D0D0D0',
                'font_size': 10
            })

            # Prepare display dataframe
            df_display = df.copy()

            # Reorder columns for better presentation
            display_order = ['StoreID', 'StoreName', 'Location', 'MunicipalityName', 'BarangayName',
                           'TotalTransactions', 'UniqueCustomers', 'AvgTransactionValue',
                           'TobaccoTransactions', 'LaundryTransactions', 'MaleCustomers', 'FemaleCustomers', 'AvgCustomerAge',
                           'FirstTransaction', 'LastTransaction', 'GeoLatitude', 'GeoLongitude']

            # Keep only columns that exist
            display_order = [col for col in display_order if col in df_display.columns]
            df_display = df_display[display_order]

            # Rename columns for professional presentation
            column_mapping = {
                'StoreID': 'Store ID',
                'StoreName': 'Store Name',
                'Location': 'Address',
                'MunicipalityName': 'Municipality',
                'BarangayName': 'Barangay',
                'TotalTransactions': 'Total Transactions',
                'UniqueCustomers': 'Unique Customers',
                'AvgTransactionValue': 'Avg Transaction Value',
                'TobaccoTransactions': 'Tobacco Txns',
                'LaundryTransactions': 'Laundry Txns',
                'MaleCustomers': 'Male Customers',
                'FemaleCustomers': 'Female Customers',
                'AvgCustomerAge': 'Avg Age',
                'FirstTransaction': 'First Transaction',
                'LastTransaction': 'Last Transaction',
                'GeoLatitude': 'Latitude',
                'GeoLongitude': 'Longitude'
            }

            df_display = df_display.rename(columns=column_mapping)

            # Sort by transaction volume
            df_display = df_display.sort_values('Total Transactions', ascending=False)

            # Write to Excel with title
            title_format = workbook.add_format({
                'bold': True,
                'font_size': 16,
                'font_color': '#2E5594'
            })

            subtitle_format = workbook.add_format({
                'font_size': 12,
                'font_color': '#666666'
            })

            df_display.to_excel(writer, sheet_name='Real Active Stores', index=False, startrow=2)

            worksheet = writer.sheets['Real Active Stores']

            # Add titles
            worksheet.write('A1', 'SCOUT v7 - REAL ACTIVE STORES DATABASE', title_format)
            worksheet.write('A2', f'Only stores with canonical_tx_id transaction data - {len(df_display)} stores total', subtitle_format)

            # Format headers
            for col_num, value in enumerate(df_display.columns.values):
                worksheet.write(2, col_num, value, header_format)

            # Format data with conditional formatting
            for row_num in range(len(df_display)):
                for col_num, col_name in enumerate(df_display.columns):
                    cell_value = df_display.iloc[row_num, col_num]

                    # High activity stores (>1000 transactions) get special highlighting
                    is_high_activity = df_display.iloc[row_num, df_display.columns.get_loc('Total Transactions')] > 1000

                    # Choose format based on column type and activity level
                    if col_name in ['Total Transactions', 'Unique Customers', 'Tobacco Txns', 'Laundry Txns', 'Male Customers', 'Female Customers']:
                        if is_high_activity:
                            format_to_use = workbook.add_format({
                                'num_format': '#,##0',
                                'border': 1,
                                'border_color': '#D0D0D0',
                                'fg_color': '#E6F7FF',
                                'font_size': 10
                            })
                        else:
                            format_to_use = number_format
                    elif col_name == 'Avg Transaction Value':
                        if is_high_activity:
                            format_to_use = workbook.add_format({
                                'num_format': '₱#,##0.00',
                                'border': 1,
                                'border_color': '#D0D0D0',
                                'fg_color': '#E6F7FF',
                                'font_size': 10
                            })
                        else:
                            format_to_use = currency_format
                    elif col_name in ['Latitude', 'Longitude'] and pd.notna(cell_value) and cell_value != '':
                        format_to_use = coordinate_format
                    else:
                        format_to_use = high_activity_format if is_high_activity else data_format

                    worksheet.write(row_num + 3, col_num, cell_value, format_to_use)

            # Auto-adjust column widths
            for i, col in enumerate(df_display.columns):
                max_len = max(
                    df_display[col].astype(str).map(len).max() if df_display[col].notna().any() else 0,
                    len(str(col))
                ) + 3
                worksheet.set_column(i, i, min(max_len, 35))

            # Add Real Data Quality Dashboard
            quality_data = pd.DataFrame([
                ['Real Active Stores', f"{data_quality['real_active_stores']:,}", '100%', 'Stores with actual transaction data'],
                ['Total Transactions', f"{data_quality['total_transactions']:,}", '100%', 'All canonical_tx_id verified'],
                ['Unique Customers with Demographics', f"{data_quality['total_unique_customers']:,}", f"{data_quality['total_unique_customers']/data_quality['total_transactions']*100:.1f}%", 'Facial recognition coverage'],
                ['Avg Transactions per Store', f"{data_quality['avg_transactions_per_store']:,.0f}", 'N/A', 'Store activity level'],
                ['Stores with GPS Coordinates', f"{data_quality['stores_with_coordinates']:,}", f"{data_quality['stores_with_coordinates']/data_quality['real_active_stores']*100:.1f}%", 'Geographic mapping ready'],
                ['Stores with Barangay Data', f"{data_quality['stores_with_barangay']:,}", f"{data_quality['stores_with_barangay']/data_quality['real_active_stores']*100:.1f}%", 'Micro-location analytics'],
                ['Tobacco Active Stores', f"{data_quality['tobacco_active_stores']:,}", f"{data_quality['tobacco_active_stores']/data_quality['real_active_stores']*100:.1f}%", 'Category presence'],
                ['Laundry Active Stores', f"{data_quality['laundry_active_stores']:,}", f"{data_quality['laundry_active_stores']/data_quality['real_active_stores']*100:.1f}%", 'Category presence'],
                ['Average Customer Age', f"{data_quality['avg_customer_age']:.1f}", 'N/A', 'Demographic insight']
            ], columns=['Real Data Metric', 'Value', 'Coverage', 'Business Impact'])

            quality_data.to_excel(writer, sheet_name='Real Data Quality', index=False, startrow=2)
            quality_sheet = writer.sheets['Real Data Quality']

            quality_sheet.write('A1', 'REAL DATA QUALITY AUDIT', title_format)
            quality_sheet.write('A2', 'Only canonical_tx_id verified transaction data included', subtitle_format)

            # Format quality sheet
            for col_num, value in enumerate(quality_data.columns.values):
                quality_sheet.write(2, col_num, value, header_format)

            for row_num in range(len(quality_data)):
                for col_num in range(len(quality_data.columns)):
                    cell_value = quality_data.iloc[row_num, col_num]
                    quality_sheet.write(row_num + 3, col_num, cell_value, data_format)

            # Auto-adjust quality sheet columns
            for i, col in enumerate(quality_data.columns):
                max_len = max(
                    quality_data[col].astype(str).map(len).max(),
                    len(str(col))
                ) + 2
                quality_sheet.set_column(i, i, min(max_len, 40))

        print(f"\n🎉 REAL ACTIVE STORES REPORT GENERATED!")
        print(f"📁 Output: {output_file}")
        print(f"📊 Features:")
        print(f"   • Only {len(df)} stores with real canonical_tx_id transaction data")
        print(f"   • {data_quality['total_transactions']:,} total verified transactions")
        print(f"   • {data_quality['total_unique_customers']:,} unique customers with facial recognition")
        print(f"   • Professional formatting with transaction volume highlighting")
        print(f"   • Real data quality audit with verified metrics")
        print(f"   • Municipality data from actual active locations")

        return output_file

    except FileNotFoundError:
        print(f"❌ Real active stores file not found: {stores_file}")
        return None
    except Exception as e:
        print(f"❌ Error generating report: {str(e)}")
        return None

if __name__ == "__main__":
    create_real_active_stores_report()