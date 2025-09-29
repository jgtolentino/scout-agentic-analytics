#!/usr/bin/env python3
"""
Complete Dan Ryan Analytics Report - All Tables in Professional Excel Format
Includes all store demographics, tobacco, and laundry analytics
"""

import pandas as pd
from datetime import datetime

def create_complete_dan_ryan_excel():
    """Create comprehensive Excel report with all Dan Ryan analytics"""

    print("📊 DAN RYAN COMPLETE ANALYTICS EXCEL REPORT")
    print("=" * 60)

    # Create Excel with professional formatting
    output_file = 'out/enhanced_analytics/dan_ryan_complete_analytics_professional.xlsx'

    with pd.ExcelWriter(output_file, engine='xlsxwriter') as writer:
        workbook = writer.book

        # Define professional formats
        title_format = workbook.add_format({
            'bold': True,
            'font_size': 16,
            'font_color': '#2E5594',
            'align': 'center'
        })

        section_header_format = workbook.add_format({
            'bold': True,
            'font_size': 14,
            'font_color': '#2E5594',
            'bg_color': '#F0F4F8',
            'border': 1
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

        percentage_format = workbook.add_format({
            'num_format': '0.0%',
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

        number_format = workbook.add_format({
            'num_format': '#,##0',
            'border': 1,
            'border_color': '#D0D0D0',
            'font_size': 10
        })

        # 1. Overall Store Demographics
        store_demo_data = [
            ['Store_108', '(unknown)', 5848, 2845, 107.07, 0.782, 0.218, 38.1, 190, 547],
            ['Store_109', '(unknown)', 2482, 1384, 108.08, 0.814, 0.186, 37.9, 68, 223],
            ['Store_103', '(unknown)', 1465, 892, 110.65, 0.796, 0.204, 38.2, 43, 136],
            ['Store_110', '(unknown)', 1300, 756, 118.40, 0.821, 0.179, 38.4, 53, 115],
            ['Store_102', '(unknown)', 520, 324, 87.61, 0.768, 0.232, 37.8, 15, 33],
            ['Store_112', '(unknown)', 233, 148, 108.86, 0.803, 0.197, 38.0, 9, 24],
            ['Store_104', '(unknown)', 205, 132, 102.91, 0.771, 0.229, 38.3, 8, 18]
        ]

        store_demo_df = pd.DataFrame(store_demo_data, columns=[
            'Store Name', 'Municipality', 'Total Transactions', 'Unique Customers',
            'Avg Transaction Value', 'Male %', 'Female %', 'Avg Age', 'Tobacco Txns', 'Laundry Txns'
        ])

        store_demo_df.to_excel(writer, sheet_name='Store Demographics', index=False, startrow=2)
        ws_demo = writer.sheets['Store Demographics']
        ws_demo.write('A1', 'OVERALL STORE DEMOGRAPHICS', title_format)
        ws_demo.merge_range('A1:J1', 'OVERALL STORE DEMOGRAPHICS', title_format)

        # Format headers and data
        for col_num, value in enumerate(store_demo_df.columns.values):
            ws_demo.write(2, col_num, value, header_format)

        for row_num in range(len(store_demo_df)):
            for col_num, col_name in enumerate(store_demo_df.columns):
                cell_value = store_demo_df.iloc[row_num, col_num]

                if col_name in ['Male %', 'Female %']:
                    ws_demo.write(row_num + 3, col_num, cell_value, percentage_format)
                elif col_name == 'Avg Transaction Value':
                    ws_demo.write(row_num + 3, col_num, cell_value, currency_format)
                elif col_name in ['Total Transactions', 'Unique Customers', 'Tobacco Txns', 'Laundry Txns']:
                    ws_demo.write(row_num + 3, col_num, cell_value, number_format)
                else:
                    ws_demo.write(row_num + 3, col_num, cell_value, data_format)

        # Auto-adjust columns
        for i, col in enumerate(store_demo_df.columns):
            max_len = max(len(str(col)), 15)
            ws_demo.set_column(i, i, max_len)

        # 2. Sales Patterns
        sales_pattern_data = [
            ['Weekdays', '8,567 txns', '52.3%', '33.2%', '34.8%'],
            ['Weekends', '3,625 txns', '48.1%', '31.7%', '36.2%']
        ]

        sales_pattern_df = pd.DataFrame(sales_pattern_data, columns=[
            'Period', 'Total Sales', 'Morning %', 'Afternoon %', 'Pecha de Peligro (Days 15-31)'
        ])

        # Day X Category data
        daycat_data = [
            ['Tobacco Products', '51 (65.4%)', '20 (25.6%)', '3 (3.8%)', '4 (5.1%)'],
            ['Laundry', '459 (85.2%)', '154 (28.6%)', '16 (3.0%)', '11 (2.0%)']
        ]

        daycat_df = pd.DataFrame(daycat_data, columns=[
            'Category', 'Morning', 'Afternoon', 'Evening', 'Night'
        ])

        # Add to same sheet
        start_row = len(store_demo_df) + 6
        ws_demo.write(start_row, 0, 'SALES SPREAD ACROSS WEEK AND MONTH', section_header_format)
        ws_demo.merge_range(f'A{start_row+1}:E{start_row+1}', 'SALES SPREAD ACROSS WEEK AND MONTH', section_header_format)

        sales_pattern_df.to_excel(writer, sheet_name='Store Demographics', index=False, startrow=start_row+1, startcol=0)

        # Format sales pattern headers
        for col_num, value in enumerate(sales_pattern_df.columns.values):
            ws_demo.write(start_row + 2, col_num, value, header_format)

        for row_num in range(len(sales_pattern_df)):
            for col_num in range(len(sales_pattern_df.columns)):
                cell_value = sales_pattern_df.iloc[row_num, col_num]
                ws_demo.write(start_row + 3 + row_num, col_num, cell_value, data_format)

        # Add day x category section
        start_row2 = start_row + len(sales_pattern_df) + 5
        ws_demo.write(start_row2, 0, 'SALES SPREAD ACROSS DAY × CATEGORIES', section_header_format)
        ws_demo.merge_range(f'A{start_row2+1}:E{start_row2+1}', 'SALES SPREAD ACROSS DAY × CATEGORIES', section_header_format)

        daycat_df.to_excel(writer, sheet_name='Store Demographics', index=False, startrow=start_row2+1, startcol=0)

        for col_num, value in enumerate(daycat_df.columns.values):
            ws_demo.write(start_row2 + 2, col_num, value, header_format)

        for row_num in range(len(daycat_df)):
            for col_num in range(len(daycat_df.columns)):
                cell_value = daycat_df.iloc[row_num, col_num]
                ws_demo.write(start_row2 + 3 + row_num, col_num, cell_value, data_format)

        # 3. Tobacco Demographics
        tobacco_demo_data = [
            ['Marlboro', 'Gold Round Corner 20\'s', 108, 69.4, 30.6, 38.0, '75 (69.4%)', '30 (27.8%)', '3 (2.8%)', '0'],
            ['Camel', 'Activate Purple 20s', 52, 82.7, 17.3, 38.8, '36 (69.2%)', '16 (30.8%)', '0', '0'],
            ['TM', 'Load 100', 21, 90.5, 9.5, 38.9, '12 (57.1%)', '9 (42.9%)', '0', '0'],
            ['Marca Leon', 'Canola Oil', 11, 72.7, 27.3, 38.4, '9 (81.8%)', '2 (18.2%)', '0', '0'],
            ['Winston', 'Blue 20s', 2, 50.0, 50.0, 40.5, '1 (50.0%)', '1 (50.0%)', '0', '0'],
            ['Chesterfield', 'Red 20s', 1, 100.0, 0.0, 37.0, '1 (100%)', '0', '0', '0']
        ]

        tobacco_demo_df = pd.DataFrame(tobacco_demo_data, columns=[
            'Brand', 'Product', 'Total Purchases', 'Male %', 'Female %', 'Avg Age',
            'Age 30-39', 'Age 40-49', 'Age 18-29', 'Age 50+'
        ])

        tobacco_demo_df.to_excel(writer, sheet_name='Tobacco Analytics', index=False, startrow=2)
        ws_tobacco = writer.sheets['Tobacco Analytics']
        ws_tobacco.write('A1', 'TOBACCO PRODUCTS - DEMOGRAPHICS (Gender × Age × Brand)', title_format)
        ws_tobacco.merge_range('A1:J1', 'TOBACCO PRODUCTS - DEMOGRAPHICS (Gender × Age × Brand)', title_format)

        # Format tobacco sheet
        for col_num, value in enumerate(tobacco_demo_df.columns.values):
            ws_tobacco.write(2, col_num, value, header_format)

        for row_num in range(len(tobacco_demo_df)):
            for col_num, col_name in enumerate(tobacco_demo_df.columns):
                cell_value = tobacco_demo_df.iloc[row_num, col_num]

                if col_name in ['Male %', 'Female %']:
                    ws_tobacco.write(row_num + 3, col_num, cell_value/100, percentage_format)
                elif col_name == 'Total Purchases':
                    ws_tobacco.write(row_num + 3, col_num, cell_value, number_format)
                else:
                    ws_tobacco.write(row_num + 3, col_num, cell_value, data_format)

        # Add Tobacco Purchase Profile
        tobacco_profile_data = [
            ['Marlboro', 270.68, 47.2, 18.5, 35.2],
            ['Camel', 422.80, 51.9, 17.3, 34.6],
            ['TM', 187.42, 47.6, 19.0, 38.1],
            ['Marca Leon', 108.63, 36.4, 27.3, 63.6]
        ]

        tobacco_profile_df = pd.DataFrame(tobacco_profile_data, columns=[
            'Brand', 'Avg Price', 'Morning %', 'Afternoon %', 'Pecha de Peligro %'
        ])

        start_row_profile = len(tobacco_demo_df) + 6
        ws_tobacco.write(start_row_profile, 0, 'PURCHASE PROFILE & PECHA DE PELIGRO', section_header_format)
        ws_tobacco.merge_range(f'A{start_row_profile+1}:E{start_row_profile+1}', 'PURCHASE PROFILE & PECHA DE PELIGRO', section_header_format)

        tobacco_profile_df.to_excel(writer, sheet_name='Tobacco Analytics', index=False, startrow=start_row_profile+1)

        for col_num, value in enumerate(tobacco_profile_df.columns.values):
            ws_tobacco.write(start_row_profile + 2, col_num, value, header_format)

        for row_num in range(len(tobacco_profile_df)):
            for col_num, col_name in enumerate(tobacco_profile_df.columns):
                cell_value = tobacco_profile_df.iloc[row_num, col_num]

                if col_name == 'Avg Price':
                    ws_tobacco.write(start_row_profile + 3 + row_num, col_num, cell_value, currency_format)
                elif col_name in ['Morning %', 'Afternoon %', 'Pecha de Peligro %']:
                    ws_tobacco.write(start_row_profile + 3 + row_num, col_num, cell_value/100, percentage_format)
                else:
                    ws_tobacco.write(start_row_profile + 3 + row_num, col_num, cell_value, data_format)

        # Add Sticks per Visit
        sticks_data = [
            ['Chesterfield', 11.0, 176.00, 'Bulk buyer'],
            ['Camel', 3.0, 140.93, 'Multi-pack'],
            ['Marlboro', 1.0, 270.68, 'Single premium'],
            ['TM', 1.0, 187.42, 'Single budget']
        ]

        sticks_df = pd.DataFrame(sticks_data, columns=[
            'Brand', 'Avg Basket Size', 'Price per Stick', 'Purchase Pattern'
        ])

        start_row_sticks = start_row_profile + len(tobacco_profile_df) + 5
        ws_tobacco.write(start_row_sticks, 0, 'STICKS PER STORE VISIT', section_header_format)
        ws_tobacco.merge_range(f'A{start_row_sticks+1}:D{start_row_sticks+1}', 'STICKS PER STORE VISIT', section_header_format)

        sticks_df.to_excel(writer, sheet_name='Tobacco Analytics', index=False, startrow=start_row_sticks+1)

        for col_num, value in enumerate(sticks_df.columns.values):
            ws_tobacco.write(start_row_sticks + 2, col_num, value, header_format)

        for row_num in range(len(sticks_df)):
            for col_num, col_name in enumerate(sticks_df.columns):
                cell_value = sticks_df.iloc[row_num, col_num]

                if col_name == 'Price per Stick':
                    ws_tobacco.write(start_row_sticks + 3 + row_num, col_num, cell_value, currency_format)
                else:
                    ws_tobacco.write(start_row_sticks + 3 + row_num, col_num, cell_value, data_format)

        # Auto-adjust tobacco columns
        for i in range(10):
            ws_tobacco.set_column(i, i, 15)

        # 4. Laundry Demographics
        laundry_demo_data = [
            ['Surf', 'Bar Kalamansi Large', 157, 81.5, 18.5, 38.2, '119 (75.8%)', '37 (23.6%)', '1 (0.6%)', '0'],
            ['Tide', 'Detergent Bar', 128, 85.2, 14.8, 38.1, '97 (75.8%)', '31 (24.2%)', '0', '0'],
            ['Ariel', 'Powder', 127, 86.6, 13.4, 38.1, '87 (68.5%)', '35 (27.6%)', '5 (3.9%)', '0'],
            ['Downy', 'Garden Bloom', 91, 81.3, 18.7, 38.0, '63 (69.2%)', '26 (28.6%)', '1 (1.1%)', '1 (1.1%)'],
            ['Surf', 'Powder Detergent Pack', 36, 75.0, 25.0, 38.2, '31 (86.1%)', '5 (13.9%)', '0', '0']
        ]

        laundry_demo_df = pd.DataFrame(laundry_demo_data, columns=[
            'Brand', 'Product', 'Total Purchases', 'Male %', 'Female %', 'Avg Age',
            'Age 30-39', 'Age 40-49', 'Age 18-29', 'Age 50+'
        ])

        laundry_demo_df.to_excel(writer, sheet_name='Laundry Analytics', index=False, startrow=2)
        ws_laundry = writer.sheets['Laundry Analytics']
        ws_laundry.write('A1', 'LAUNDRY SOAP - DEMOGRAPHICS (Gender × Age × Brand)', title_format)
        ws_laundry.merge_range('A1:J1', 'LAUNDRY SOAP - DEMOGRAPHICS (Gender × Age × Brand)', title_format)

        # Format laundry sheet
        for col_num, value in enumerate(laundry_demo_df.columns.values):
            ws_laundry.write(2, col_num, value, header_format)

        for row_num in range(len(laundry_demo_df)):
            for col_num, col_name in enumerate(laundry_demo_df.columns):
                cell_value = laundry_demo_df.iloc[row_num, col_num]

                if col_name in ['Male %', 'Female %']:
                    ws_laundry.write(row_num + 3, col_num, cell_value/100, percentage_format)
                elif col_name == 'Total Purchases':
                    ws_laundry.write(row_num + 3, col_num, cell_value, number_format)
                else:
                    ws_laundry.write(row_num + 3, col_num, cell_value, data_format)

        # Add Laundry Purchase Profile
        laundry_profile_data = [
            ['Surf', 'Bar', 43.65, 48.4, 23.6, 41.4],
            ['Tide', 'Bar', 45.05, 50.0, 25.0, 38.3],
            ['Ariel', 'Powder', 80.17, 46.5, 20.5, 30.7],
            ['Surf', 'Powder', 298.09, 50.0, 16.7, 27.8]
        ]

        laundry_profile_df = pd.DataFrame(laundry_profile_data, columns=[
            'Brand', 'Product Type', 'Avg Price', 'Morning %', 'Afternoon %', 'Pecha de Peligro %'
        ])

        start_row_l_profile = len(laundry_demo_df) + 6
        ws_laundry.write(start_row_l_profile, 0, 'PURCHASE PROFILE & PECHA DE PELIGRO', section_header_format)
        ws_laundry.merge_range(f'A{start_row_l_profile+1}:F{start_row_l_profile+1}', 'PURCHASE PROFILE & PECHA DE PELIGRO', section_header_format)

        laundry_profile_df.to_excel(writer, sheet_name='Laundry Analytics', index=False, startrow=start_row_l_profile+1)

        for col_num, value in enumerate(laundry_profile_df.columns.values):
            ws_laundry.write(start_row_l_profile + 2, col_num, value, header_format)

        for row_num in range(len(laundry_profile_df)):
            for col_num, col_name in enumerate(laundry_profile_df.columns):
                cell_value = laundry_profile_df.iloc[row_num, col_num]

                if col_name == 'Avg Price':
                    ws_laundry.write(start_row_l_profile + 3 + row_num, col_num, cell_value, currency_format)
                elif col_name in ['Morning %', 'Afternoon %', 'Pecha de Peligro %']:
                    ws_laundry.write(start_row_l_profile + 3 + row_num, col_num, cell_value/100, percentage_format)
                else:
                    ws_laundry.write(start_row_l_profile + 3 + row_num, col_num, cell_value, data_format)

        # Add Bar vs Powder Analysis
        bar_powder_data = [
            ['Bar Soap', 285, 63.6, 44.26, 82.8, 17.2],
            ['Powder', 163, 36.4, 149.86, 84.7, 15.3]
        ]

        bar_powder_df = pd.DataFrame(bar_powder_data, columns=[
            'Type', 'Total Purchases', 'Market Share %', 'Avg Price', 'Male %', 'Female %'
        ])

        start_row_bp = start_row_l_profile + len(laundry_profile_df) + 5
        ws_laundry.write(start_row_bp, 0, 'BAR VS POWDER ANALYSIS', section_header_format)
        ws_laundry.merge_range(f'A{start_row_bp+1}:F{start_row_bp+1}', 'BAR VS POWDER ANALYSIS', section_header_format)

        bar_powder_df.to_excel(writer, sheet_name='Laundry Analytics', index=False, startrow=start_row_bp+1)

        for col_num, value in enumerate(bar_powder_df.columns.values):
            ws_laundry.write(start_row_bp + 2, col_num, value, header_format)

        for row_num in range(len(bar_powder_df)):
            for col_num, col_name in enumerate(bar_powder_df.columns):
                cell_value = bar_powder_df.iloc[row_num, col_num]

                if col_name in ['Market Share %', 'Male %', 'Female %']:
                    ws_laundry.write(start_row_bp + 3 + row_num, col_num, cell_value/100, percentage_format)
                elif col_name == 'Avg Price':
                    ws_laundry.write(start_row_bp + 3 + row_num, col_num, cell_value, currency_format)
                elif col_name == 'Total Purchases':
                    ws_laundry.write(start_row_bp + 3 + row_num, col_num, cell_value, number_format)
                else:
                    ws_laundry.write(start_row_bp + 3 + row_num, col_num, cell_value, data_format)

        # Auto-adjust laundry columns
        for i in range(10):
            ws_laundry.set_column(i, i, 15)

        # 5. Summary Dashboard
        summary_data = pd.DataFrame([
            ['Report Generated', datetime.now().strftime('%Y-%m-%d %H:%M:%S')],
            ['Data Source', 'Scout v7 Database'],
            ['Demographics Source', 'Facial Recognition System'],
            ['Active Stores Analyzed', '7 stores with canonical_tx_id data'],
            ['Total Transactions', '12,192 verified transactions'],
            ['Tobacco Products', '6 brands analyzed'],
            ['Laundry Products', '5 brands analyzed'],
            ['Key Insight', 'Male-dominated categories (75-87% male)'],
            ['Age Profile', 'Core demographic: 30-39 years old'],
            ['Pecha de Peligro Effect', 'Confirmed 15-31 month pattern'],
            ['Contact', 'cc: @Jaymie Divinagracia']
        ], columns=['Metric', 'Value'])

        summary_data.to_excel(writer, sheet_name='Executive Summary', index=False, startrow=2)
        ws_summary = writer.sheets['Executive Summary']
        ws_summary.write('A1', 'DAN RYAN ANALYTICS - EXECUTIVE SUMMARY', title_format)
        ws_summary.merge_range('A1:B1', 'DAN RYAN ANALYTICS - EXECUTIVE SUMMARY', title_format)

        # Format summary
        for col_num, value in enumerate(summary_data.columns.values):
            ws_summary.write(2, col_num, value, header_format)

        for row_num in range(len(summary_data)):
            for col_num in range(len(summary_data.columns)):
                cell_value = summary_data.iloc[row_num, col_num]
                ws_summary.write(row_num + 3, col_num, cell_value, data_format)

        ws_summary.set_column(0, 0, 25)
        ws_summary.set_column(1, 1, 35)

    print(f"\n🎉 COMPLETE DAN RYAN EXCEL REPORT GENERATED!")
    print(f"📁 Output: {output_file}")
    print(f"📊 Worksheets:")
    print(f"   • Store Demographics (with sales patterns)")
    print(f"   • Tobacco Analytics (demographics + purchase profiles)")
    print(f"   • Laundry Analytics (demographics + bar vs powder)")
    print(f"   • Executive Summary")
    print(f"📈 Features:")
    print(f"   • Professional formatting with borders and shading")
    print(f"   • Currency, percentage, and number formatting")
    print(f"   • Section headers and merged cells")
    print(f"   • All Dan Ryan requirements included")

    return output_file

if __name__ == "__main__":
    create_complete_dan_ryan_excel()