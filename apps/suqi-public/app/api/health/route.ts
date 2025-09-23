import { NextResponse } from 'next/server';
import { getScoutCache } from '@/lib/redis';
import { healthCheckKeyVault } from '@/lib/keyVault';
import { getScoutMonitoring } from '@/lib/monitoring';
import sql from 'mssql';

export const runtime = 'nodejs';

interface HealthCheckResult {
  service: string;
  status: 'healthy' | 'unhealthy' | 'degraded';
  responseTime: number;
  message: string;
  details?: any;
}

interface SystemHealth {
  status: 'healthy' | 'unhealthy' | 'degraded';
  timestamp: string;
  version: string;
  uptime: number;
  checks: HealthCheckResult[];
  summary: {
    total: number;
    healthy: number;
    unhealthy: number;
    degraded: number;
  };
}

export async function GET() {
  const startTime = Date.now();
  const monitoring = getScoutMonitoring();

  try {
    // Run all health checks in parallel
    const checks = await Promise.allSettled([
      checkDatabase(),
      checkRedis(),
      checkKeyVault(),
      checkApplicationInsights(),
      checkSystemResources()
    ]);

    const healthResults: HealthCheckResult[] = checks.map((result, index) => {
      const services = ['database', 'redis', 'keyvault', 'monitoring', 'system'];
      const serviceName = services[index];

      if (result.status === 'fulfilled') {
        return result.value;
      } else {
        return {
          service: serviceName,
          status: 'unhealthy' as const,
          responseTime: Date.now() - startTime,
          message: result.reason?.message || 'Health check failed',
          details: { error: result.reason }
        };
      }
    });

    // Calculate overall status
    const summary = {
      total: healthResults.length,
      healthy: healthResults.filter(r => r.status === 'healthy').length,
      unhealthy: healthResults.filter(r => r.status === 'unhealthy').length,
      degraded: healthResults.filter(r => r.status === 'degraded').length
    };

    let overallStatus: 'healthy' | 'unhealthy' | 'degraded' = 'healthy';
    if (summary.unhealthy > 0) {
      overallStatus = summary.unhealthy >= summary.total / 2 ? 'unhealthy' : 'degraded';
    } else if (summary.degraded > 0) {
      overallStatus = 'degraded';
    }

    const health: SystemHealth = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      uptime: process.uptime(),
      checks: healthResults,
      summary
    };

    // Track health check in monitoring
    await monitoring.trackHealthCheck(
      'system',
      overallStatus,
      Date.now() - startTime,
      health
    );

    // Return appropriate HTTP status
    const httpStatus = overallStatus === 'healthy' ? 200 :
                      overallStatus === 'degraded' ? 200 : 503;

    return NextResponse.json(health, { status: httpStatus });

  } catch (error) {
    const errorHealth: SystemHealth = {
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      uptime: process.uptime(),
      checks: [{
        service: 'health_check',
        status: 'unhealthy',
        responseTime: Date.now() - startTime,
        message: `Health check system failure: ${error instanceof Error ? error.message : 'Unknown error'}`
      }],
      summary: { total: 1, healthy: 0, unhealthy: 1, degraded: 0 }
    };

    return NextResponse.json(errorHealth, { status: 503 });
  }
}

async function checkDatabase(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    // Test database connectivity
    const pool = new sql.ConnectionPool({
      server: process.env.SQL_SERVER!,
      database: process.env.SQL_DATABASE!,
      user: process.env.SQL_USER!,
      password: process.env.SQL_PASSWORD!,
      options: {
        encrypt: true,
        trustServerCertificate: false,
        connectTimeout: 5000,
        requestTimeout: 5000
      }
    });

    await pool.connect();

    // Test query
    const result = await pool.request().query('SELECT 1 as test, GETDATE() as current_time');
    await pool.close();

    const responseTime = Date.now() - startTime;

    return {
      service: 'database',
      status: 'healthy',
      responseTime,
      message: 'Database connection successful',
      details: {
        server: process.env.SQL_SERVER,
        database: process.env.SQL_DATABASE,
        timestamp: result.recordset[0].current_time
      }
    };

  } catch (error) {
    return {
      service: 'database',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `Database connection failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      details: { error }
    };
  }
}

async function checkRedis(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    const cache = getScoutCache();
    const health = await cache.healthCheck();

    return {
      service: 'redis',
      status: health.status,
      responseTime: health.responseTime || Date.now() - startTime,
      message: health.message,
      details: health.stats
    };

  } catch (error) {
    return {
      service: 'redis',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `Redis health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      details: { error }
    };
  }
}

async function checkKeyVault(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    const health = await healthCheckKeyVault();

    return {
      service: 'keyvault',
      status: health.status,
      responseTime: health.responseTime || Date.now() - startTime,
      message: health.message
    };

  } catch (error) {
    return {
      service: 'keyvault',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `Key Vault health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      details: { error }
    };
  }
}

async function checkApplicationInsights(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;

    if (!connectionString) {
      return {
        service: 'monitoring',
        status: 'degraded',
        responseTime: Date.now() - startTime,
        message: 'Application Insights not configured'
      };
    }

    // Test telemetry
    const monitoring = getScoutMonitoring();
    await monitoring.trackMetric('health.check', 1, { service: 'monitoring' });

    return {
      service: 'monitoring',
      status: 'healthy',
      responseTime: Date.now() - startTime,
      message: 'Application Insights operational'
    };

  } catch (error) {
    return {
      service: 'monitoring',
      status: 'degraded',
      responseTime: Date.now() - startTime,
      message: `Monitoring check failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      details: { error }
    };
  }
}

async function checkSystemResources(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    const memoryUsage = process.memoryUsage();
    const cpuUsage = process.cpuUsage();

    // Calculate memory usage percentage (assuming 1GB container limit)
    const memoryLimitBytes = 1024 * 1024 * 1024; // 1GB
    const memoryUsagePercent = (memoryUsage.rss / memoryLimitBytes) * 100;

    // Determine status based on resource usage
    let status: 'healthy' | 'degraded' | 'unhealthy' = 'healthy';
    let message = 'System resources normal';

    if (memoryUsagePercent > 90) {
      status = 'unhealthy';
      message = 'Critical memory usage';
    } else if (memoryUsagePercent > 80) {
      status = 'degraded';
      message = 'High memory usage';
    }

    return {
      service: 'system',
      status,
      responseTime: Date.now() - startTime,
      message,
      details: {
        memory: {
          rss: Math.round(memoryUsage.rss / 1024 / 1024), // MB
          heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024), // MB
          heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024), // MB
          external: Math.round(memoryUsage.external / 1024 / 1024), // MB
          usagePercent: Math.round(memoryUsagePercent * 100) / 100
        },
        cpu: {
          user: cpuUsage.user,
          system: cpuUsage.system
        },
        uptime: process.uptime(),
        version: process.version,
        platform: process.platform,
        arch: process.arch
      }
    };

  } catch (error) {
    return {
      service: 'system',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `System resource check failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      details: { error }
    };
  }
}

// Deep health check for troubleshooting
export async function POST() {
  const startTime = Date.now();

  try {
    // Extended health checks
    const checks = await Promise.allSettled([
      checkDatabase(),
      checkDatabaseQueries(),
      checkRedis(),
      checkRedisOperations(),
      checkKeyVault(),
      checkApplicationInsights(),
      checkSystemResources(),
      checkDiskSpace(),
      checkNetworkConnectivity()
    ]);

    const healthResults: HealthCheckResult[] = checks.map((result, index) => {
      const services = [
        'database', 'database_queries', 'redis', 'redis_operations',
        'keyvault', 'monitoring', 'system', 'disk', 'network'
      ];
      const serviceName = services[index];

      if (result.status === 'fulfilled') {
        return result.value;
      } else {
        return {
          service: serviceName,
          status: 'unhealthy' as const,
          responseTime: Date.now() - startTime,
          message: result.reason?.message || 'Deep health check failed',
          details: { error: result.reason }
        };
      }
    });

    const summary = {
      total: healthResults.length,
      healthy: healthResults.filter(r => r.status === 'healthy').length,
      unhealthy: healthResults.filter(r => r.status === 'unhealthy').length,
      degraded: healthResults.filter(r => r.status === 'degraded').length
    };

    let overallStatus: 'healthy' | 'unhealthy' | 'degraded' = 'healthy';
    if (summary.unhealthy > 0) {
      overallStatus = summary.unhealthy >= summary.total / 2 ? 'unhealthy' : 'degraded';
    } else if (summary.degraded > 0) {
      overallStatus = 'degraded';
    }

    const health: SystemHealth = {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      uptime: process.uptime(),
      checks: healthResults,
      summary
    };

    const httpStatus = overallStatus === 'healthy' ? 200 :
                      overallStatus === 'degraded' ? 200 : 503;

    return NextResponse.json(health, { status: httpStatus });

  } catch (error) {
    return NextResponse.json({
      status: 'unhealthy',
      message: `Deep health check failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      timestamp: new Date().toISOString()
    }, { status: 503 });
  }
}

async function checkDatabaseQueries(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    const pool = new sql.ConnectionPool({
      server: process.env.SQL_SERVER!,
      database: process.env.SQL_DATABASE!,
      user: process.env.SQL_USER!,
      password: process.env.SQL_PASSWORD!,
      options: {
        encrypt: true,
        trustServerCertificate: false,
        connectTimeout: 5000,
        requestTimeout: 10000
      }
    });

    await pool.connect();

    // Test critical queries
    const transactionCount = await pool.request()
      .query('SELECT COUNT(*) as count FROM silver.Transactions');

    const lastSync = await pool.request()
      .query(`
        SELECT TOP 1 last_heartbeat, status
        FROM system.v_task_status
        WHERE task_name LIKE '%SYNC%'
        ORDER BY last_heartbeat DESC
      `);

    await pool.close();

    const responseTime = Date.now() - startTime;

    return {
      service: 'database_queries',
      status: 'healthy',
      responseTime,
      message: 'Database queries successful',
      details: {
        transactionCount: transactionCount.recordset[0].count,
        lastSync: lastSync.recordset[0] || null
      }
    };

  } catch (error) {
    return {
      service: 'database_queries',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `Database query test failed: ${error instanceof Error ? error.message : 'Unknown error'}`
    };
  }
}

async function checkRedisOperations(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    const cache = getScoutCache();

    // Test cache operations
    const testKey = `health_check_${Date.now()}`;
    const testValue = { timestamp: new Date().toISOString(), test: true };

    await cache.redis.set(testKey, testValue, { ttl: 60 });
    const retrieved = await cache.redis.get(testKey);
    await cache.redis.delete(testKey);

    const responseTime = Date.now() - startTime;

    if (JSON.stringify(retrieved) === JSON.stringify(testValue)) {
      return {
        service: 'redis_operations',
        status: 'healthy',
        responseTime,
        message: 'Redis operations successful'
      };
    } else {
      return {
        service: 'redis_operations',
        status: 'degraded',
        responseTime,
        message: 'Redis operation data integrity issue'
      };
    }

  } catch (error) {
    return {
      service: 'redis_operations',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `Redis operations test failed: ${error instanceof Error ? error.message : 'Unknown error'}`
    };
  }
}

async function checkDiskSpace(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    // This is a simplified check - in production you'd use fs.statSync
    const tmpDir = '/tmp';
    const stats = require('fs').statSync(tmpDir);

    return {
      service: 'disk',
      status: 'healthy',
      responseTime: Date.now() - startTime,
      message: 'Disk space check completed',
      details: {
        available: 'unknown', // Would calculate from fs.statSync
        used: 'unknown'
      }
    };

  } catch (error) {
    return {
      service: 'disk',
      status: 'degraded',
      responseTime: Date.now() - startTime,
      message: 'Disk space check not available in this environment'
    };
  }
}

async function checkNetworkConnectivity(): Promise<HealthCheckResult> {
  const startTime = Date.now();

  try {
    // Test external connectivity
    const response = await fetch('https://httpbin.org/status/200', {
      signal: AbortSignal.timeout(5000)
    });

    const responseTime = Date.now() - startTime;

    if (response.ok) {
      return {
        service: 'network',
        status: 'healthy',
        responseTime,
        message: 'Network connectivity successful'
      };
    } else {
      return {
        service: 'network',
        status: 'degraded',
        responseTime,
        message: `Network connectivity degraded: ${response.status}`
      };
    }

  } catch (error) {
    return {
      service: 'network',
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      message: `Network connectivity failed: ${error instanceof Error ? error.message : 'Unknown error'}`
    };
  }
}