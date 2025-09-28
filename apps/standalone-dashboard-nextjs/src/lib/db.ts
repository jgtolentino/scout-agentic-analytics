// Azure SQL Database client with Managed Identity support
import sql from 'mssql';

let pool: sql.ConnectionPool | null = null;

// Database configuration
const dbConfig = {
  server: process.env.AZURE_SQL_SERVER || 'sqltbwaprojectscoutserver.database.windows.net',
  database: process.env.AZURE_SQL_DATABASE || 'SQL-TBWA-ProjectScout-Reporting-Prod',
  options: {
    encrypt: true, // Always encrypt for Azure SQL
    trustServerCertificate: false,
    enableArithAbort: true,
    requestTimeout: 30000,
    connectionTimeout: 30000,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
} as sql.config;

// Configure authentication method
const useManagedIdentity = process.env.MI_ENABLED === '1' || process.env.NODE_ENV === 'production';

if (useManagedIdentity) {
  // Use Managed Identity for production Azure App Service
  dbConfig.authentication = {
    type: 'azure-active-directory-msi-vm' as any,
  };
  console.log('🔐 Using Azure Managed Identity for SQL authentication');
} else {
  // Fallback to connection string or username/password for development
  if (process.env.AZURE_SQL_CONNECTION_STRING) {
    dbConfig.connectionString = process.env.AZURE_SQL_CONNECTION_STRING;
    console.log('🔐 Using connection string for SQL authentication');
  } else {
    dbConfig.user = process.env.AZURE_SQL_USER;
    dbConfig.password = process.env.AZURE_SQL_PASSWORD;
    console.log('🔐 Using username/password for SQL authentication');
  }
}

export async function getPool(): Promise<sql.ConnectionPool> {
  if (!pool) {
    try {
      console.log('🔌 Connecting to Azure SQL Database...');
      pool = new sql.ConnectionPool(dbConfig);
      await pool.connect();
      console.log('✅ Connected to Azure SQL Database');

      // Test connection
      const result = await pool.request().query('SELECT 1 as test');
      console.log('🧪 Database connection test:', result.recordset[0]);
    } catch (error) {
      console.error('❌ Failed to connect to Azure SQL Database:', error);
      pool = null;
      throw error;
    }
  }
  return pool;
}

export async function executeQuery<T = any>(query: string, params?: Record<string, any>): Promise<T[]> {
  try {
    const poolConnection = await getPool();
    const request = poolConnection.request();

    // Add parameters if provided
    if (params) {
      for (const [key, value] of Object.entries(params)) {
        request.input(key, value);
      }
    }

    const result = await request.query(query);
    return result.recordset as T[];
  } catch (error) {
    console.error('❌ SQL Query failed:', error);
    throw error;
  }
}

export async function executeStoredProcedure<T = any>(
  procedureName: string,
  params?: Record<string, any>
): Promise<T[]> {
  try {
    const poolConnection = await getPool();
    const request = poolConnection.request();

    // Add parameters if provided
    if (params) {
      for (const [key, value] of Object.entries(params)) {
        request.input(key, value);
      }
    }

    const result = await request.execute(procedureName);
    return result.recordset as T[];
  } catch (error) {
    console.error('❌ Stored procedure execution failed:', error);
    throw error;
  }
}

// Graceful shutdown
export async function closePool(): Promise<void> {
  if (pool) {
    try {
      await pool.close();
      pool = null;
      console.log('🔌 Database connection pool closed');
    } catch (error) {
      console.error('❌ Error closing database pool:', error);
    }
  }
}

// Health check function
export async function checkDatabaseHealth(): Promise<{ connected: boolean; server?: string; database?: string; error?: string }> {
  try {
    const poolConnection = await getPool();
    const result = await poolConnection.request().query(`
      SELECT
        @@SERVERNAME as server_name,
        DB_NAME() as database_name,
        GETDATE() as current_time
    `);

    return {
      connected: true,
      server: result.recordset[0].server_name,
      database: result.recordset[0].database_name,
    };
  } catch (error) {
    return {
      connected: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}