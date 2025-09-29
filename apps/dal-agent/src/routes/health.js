const express = require('express');
const router = express.Router();
const dbConnection = require('../config/database');

// Basic health check
router.get('/', async (req, res) => {
  try {
    const dbTest = await dbConnection.testConnection();
    const dbStatus = dbConnection.getStatus();

    const health = {
      status: dbTest.success ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      service: 'Scout Analytics API',
      version: '1.0.0',
      uptime: process.uptime(),
      environment: process.env.NODE_ENV || 'development',
      database: {
        connected: dbTest.success,
        server: dbStatus.server,
        database: dbStatus.database,
        version: dbTest.version || null,
        lastChecked: dbTest.currentTime || null,
        connectionStatus: {
          isConnected: dbStatus.isConnected,
          poolConnected: dbStatus.poolConnected,
          poolConnecting: dbStatus.poolConnecting
        }
      },
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        external: Math.round(process.memoryUsage().external / 1024 / 1024),
        rss: Math.round(process.memoryUsage().rss / 1024 / 1024)
      },
      system: {
        platform: process.platform,
        nodeVersion: process.version,
        pid: process.pid
      }
    };

    if (!dbTest.success) {
      health.error = dbTest.error;
      return res.status(503).json(health);
    }

    res.status(200).json(health);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      service: 'Scout Analytics API',
      error: error.message,
      database: {
        connected: false,
        error: error.message
      }
    });
  }
});

// Detailed health check with analytics validation
router.get('/detailed', async (req, res) => {
  try {
    const dbTest = await dbConnection.testConnection();

    if (!dbTest.success) {
      return res.status(503).json({
        status: 'unhealthy',
        error: 'Database connection failed',
        details: dbTest.error
      });
    }

    // Test core analytics views
    const viewTests = await Promise.allSettled([
      dbConnection.executeQuery("SELECT COUNT(*) as count FROM dbo.v_ultra_enriched_dataset WHERE TransactionDate >= DATEADD(DAY, -1, GETDATE())"),
      dbConnection.executeQuery("SELECT COUNT(*) as active_stores FROM dbo.v_system_health_dashboard"),
      dbConnection.executeQuery("SELECT COUNT(*) as store_count FROM dbo.v_store_performance_summary")
    ]);

    const analyticsHealth = {
      ultraEnrichedDataset: viewTests[0].status === 'fulfilled' ?
        { available: true, recentTransactions: viewTests[0].value.recordset[0].count } :
        { available: false, error: viewTests[0].reason?.message },

      systemHealthDashboard: viewTests[1].status === 'fulfilled' ?
        { available: true } :
        { available: false, error: viewTests[1].reason?.message },

      storePerformance: viewTests[2].status === 'fulfilled' ?
        { available: true, storeCount: viewTests[2].value.recordset[0].store_count } :
        { available: false, error: viewTests[2].reason?.message }
    };

    const allViewsHealthy = viewTests.every(test => test.status === 'fulfilled');

    res.status(allViewsHealthy ? 200 : 206).json({
      status: allViewsHealthy ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      service: 'Scout Analytics API',
      database: {
        connected: true,
        version: dbTest.version,
        server: dbConnection.getStatus().server,
        database: dbConnection.getStatus().database
      },
      analytics: analyticsHealth,
      summary: {
        coreViewsHealthy: allViewsHealthy,
        availableViews: viewTests.filter(t => t.status === 'fulfilled').length,
        totalViews: viewTests.length
      }
    });

  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message,
      service: 'Scout Analytics API'
    });
  }
});

// Readiness probe for Kubernetes/container orchestration
router.get('/ready', async (req, res) => {
  try {
    const dbTest = await dbConnection.testConnection();

    if (dbTest.success) {
      res.status(200).json({
        ready: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(503).json({
        ready: false,
        error: dbTest.error,
        timestamp: new Date().toISOString()
      });
    }
  } catch (error) {
    res.status(503).json({
      ready: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Liveness probe for Kubernetes/container orchestration
router.get('/live', (req, res) => {
  res.status(200).json({
    alive: true,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    pid: process.pid
  });
});

module.exports = router;