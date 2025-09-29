#!/usr/bin/env python3
"""
Sample Revenue by Category Analysis
Based on Scout v7 data patterns - shows expected output format
"""

import pandas as pd

def create_sample_revenue_analysis():
    """Create sample revenue analysis showing expected structure"""

    print("💰 SAMPLE REVENUE BY CATEGORY ANALYSIS")
    print("=" * 60)
    print("📊 Based on Scout v7 data patterns")

    # Sample Category Summary (based on known Scout patterns)
    category_data = [
        ['Tobacco', 386, '₱41,348.00', '₱107.12', 7],
        ['Laundry', 539, '₱57,892.00', '₱107.41', 7],
        ['Food', 298, '₱24,156.00', '₱81.07', 6],
        ['Beverages', 445, '₱38,290.00', '₱86.07', 7],
        ['Personal Care', 187, '₱19,834.00', '₱106.09', 5],
        ['Household', 156, '₱13,245.00', '₱84.90', 4],
        ['Snacks', 234, '₱18,567.00', '₱79.34', 6]
    ]

    category_df = pd.DataFrame(category_data, columns=[
        'Category', 'Transaction Count', 'Total Revenue', 'Avg Transaction Value', 'Active Stores'
    ])

    # Sample Subcategory Breakdown
    subcategory_data = [
        ['Tobacco', 'Cigarettes - Marlboro', 108, '₱11,564.00', '₱107.07', '5.65%'],
        ['Tobacco', 'Cigarettes - Camel', 52, '₱5,620.00', '₱108.08', '2.75%'],
        ['Tobacco', 'Cigarettes - TM', 21, '₱2,323.00', '₱110.65', '1.14%'],
        ['Tobacco', 'Cigarettes - Marca Leon', 11, '₱1,302.00', '₱118.40', '0.64%'],
        ['Laundry', 'Bar Soap - Surf', 157, '₱16,969.00', '₱108.08', '8.30%'],
        ['Laundry', 'Bar Soap - Tide', 128, '₱13,833.00', '₱108.07', '6.77%'],
        ['Laundry', 'Powder - Ariel', 127, '₱14,052.00', '₱110.65', '6.88%'],
        ['Laundry', 'Fabric Conditioner - Downy', 91, '₱10,774.00', '₱118.40', '5.27%'],
        ['Beverages', 'Soft Drinks - Coke', 89, '₱7,658.00', '₱86.07', '3.75%'],
        ['Beverages', 'Water - Bottled', 156, '₱13,434.00', '₱86.11', '6.58%'],
        ['Food', 'Rice - Premium', 67, '₱5,436.00', '₱81.13', '2.66%'],
        ['Food', 'Noodles - Instant', 89, '₱7,215.00', '₱81.07', '3.53%']
    ]

    subcategory_df = pd.DataFrame(subcategory_data, columns=[
        'Category', 'Subcategory', 'Transaction Count', 'Total Revenue', 'Avg Transaction Value', 'Revenue %'
    ])

    # Top Performers
    top_performers_data = [
        ['Laundry', 'Bar Soap - Surf', '₱16,969.00', 157, '₱108.08'],
        ['Laundry', 'Powder - Ariel', '₱14,052.00', 127, '₱110.65'],
        ['Laundry', 'Bar Soap - Tide', '₱13,833.00', 128, '₱108.07'],
        ['Beverages', 'Water - Bottled', '₱13,434.00', 156, '₱86.11'],
        ['Tobacco', 'Cigarettes - Marlboro', '₱11,564.00', 108, '₱107.07'],
        ['Laundry', 'Fabric Conditioner - Downy', '₱10,774.00', 91, '₱118.40'],
        ['Beverages', 'Soft Drinks - Coke', '₱7,658.00', 89, '₱86.07'],
        ['Food', 'Noodles - Instant', '₱7,215.00', 89, '₱81.07'],
        ['Tobacco', 'Cigarettes - Camel', '₱5,620.00', 52, '₱108.08'],
        ['Food', 'Rice - Premium', '₱5,436.00', 67, '₱81.13']
    ]

    top_performers_df = pd.DataFrame(top_performers_data, columns=[
        'Category', 'Subcategory', 'Total Revenue', 'Transaction Count', 'Avg Transaction Value'
    ])

    # Create Excel report
    output_file = 'out/enhanced_analytics/sample_revenue_by_category.xlsx'

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

        # Category Summary worksheet
        category_df.to_excel(writer, sheet_name='Category Summary', index=False, startrow=2)
        ws_cat = writer.sheets['Category Summary']
        ws_cat.merge_range('A1:E1', 'REVENUE ANALYSIS - CATEGORY SUMMARY', title_format)

        for col_num, value in enumerate(category_df.columns.values):
            ws_cat.write(2, col_num, value, header_format)

        for row_num in range(len(category_df)):
            for col_num in range(len(category_df.columns)):
                cell_value = category_df.iloc[row_num, col_num]
                ws_cat.write(row_num + 3, col_num, cell_value, data_format)

        # Subcategory Breakdown worksheet
        subcategory_df.to_excel(writer, sheet_name='Subcategory Breakdown', index=False, startrow=2)
        ws_sub = writer.sheets['Subcategory Breakdown']
        ws_sub.merge_range('A1:F1', 'REVENUE ANALYSIS - SUBCATEGORY BREAKDOWN', title_format)

        for col_num, value in enumerate(subcategory_df.columns.values):
            ws_sub.write(2, col_num, value, header_format)

        for row_num in range(len(subcategory_df)):
            for col_num in range(len(subcategory_df.columns)):
                cell_value = subcategory_df.iloc[row_num, col_num]
                ws_sub.write(row_num + 3, col_num, cell_value, data_format)

        # Top Performers worksheet
        top_performers_df.to_excel(writer, sheet_name='Top Performers', index=False, startrow=2)
        ws_top = writer.sheets['Top Performers']
        ws_top.merge_range('A1:E1', 'REVENUE ANALYSIS - TOP PERFORMERS', title_format)

        for col_num, value in enumerate(top_performers_df.columns.values):
            ws_top.write(2, col_num, value, header_format)

        for row_num in range(len(top_performers_df)):
            for col_num in range(len(top_performers_df.columns)):
                cell_value = top_performers_df.iloc[row_num, col_num]
                ws_top.write(row_num + 3, col_num, cell_value, data_format)

        # Auto-adjust column widths for all sheets
        for sheet_name in ['Category Summary', 'Subcategory Breakdown', 'Top Performers']:
            worksheet = writer.sheets[sheet_name]
            for i in range(6):  # Adjust first 6 columns
                worksheet.set_column(i, i, 20)

    print(f"\n🎉 SAMPLE REVENUE ANALYSIS GENERATED!")
    print(f"📁 Output: {output_file}")
    print(f"📊 Key Insights from Sample Data:")
    print(f"   • Top Revenue Category: Laundry (₱57,892)")
    print(f"   • Top Subcategory: Bar Soap - Surf (₱16,969)")
    print(f"   • Highest Avg Transaction: Marca Leon (₱118.40)")
    print(f"   • Most Transactions: Surf Bar Soap (157 transactions)")

    return output_file

if __name__ == "__main__":
    create_sample_revenue_analysis()