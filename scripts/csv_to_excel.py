#!/usr/bin/env python3
"""
Convert Scout Analytics CSV exports to Excel format
"""
import pandas as pd
import os

def csv_to_excel():
    exports_dir = "/Users/tbwa/scout-v7/exports"

    # Convert flat dataframe
    flat_csv = os.path.join(exports_dir, "scout_flat_dataframe_enriched.csv")
    flat_excel = os.path.join(exports_dir, "scout_flat_dataframe_enriched.xlsx")

    df_flat = pd.read_csv(flat_csv)

    # Create Excel with formatting
    with pd.ExcelWriter(flat_excel, engine='openpyxl') as writer:
        df_flat.to_excel(writer, sheet_name='Flat_Dataframe', index=False)

        # Get workbook and worksheet for formatting
        workbook = writer.book
        worksheet = writer.sheets['Flat_Dataframe']

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

    # Convert crosstab
    crosstab_csv = os.path.join(exports_dir, "scout_crosstab_analysis.csv")
    crosstab_excel = os.path.join(exports_dir, "scout_crosstab_analysis.xlsx")

    df_crosstab = pd.read_csv(crosstab_csv)

    with pd.ExcelWriter(crosstab_excel, engine='openpyxl') as writer:
        df_crosstab.to_excel(writer, sheet_name='Crosstab_Analysis', index=False)

        # Get workbook and worksheet for formatting
        workbook = writer.book
        worksheet = writer.sheets['Crosstab_Analysis']

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
            adjusted_width = min(max_length + 2, 30)
            worksheet.column_dimensions[column_letter].width = adjusted_width

    print(f"✅ Created Excel files:")
    print(f"   - {flat_excel}")
    print(f"   - {crosstab_excel}")
    print(f"✅ CSV files available:")
    print(f"   - {flat_csv}")
    print(f"   - {crosstab_csv}")

if __name__ == "__main__":
    csv_to_excel()