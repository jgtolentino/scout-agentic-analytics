#!/usr/bin/env python3
"""
Create complete Excel files with all available Scout Analytics data
"""
import pandas as pd
import os

def create_complete_excel():
    exports_dir = "/Users/tbwa/scout-v7/exports"

    # Load complete flat data with audio transcripts
    flat_csv = os.path.join(exports_dir, "all_flat_transactions_complete.csv")
    df_flat = pd.read_csv(flat_csv)

    # Load complete crosstab data
    crosstab_csv = os.path.join(exports_dir, "all_crosstab_complete.csv")
    df_crosstab = pd.read_csv(crosstab_csv)

    # Create comprehensive Excel workbook
    excel_file = os.path.join(exports_dir, "Scout_Analytics_Complete_Dataset.xlsx")

    with pd.ExcelWriter(excel_file, engine='openpyxl') as writer:
        # Flat transactions with all enriched data
        df_flat.to_excel(writer, sheet_name='Flat_Transactions', index=False)

        # Crosstab dimensional analysis
        df_crosstab.to_excel(writer, sheet_name='Crosstab_Analysis', index=False)

        # Summary sheet
        summary_data = {
            'Metric': [
                'Total Transactions',
                'Total Revenue (PHP)',
                'Average Transaction Value (PHP)',
                'Unique Brands',
                'Unique Categories',
                'Date Range',
                'Primary Store',
                'Device ID',
                'Payment Method'
            ],
            'Value': [
                len(df_flat),
                df_flat['total_amount'].sum(),
                round(df_flat['total_amount'].mean(), 2),
                df_flat['brand'].nunique(),
                df_flat['category'].nunique(),
                f"{df_flat['transaction_date'].min()} to {df_flat['transaction_date'].max()}",
                df_flat['store_name'].iloc[0],
                df_flat['device_id'].iloc[0],
                df_flat['payment_method'].iloc[0]
            ]
        }
        df_summary = pd.DataFrame(summary_data)
        df_summary.to_excel(writer, sheet_name='Summary', index=False)

        # Brand analysis
        brand_analysis = df_flat.groupby('brand').agg({
            'total_amount': ['sum', 'mean', 'count'],
            'total_items': 'sum'
        }).round(2)
        brand_analysis.columns = ['Total_Revenue', 'Avg_Transaction', 'Transaction_Count', 'Total_Items']
        brand_analysis = brand_analysis.reset_index()
        brand_analysis.to_excel(writer, sheet_name='Brand_Analysis', index=False)

        # Category analysis
        category_analysis = df_flat.groupby('category').agg({
            'total_amount': ['sum', 'mean', 'count'],
            'total_items': 'sum'
        }).round(2)
        category_analysis.columns = ['Total_Revenue', 'Avg_Transaction', 'Transaction_Count', 'Total_Items']
        category_analysis = category_analysis.reset_index()
        category_analysis.to_excel(writer, sheet_name='Category_Analysis', index=False)

        # Format all sheets
        for sheet_name in writer.sheets:
            worksheet = writer.sheets[sheet_name]

            # Auto-adjust column widths
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)
                worksheet.column_dimensions[column_letter].width = adjusted_width

    print(f"✅ Complete Excel workbook created: {excel_file}")
    print(f"📊 Contains {len(df_flat)} transactions with full audio transcripts")
    print(f"💰 Total revenue: ₱{df_flat['total_amount'].sum():.2f}")
    print(f"🏪 Store: {df_flat['store_name'].iloc[0]}")
    print(f"📱 Device: {df_flat['device_id'].iloc[0]}")

    # Also create individual CSV files
    flat_final = os.path.join(exports_dir, "Scout_Flat_Transactions_Complete.csv")
    crosstab_final = os.path.join(exports_dir, "Scout_Crosstab_Complete.csv")

    df_flat.to_csv(flat_final, index=False)
    df_crosstab.to_csv(crosstab_final, index=False)

    print(f"✅ CSV files created:")
    print(f"   - {flat_final}")
    print(f"   - {crosstab_final}")

if __name__ == "__main__":
    create_complete_excel()