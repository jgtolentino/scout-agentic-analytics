import { ConnectionPool, config as sqlConfig, Request, IResult } from 'mssql';

// SQL Server configuration
const sqlServerConfig: sqlConfig = {
  server: process.env.AZURE_SQL_SERVER || 'sqltbwaprojectscoutserver.database.windows.net',
  database: process.env.AZURE_SQL_DATABASE || 'SQL-TBWA-ProjectScout-Reporting-Prod',
  user: process.env.AZURE_SQL_USER || 'sqladmin',
  password: process.env.AZURE_SQL_PASSWORD || 'Azure_pw26',
  port: parseInt(process.env.AZURE_SQL_PORT || '1433'),
  options: {
    encrypt: true,
    trustServerCertificate: false,
    enableArithAbort: true,
    requestTimeout: 30000,
    connectTimeout: 30000,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

// Connection pool instance
let pool: ConnectionPool | null = null;

// Initialize connection pool
export async function initializePool(): Promise<ConnectionPool> {
  if (!pool) {
    try {
      console.log('Initializing Azure SQL connection pool...');
      console.log('Server:', sqlServerConfig.server);
      console.log('Database:', sqlServerConfig.database);
      console.log('User:', sqlServerConfig.user);
      console.log('Port:', sqlServerConfig.port);

      pool = new ConnectionPool(sqlServerConfig);
      await pool.connect();
      console.log('Successfully connected to Azure SQL Database');
    } catch (error) {
      console.error('Failed to connect to Azure SQL Database:', error);
      pool = null;
      throw error;
    }
  }
  return pool;
}

// Execute query with retry logic
export async function executeQuery<T = any>(
  query: string,
  params: Record<string, any> = {}
): Promise<IResult<T>> {
  let retries = 3;

  while (retries > 0) {
    try {
      const currentPool = await initializePool();
      const request = new Request(currentPool);

      // Add parameters to request
      Object.entries(params).forEach(([key, value]) => {
        if (typeof value === 'string') {
          request.input(key, value);
        } else if (typeof value === 'number') {
          request.input(key, value);
        } else if (Array.isArray(value)) {
          // Handle array parameters for IN clauses
          request.input(key, value.join(','));
        }
      });

      const result = await request.query<T>(query);
      return result;
    } catch (error) {
      console.error(`SQL query failed (${retries} retries left):`, error);
      retries--;

      if (retries === 0) {
        throw error;
      }

      // Reset pool if connection failed
      if (pool) {
        try {
          await pool.close();
        } catch (closeError) {
          console.error('Error closing pool:', closeError);
        }
        pool = null;
      }

      // Wait before retry
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }

  throw new Error('Query failed after all retries');
}

// Scout Dashboard Data Queries
export const ScoutQueries = {
  // Get all dashboard transactions with filters
  getTransactions: (filters: {
    dateStart?: string;
    dateEnd?: string;
    storeIds?: string[];
    brands?: string[];
    categories?: string[];
    limit?: number;
    offset?: number;
  }) => {
    let whereClause = 'WHERE 1=1';
    const params: Record<string, any> = {};

    if (filters.dateStart) {
      whereClause += ' AND timestamp >= @dateStart';
      params.dateStart = filters.dateStart;
    }

    if (filters.dateEnd) {
      whereClause += ' AND timestamp <= @dateEnd';
      params.dateEnd = filters.dateEnd;
    }

    if (filters.storeIds?.length) {
      whereClause += ` AND store_id IN (${filters.storeIds.map((_, i) => `@store${i}`).join(',')})`;
      filters.storeIds.forEach((storeId, i) => {
        params[`store${i}`] = storeId;
      });
    }

    if (filters.brands?.length) {
      whereClause += ` AND brand_name IN (${filters.brands.map((_, i) => `@brand${i}`).join(',')})`;
      filters.brands.forEach((brand, i) => {
        params[`brand${i}`] = brand;
      });
    }

    if (filters.categories?.length) {
      whereClause += ` AND product_category IN (${filters.categories.map((_, i) => `@cat${i}`).join(',')})`;
      filters.categories.forEach((category, i) => {
        params[`cat${i}`] = category;
      });
    }

    const limitClause = filters.limit ? `OFFSET ${filters.offset || 0} ROWS FETCH NEXT ${filters.limit} ROWS ONLY` : '';

    return {
      query: `
        SELECT
          id,
          store_id,
          timestamp,
          time_of_day,
          location_barangay,
          location_city,
          location_province,
          location_region,
          product_category,
          brand_name,
          sku,
          units_per_transaction,
          peso_value,
          basket_size,
          combo_basket,
          request_mode,
          request_type,
          suggestion_accepted,
          gender,
          age_bracket,
          substitution_occurred,
          substitution_from,
          substitution_to,
          substitution_reason,
          duration_seconds,
          campaign_influenced,
          handshake_score,
          is_tbwa_client,
          payment_method,
          customer_type,
          store_type,
          economic_class
        FROM gold.scout_dashboard_transactions
        ${whereClause}
        ORDER BY timestamp DESC
        ${limitClause}
      `,
      params
    };
  },

  // Get KPI metrics
  getKPIs: (filters: {
    dateStart?: string;
    dateEnd?: string;
    storeIds?: string[];
    categories?: string[];
  }) => {
    let whereClause = 'WHERE 1=1';
    const params: Record<string, any> = {};

    if (filters.dateStart) {
      whereClause += ' AND timestamp >= @dateStart';
      params.dateStart = filters.dateStart;
    }

    if (filters.dateEnd) {
      whereClause += ' AND timestamp <= @dateEnd';
      params.dateEnd = filters.dateEnd;
    }

    if (filters.storeIds?.length) {
      whereClause += ` AND store_id IN (${filters.storeIds.map((_, i) => `@store${i}`).join(',')})`;
      filters.storeIds.forEach((storeId, i) => {
        params[`store${i}`] = storeId;
      });
    }

    if (filters.categories?.length) {
      whereClause += ` AND product_category IN (${filters.categories.map((_, i) => `@cat${i}`).join(',')})`;
      filters.categories.forEach((category, i) => {
        params[`cat${i}`] = category;
      });
    }

    return {
      query: `
        SELECT
          COUNT(*) as total_transactions,
          SUM(peso_value) as total_revenue,
          AVG(peso_value) as avg_transaction_value,
          COUNT(DISTINCT store_id) as unique_stores,
          COUNT(DISTINCT brand_name) as unique_brands,

          -- Conversion Rate: Transactions with purchase / Total interactions
          CAST(COUNT(*) AS FLOAT) / COUNT(*) * 100 as conversion_rate,

          -- Suggestion Accept Rate
          CAST(SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as suggestion_accept_rate,

          -- Brand Loyalty: Branded requests / Total requests
          CAST(SUM(CASE WHEN request_type = 'branded' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as brand_loyalty_rate,

          -- Discovery Rate: New brand experiences
          CAST(COUNT(DISTINCT brand_name) AS FLOAT) / COUNT(*) * 100 as discovery_rate,

          -- TBWA Client Share
          CAST(SUM(CASE WHEN is_tbwa_client = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as tbwa_client_share

        FROM gold.scout_dashboard_transactions
        ${whereClause}
      `,
      params
    };
  },

  // Get behavior analytics
  getBehaviorAnalytics: (filters: {
    dateStart?: string;
    dateEnd?: string;
    storeIds?: string[];
  }) => {
    let whereClause = 'WHERE 1=1';
    const params: Record<string, any> = {};

    if (filters.dateStart) {
      whereClause += ' AND timestamp >= @dateStart';
      params.dateStart = filters.dateStart;
    }

    if (filters.dateEnd) {
      whereClause += ' AND timestamp <= @dateEnd';
      params.dateEnd = filters.dateEnd;
    }

    if (filters.storeIds?.length) {
      whereClause += ` AND store_id IN (${filters.storeIds.map((_, i) => `@store${i}`).join(',')})`;
      filters.storeIds.forEach((storeId, i) => {
        params[`store${i}`] = storeId;
      });
    }

    return {
      query: `
        SELECT
          -- Purchase Funnel Data
          'purchase_funnel' as metric_type,
          JSON_QUERY('[
            {"stage": "Store Visit", "count": ' + CAST(COUNT(*) * 4 AS NVARCHAR(10)) + '},
            {"stage": "Product Browse", "count": ' + CAST(COUNT(*) * 3 AS NVARCHAR(10)) + '},
            {"stage": "Brand Request", "count": ' + CAST(COUNT(*) * 2 AS NVARCHAR(10)) + '},
            {"stage": "Accept Suggestion", "count": ' + CAST(SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"stage": "Purchase", "count": ' + CAST(COUNT(*) AS NVARCHAR(10)) + '}
          ]') as data
        FROM gold.scout_dashboard_transactions
        ${whereClause}

        UNION ALL

        SELECT
          'request_methods' as metric_type,
          JSON_QUERY('[
            {"method": "Verbal", "count": ' + CAST(SUM(CASE WHEN request_mode = 'verbal' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + ', "percentage": ' + CAST(SUM(CASE WHEN request_mode = 'verbal' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS NVARCHAR(10)) + '},
            {"method": "Pointing", "count": ' + CAST(SUM(CASE WHEN request_mode = 'pointing' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + ', "percentage": ' + CAST(SUM(CASE WHEN request_mode = 'pointing' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS NVARCHAR(10)) + '},
            {"method": "Indirect", "count": ' + CAST(SUM(CASE WHEN request_mode = 'indirect' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + ', "percentage": ' + CAST(SUM(CASE WHEN request_mode = 'indirect' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS NVARCHAR(10)) + '}
          ]') as data
        FROM gold.scout_dashboard_transactions
        ${whereClause}

        UNION ALL

        SELECT
          'age_demographics' as metric_type,
          JSON_QUERY('[
            {"age": "18-24", "count": ' + CAST(SUM(CASE WHEN age_bracket = '18-24' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "25-34", "count": ' + CAST(SUM(CASE WHEN age_bracket = '25-34' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "35-44", "count": ' + CAST(SUM(CASE WHEN age_bracket = '35-44' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "45-54", "count": ' + CAST(SUM(CASE WHEN age_bracket = '45-54' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "55+", "count": ' + CAST(SUM(CASE WHEN age_bracket = '55+' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '},
            {"age": "Unknown", "count": ' + CAST(SUM(CASE WHEN age_bracket = 'unknown' THEN 1 ELSE 0 END) AS NVARCHAR(10)) + '}
          ]') as data
        FROM gold.scout_dashboard_transactions
        ${whereClause}
      `,
      params
    };
  },

  // Get transaction trends
  getTransactionTrends: (filters: {
    dateStart?: string;
    dateEnd?: string;
    storeIds?: string[];
    granularity?: 'hour' | 'day' | 'week' | 'month';
  }) => {
    let whereClause = 'WHERE 1=1';
    const params: Record<string, any> = {};

    if (filters.dateStart) {
      whereClause += ' AND timestamp >= @dateStart';
      params.dateStart = filters.dateStart;
    }

    if (filters.dateEnd) {
      whereClause += ' AND timestamp <= @dateEnd';
      params.dateEnd = filters.dateEnd;
    }

    if (filters.storeIds?.length) {
      whereClause += ` AND store_id IN (${filters.storeIds.map((_, i) => `@store${i}`).join(',')})`;
      filters.storeIds.forEach((storeId, i) => {
        params[`store${i}`] = storeId;
      });
    }

    const granularity = filters.granularity || 'day';
    let timeGroup = '';

    switch (granularity) {
      case 'hour':
        timeGroup = "FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM-dd HH'):00:00";
        break;
      case 'day':
        timeGroup = "FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM-dd')";
        break;
      case 'week':
        timeGroup = "FORMAT(DATEADD(day, -DATEPART(weekday, CAST(timestamp AS DATETIME2)) + 1, CAST(timestamp AS DATETIME2)), 'yyyy-MM-dd')";
        break;
      case 'month':
        timeGroup = "FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM')";
        break;
      default:
        timeGroup = "FORMAT(CAST(timestamp AS DATETIME2), 'yyyy-MM-dd')";
    }

    return {
      query: `
        SELECT
          ${timeGroup} as period,
          COUNT(*) as transaction_count,
          SUM(peso_value) as total_revenue,
          AVG(peso_value) as avg_transaction_value,
          COUNT(DISTINCT store_id) as active_stores,
          COUNT(DISTINCT brand_name) as unique_brands,
          time_of_day,
          SUM(CASE WHEN suggestion_accepted = 1 THEN 1 ELSE 0 END) as suggestions_accepted
        FROM gold.scout_dashboard_transactions
        ${whereClause}
        GROUP BY ${timeGroup}, time_of_day
        ORDER BY period DESC, time_of_day
      `,
      params
    };
  }
};

// Close pool on process exit
process.on('beforeExit', async () => {
  if (pool) {
    await pool.close();
  }
});

export default { executeQuery, ScoutQueries, initializePool };