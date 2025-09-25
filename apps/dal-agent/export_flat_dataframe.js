const sql = require('mssql');
const fs = require('fs');

async function exportFlatDataframe() {
    const cfg = {
        server: process.env.AZURE_SQL_SERVER || 'sqltbwaprojectscoutserver.database.windows.net',
        database: process.env.AZURE_SQL_DATABASE || 'SQL-TBWA-ProjectScout-Reporting-Prod',
        user: process.env.AZURE_SQL_USER || 'TBWA',
        password: process.env.AZURE_SQL_PASSWORD || 'R@nd0mPA$2025!',
        options: { encrypt: true, trustServerCertificate: false }
    };

    let pool;
    try {
        console.log('Connecting to Azure SQL...');
        pool = await new sql.ConnectionPool(cfg).connect();
        console.log('✅ Connected!');

        console.log('Exporting flat enriched dataframe...');
        const result = await pool.request().query(`
            SELECT
                canonical_tx_id,
                transaction_id,
                transaction_timestamp,
                DATEPART(HOUR, transaction_timestamp) as hour_of_day,
                daypart,
                weekday_weekend,
                transaction_value,
                basket_size,
                payment_method,
                brand_name,
                nielsen_category,
                nielsen_department,
                pack_size,
                age_bracket,
                gender,
                customer_type,
                emotions,
                store_id,
                store_name,
                region,
                province_name,
                municipality_name,
                substitution_event,
                substitution_reason,
                suggestion_accepted
            FROM dbo.v_nielsen_complete_analytics
            WHERE transaction_value > 0
            ORDER BY transaction_timestamp
        `);

        // Convert to CSV
        const data = result.recordset;
        if (data.length === 0) {
            console.log('❌ No data found');
            return;
        }

        console.log(`Found ${data.length} completed transactions`);

        // Create CSV header
        const headers = Object.keys(data[0]);
        const csvContent = [
            headers.join(','),
            ...data.map(row =>
                headers.map(header => {
                    const value = row[header];
                    if (value === null || value === undefined) return '';
                    if (typeof value === 'string' && value.includes(',')) {
                        return `"${value.replace(/"/g, '""')}"`;
                    }
                    return value;
                }).join(',')
            )
        ].join('\n');

        // Write to file
        const filePath = './exports/flat_dataframe_enriched.csv';
        fs.writeFileSync(filePath, csvContent, 'utf8');
        console.log(`✅ Exported ${data.length} records to ${filePath}`);

        // Show sample
        console.log('\nSample data (first 3 rows):');
        console.table(data.slice(0, 3));

    } catch (err) {
        console.error('❌ Export failed:', err.message);
    } finally {
        if (pool) await pool.close();
    }
}

exportFlatDataframe();