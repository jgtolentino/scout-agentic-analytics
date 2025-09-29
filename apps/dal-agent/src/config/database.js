const sql = require('mssql');

class DatabaseConnection {
  constructor() {
    this.pool = null;
    this.config = null;
    this.isConnected = false;
  }

  async initialize() {
    try {
      this.config = await this.getConnectionConfig();
      this.pool = new sql.ConnectionPool(this.config);

      this.pool.on('error', (err) => {
        console.error('Database pool error:', err);
        this.isConnected = false;
      });

      await this.pool.connect();
      this.isConnected = true;

      console.log('✅ Connected to Azure SQL Database');
      return this.pool;
    } catch (error) {
      console.error('❌ Database connection failed:', error);
      this.isConnected = false;
      throw error;
    }
  }

  async getConnectionConfig() {
    // Try direct connection string first
    if (process.env.AZURE_SQL_CONNECTION_STRING) {
      return {
        connectionString: process.env.AZURE_SQL_CONNECTION_STRING,
        options: {
          encrypt: true,
          trustServerCertificate: false,
          connectTimeout: 30000,
          requestTimeout: 30000,
          pool: {
            max: parseInt(process.env.CONNECTION_POOL_MAX) || 20,
            min: parseInt(process.env.CONNECTION_POOL_MIN) || 5,
            idleTimeoutMillis: 30000
          }
        }
      };
    }

    // Fallback to individual components
    const config = {
      server: process.env.AZURE_SQL_SERVER || 'sqltbwaprojectscoutserver.database.windows.net',
      database: process.env.AZURE_SQL_DATABASE || 'SQL-TBWA-ProjectScout-Reporting-Prod',
      authentication: {
        type: 'default',
        options: {
          userName: process.env.AZURE_SQL_USERNAME,
          password: process.env.AZURE_SQL_PASSWORD
        }
      },
      options: {
        encrypt: true,
        trustServerCertificate: false,
        connectTimeout: 30000,
        requestTimeout: 30000,
        enableArithAbort: true,
        pool: {
          max: parseInt(process.env.CONNECTION_POOL_MAX) || 20,
          min: parseInt(process.env.CONNECTION_POOL_MIN) || 5,
          idleTimeoutMillis: 30000
        }
      }
    };

    return config;
  }

  async getConnection() {
    if (!this.isConnected || !this.pool) {
      await this.initialize();
    }

    return this.pool;
  }

  async executeQuery(query, params = {}) {
    try {
      const pool = await this.getConnection();
      const request = pool.request();

      // Add parameters
      Object.keys(params).forEach(key => {
        request.input(key, params[key]);
      });

      const result = await request.query(query);
      return result;
    } catch (error) {
      console.error('Query execution error:', error);
      throw error;
    }
  }

  async executeProcedure(procedureName, params = {}) {
    try {
      const pool = await this.getConnection();
      const request = pool.request();

      // Add parameters
      Object.keys(params).forEach(key => {
        const param = params[key];
        if (typeof param === 'object' && param.type && param.value !== undefined) {
          request.input(key, param.type, param.value);
        } else {
          request.input(key, param);
        }
      });

      const result = await request.execute(procedureName);
      return result;
    } catch (error) {
      console.error('Procedure execution error:', error);
      throw error;
    }
  }

  async testConnection() {
    try {
      const result = await this.executeQuery('SELECT @@VERSION as version, GETDATE() as current_time');
      return {
        success: true,
        version: result.recordset[0].version,
        currentTime: result.recordset[0].current_time,
        isConnected: this.isConnected
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        isConnected: false
      };
    }
  }

  async close() {
    if (this.pool) {
      try {
        await this.pool.close();
        this.isConnected = false;
        console.log('Database connection closed');
      } catch (error) {
        console.error('Error closing database connection:', error);
      }
    }
  }

  getStatus() {
    return {
      isConnected: this.isConnected,
      poolConnected: this.pool?.connected || false,
      poolConnecting: this.pool?.connecting || false,
      database: this.config?.database || process.env.AZURE_SQL_DATABASE,
      server: this.config?.server || process.env.AZURE_SQL_SERVER
    };
  }
}

// Create singleton instance
const dbConnection = new DatabaseConnection();

// Initialize on module load for production
if (process.env.NODE_ENV === 'production') {
  dbConnection.initialize().catch(error => {
    console.error('Failed to initialize database connection:', error);
  });
}

module.exports = dbConnection;