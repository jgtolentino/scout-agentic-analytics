const express = require('express');
const { query, validationResult } = require('express-validator');
const NodeCache = require('node-cache');
const router = express.Router();
const dbConnection = require('../config/database');

// Cache for monitoring data (shorter TTL for real-time data)
const cache = new NodeCache({ stdTTL: 60 }); // 1 minute cache

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }
  next();
};

// GET /api/v1/monitoring/live-dashboard
// Real-time system health dashboard
router.get('/live-dashboard', async (req, res) => {
  try {
    const cacheKey = 'live-dashboard';
    const cached = cache.get(cacheKey);

    if (cached) {
      return res.json({ ...cached, cached: true });
    }

    const result = await dbConnection.executeQuery(`
      SELECT
        platform_status,
        overall_platform_health_score,
        total_transactions_last_hour,
        active_stores,
        unique_customers_last_hour,
        avg_platform_satisfaction * 100 as satisfaction_percentage,
        transaction_validity_score,
        facial_recognition_score,
        brand_detection_score,
        performance_vs_yesterday,
        dashboard_timestamp
      FROM dbo.v_system_health_dashboard
    `);

    const dashboardData = {
      success: true,
      data: result.recordset[0] || {},
      timestamp: new Date().toISOString()
    };

    cache.set(cacheKey, dashboardData, 60);
    res.json(dashboardData);

  } catch (error) {
    console.error('Live dashboard error:', error);
    res.status(500).json({
      error: 'Failed to fetch live dashboard data',
      details: error.message
    });
  }
});

// GET /api/v1/monitoring/store-activity
// Store activity monitoring
router.get('/store-activity',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('alertsOnly').optional().isBoolean()
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, alertsOnly } = req.query;

      let query = `
        SELECT
          StoreID,
          transactions_last_hour,
          unique_customers_last_hour,
          avg_satisfaction_last_hour * 100 as satisfaction_percentage,
          activity_status,
          system_health,
          daily_trend,
          facial_recognition_rate,
          silent_transaction_rate,
          last_transaction_time,
          monitor_timestamp
        FROM dbo.v_live_transaction_monitor
        WHERE 1=1
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      if (alertsOnly === 'true') {
        query += " AND system_health != 'Healthy'";
      }

      query += ' ORDER BY monitor_timestamp DESC';

      const result = await dbConnection.executeQuery(query, params);

      res.json({
        success: true,
        data: result.recordset,
        summary: {
          totalStores: result.recordset.length,
          healthyStores: result.recordset.filter(s => s.system_health === 'Healthy').length,
          alertStores: result.recordset.filter(s => s.system_health !== 'Healthy').length
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Store activity error:', error);
      res.status(500).json({
        error: 'Failed to fetch store activity data',
        details: error.message
      });
    }
  }
);

// GET /api/v1/monitoring/customer-experience
// Customer experience monitoring
router.get('/customer-experience',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('alertPriority').optional().isIn(['High', 'Medium', 'Low'])
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, alertPriority } = req.query;

      let query = `
        SELECT
          StoreID,
          total_interactions,
          satisfaction_score,
          politeness_score,
          experience_status,
          satisfaction_trend,
          politeness_trend,
          language_pattern,
          alert_priority,
          high_satisfaction_rate,
          silent_interaction_rate,
          strong_suki_rate,
          monitor_timestamp
        FROM dbo.v_customer_experience_monitor
        WHERE 1=1
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      if (alertPriority) {
        query += ' AND alert_priority = @alertPriority';
        params.alertPriority = alertPriority;
      }

      query += ' ORDER BY alert_priority DESC, satisfaction_score ASC';

      const result = await dbConnection.executeQuery(query, params);

      res.json({
        success: true,
        data: result.recordset,
        insights: {
          totalStores: result.recordset.length,
          avgSatisfaction: result.recordset.reduce((sum, store) => sum + store.satisfaction_score, 0) / result.recordset.length,
          highAlerts: result.recordset.filter(s => s.alert_priority === 'High').length,
          mediumAlerts: result.recordset.filter(s => s.alert_priority === 'Medium').length
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Customer experience error:', error);
      res.status(500).json({
        error: 'Failed to fetch customer experience data',
        details: error.message
      });
    }
  }
);

// GET /api/v1/monitoring/activity-heatmap
// Store activity heatmap for visualization
router.get('/activity-heatmap',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId } = req.query;

      let query = `
        SELECT
          StoreID,
          hour_of_day,
          transaction_count,
          avg_satisfaction * 100 as satisfaction_percentage,
          unique_customers,
          revenue,
          activity_intensity,
          satisfaction_level,
          time_period,
          activity_level,
          heatmap_timestamp
        FROM dbo.v_store_activity_heatmap
        WHERE 1=1
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      query += ' ORDER BY StoreID, hour_of_day';

      const result = await dbConnection.executeQuery(query, params);

      // Transform data for heatmap visualization
      const heatmapData = {};
      result.recordset.forEach(row => {
        if (!heatmapData[row.StoreID]) {
          heatmapData[row.StoreID] = {
            storeId: row.StoreID,
            hourlyData: []
          };
        }
        heatmapData[row.StoreID].hourlyData.push({
          hour: row.hour_of_day,
          transactions: row.transaction_count,
          satisfaction: row.satisfaction_percentage,
          customers: row.unique_customers,
          revenue: row.revenue,
          intensity: row.activity_intensity,
          level: row.activity_level,
          period: row.time_period
        });
      });

      res.json({
        success: true,
        data: Object.values(heatmapData),
        summary: {
          storeCount: Object.keys(heatmapData).length,
          totalDataPoints: result.recordset.length,
          timeRange: '24 hours'
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Activity heatmap error:', error);
      res.status(500).json({
        error: 'Failed to fetch activity heatmap data',
        details: error.message
      });
    }
  }
);

// GET /api/v1/monitoring/operational-alerts
// Get current operational alerts
router.get('/operational-alerts',
  [
    query('alertPeriodHours').optional().isInt({ min: 1, max: 24 }),
    query('priority').optional().isIn(['High', 'Medium', 'Low'])
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { alertPeriodHours = 2, priority } = req.query;

      const params = {
        alert_period_hours: { type: sql.Int, value: parseInt(alertPeriodHours) },
        min_transactions_for_alert: { type: sql.Int, value: 5 }
      };

      const result = await dbConnection.executeProcedure('dbo.sp_generate_operational_alerts', params);

      let alerts = result.recordset;

      if (priority) {
        alerts = alerts.filter(alert => alert.alert_priority === priority);
      }

      res.json({
        success: true,
        alerts: alerts,
        summary: {
          totalAlerts: alerts.length,
          highPriority: alerts.filter(a => a.alert_priority === 'High').length,
          mediumPriority: alerts.filter(a => a.alert_priority === 'Medium').length,
          lowPriority: alerts.filter(a => a.alert_priority === 'Low').length,
          periodHours: parseInt(alertPeriodHours)
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Operational alerts error:', error);
      res.status(500).json({
        error: 'Failed to fetch operational alerts',
        details: error.message
      });
    }
  }
);

// GET /api/v1/monitoring/performance-kpi
// Platform performance KPIs
router.get('/performance-kpi', async (req, res) => {
  try {
    const cacheKey = 'performance-kpi';
    const cached = cache.get(cacheKey);

    if (cached) {
      return res.json({ ...cached, cached: true });
    }

    const result = await dbConnection.executeQuery(`
      SELECT
        total_transactions_today,
        active_stores_today,
        unique_customers_today,
        total_revenue_today,
        avg_transaction_amount_today,
        customer_satisfaction_score,
        data_quality_score,
        facial_recognition_rate,
        conversation_engagement_rate,
        suki_relationship_score,
        transaction_growth_vs_yesterday,
        revenue_growth_vs_yesterday,
        transaction_growth_vs_last_week,
        satisfaction_status,
        activity_trend,
        kpi_date,
        last_updated
      FROM dbo.v_platform_performance_kpi
    `);

    const kpiData = {
      success: true,
      kpi: result.recordset[0] || {},
      timestamp: new Date().toISOString()
    };

    cache.set(cacheKey, kpiData, 300); // 5 minute cache for KPIs
    res.json(kpiData);

  } catch (error) {
    console.error('Performance KPI error:', error);
    res.status(500).json({
      error: 'Failed to fetch performance KPIs',
      details: error.message
    });
  }
});

// GET /api/v1/monitoring/system-status
// Overall system status summary
router.get('/system-status', async (req, res) => {
  try {
    const [healthResult, alertsResult] = await Promise.allSettled([
      dbConnection.executeQuery('SELECT platform_status, overall_platform_health_score FROM dbo.v_system_health_dashboard'),
      dbConnection.executeProcedure('dbo.sp_generate_operational_alerts', {
        alert_period_hours: { type: sql.Int, value: 1 },
        min_transactions_for_alert: { type: sql.Int, value: 5 }
      })
    ]);

    const systemStatus = {
      success: true,
      status: {
        overall: healthResult.status === 'fulfilled' ?
          healthResult.value.recordset[0]?.platform_status || 'Unknown' : 'Error',
        healthScore: healthResult.status === 'fulfilled' ?
          healthResult.value.recordset[0]?.overall_platform_health_score || 0 : 0,
        activeAlerts: alertsResult.status === 'fulfilled' ?
          alertsResult.value.recordset.length : 0,
        criticalAlerts: alertsResult.status === 'fulfilled' ?
          alertsResult.value.recordset.filter(a => a.alert_priority === 'High').length : 0
      },
      timestamp: new Date().toISOString()
    };

    res.json(systemStatus);

  } catch (error) {
    console.error('System status error:', error);
    res.status(500).json({
      error: 'Failed to fetch system status',
      details: error.message
    });
  }
});

module.exports = router;