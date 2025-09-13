import { createClient } from '@supabase/supabase-js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load environment variables
import dotenv from 'dotenv';
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function applySQL() {
  try {
    console.log('Applying geo and competitive analysis SQL...');
    
    // Read the SQL file
    const sqlPath = path.join(__dirname, '..', 'supabase/sql/dal/2025-08-14_geo_competitive.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    
    // Execute the SQL
    const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });
    
    if (error) {
      // If exec_sql doesn't exist, try executing statements individually
      const statements = sql.split(';').filter(s => s.trim());
      
      for (const statement of statements) {
        if (statement.trim()) {
          console.log('Executing:', statement.substring(0, 50) + '...');
          const { error: stmtError } = await supabase.from('_dummy_').select().limit(0);
          // Since Supabase doesn't have a direct SQL execution method via JS client,
          // we'll need to use the REST API directly
        }
      }
      
      console.log('\n⚠️  Note: Supabase JS client doesn\'t support direct SQL execution.');
      console.log('Please run the SQL manually in the Supabase Dashboard:');
      console.log(`\n1. Go to: ${supabaseUrl}/project/cxzllzyxwpyptfretryc/sql/new`);
      console.log('2. Copy and paste the contents of:');
      console.log(`   ${sqlPath}`);
      console.log('3. Click "Run" to execute the SQL\n');
      
      // Optionally seed demo data
      const readline = await import('readline');
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      });
      
      rl.question('Do you want to see the demo competitor data SQL? (y/N) ', (answer) => {
        if (answer.toLowerCase() === 'y') {
          console.log('\nDemo competitor data SQL:');
          console.log(`
insert into scout.ext_competitor_sales_by_region_daily(dte, region, brand, revenue_php) values
  (current_date - 3, 'Metro Manila', 'Brand X', 320000),
  (current_date - 2, 'Metro Manila', 'Brand X', 305000),
  (current_date - 1, 'Metro Manila', 'Brand X', 315000),
  (current_date - 3, 'Cebu', 'Brand Y', 140000),
  (current_date - 2, 'Cebu', 'Brand Y', 145000),
  (current_date - 1, 'Cebu', 'Brand Y', 150000),
  (current_date - 3, 'Davao', 'Brand Z', 85000),
  (current_date - 2, 'Davao', 'Brand Z', 87000),
  (current_date - 1, 'Davao', 'Brand Z', 90000)
on conflict do nothing;
          `);
        }
        rl.close();
        process.exit(0);
      });
    } else {
      console.log('✅ SQL applied successfully!');
    }
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

applySQL();