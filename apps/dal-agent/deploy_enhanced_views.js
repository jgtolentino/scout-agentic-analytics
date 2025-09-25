const sql = require('mssql');
const fs = require('fs');
const path = require('path');

async function deployEnhancedViews() {
    const cfg = {
        server: 'sqltbwaprojectscoutserver.database.windows.net',
        database: 'SQL-TBWA-ProjectScout-Reporting-Prod',
        user: 'TBWA',
        password: 'R@nd0mPA$2025!',
        options: { encrypt: true, trustServerCertificate: false }
    };

    let pool;
    try {
        console.log('Connecting to Azure SQL Database...');
        pool = await new sql.ConnectionPool(cfg).connect();
        console.log('✅ Connected successfully!');

        // Read the SQL file
        const sqlContent = fs.readFileSync(path.join(__dirname, 'sql', 'enhanced_cross_tab_view.sql'), 'utf8');

        // Split the SQL into individual statements and execute them
        const statements = sqlContent.split('GO').filter(s => s.trim().length > 0);

        console.log(`Found ${statements.length} SQL statements to execute...`);

        for (let i = 0; i < statements.length; i++) {
            const statement = statements[i].trim();
            if (statement.length === 0) continue;

            try {
                console.log(`Executing statement ${i + 1}/${statements.length}...`);
                await pool.request().query(statement);
                console.log(`✅ Statement ${i + 1} executed successfully`);
            } catch (err) {
                console.error(`❌ Error executing statement ${i + 1}:`, err.message);
                // Continue with other statements unless it's a critical error
                if (err.message.includes('Cannot drop') || err.message.includes('does not exist')) {
                    console.log('🔄 Continuing with remaining statements...');
                } else {
                    throw err;
                }
            }
        }

        console.log('🎉 Enhanced cross-tabulation views deployed successfully!');

        // Test the main view
        console.log('Testing the main view...');
        const testResult = await pool.request().query(`
            SELECT TOP 5
                canonical_tx_id,
                purchased_brand,
                category,
                age_bracket,
                pack_size_bucket,
                payment_method
            FROM dbo.v_insight_cross_tabs
        `);

        console.log(`✅ Main view working! Found ${testResult.recordset.length} sample records.`);
        console.log('Sample data:', testResult.recordset);

    } catch (err) {
        console.error('❌ Deployment failed:', err.message);
        process.exit(1);
    } finally {
        if (pool) {
            await pool.close();
            console.log('Connection closed.');
        }
    }
}

deployEnhancedViews();