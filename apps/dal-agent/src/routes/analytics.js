const express = require('express');
const { body, query, validationResult } = require('express-validator');
const NodeCache = require('node-cache');
const router = express.Router();
const dbConnection = require('../config/database');

// Cache for 5 minutes by default
const cache = new NodeCache({ stdTTL: parseInt(process.env.CACHE_TTL_SECONDS) || 300 });

// Validation middleware
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

// Cache middleware
const cacheMiddleware = (cacheDuration = 300) => {
  return (req, res, next) => {
    if (req.method !== 'GET') {
      return next();
    }

    const cacheKey = `${req.originalUrl}_${JSON.stringify(req.query)}`;
    const cachedResponse = cache.get(cacheKey);

    if (cachedResponse) {
      return res.json({
        ...cachedResponse,
        cached: true,
        cacheTimestamp: new Date(cachedResponse.timestamp)
      });
    }

    // Override res.json to cache successful responses
    const originalJson = res.json;
    res.json = function(body) {
      if (res.statusCode === 200) {
        cache.set(cacheKey, { ...body, timestamp: new Date().toISOString() }, cacheDuration);
      }
      return originalJson.call(this, body);
    };

    next();
  };
};

// GET /api/v1/analytics/ultra-enriched
// Ultra-enriched dataset with 150+ columns
router.get('/ultra-enriched',
  cacheMiddleware(300),
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }).withMessage('Store ID must be between 100-999'),
    query('startDate').optional().isISO8601().withMessage('Start date must be valid ISO date'),
    query('endDate').optional().isISO8601().withMessage('End date must be valid ISO date'),
    query('limit').optional().isInt({ min: 1, max: 1000 }).withMessage('Limit must be between 1-1000'),
    query('behaviorSegment').optional().isString().withMessage('Behavior segment must be string')
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, startDate, endDate, limit = 100, behaviorSegment } = req.query;

      let query = `
        SELECT TOP (@limit)
          canonical_tx_id,
          StoreID,
          FacialID,
          TransactionDate,
          amount,
          Age,
          Gender,
          customer_behavior_segment,
          suki_loyalty_index,
          tingi_preference_score,
          payday_correlation_score,
          emotional_satisfaction_index,
          politeness_score,
          language_detected,
          intent_classification,
          product_mentions,
          primary_category,
          detected_brands,
          item_count,
          neighborhood_persona
        FROM dbo.v_ultra_enriched_dataset
        WHERE 1=1
      `;

      const params = { limit: parseInt(limit) };

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      if (startDate) {
        query += ' AND TransactionDate >= @startDate';
        params.startDate = startDate;
      }

      if (endDate) {
        query += ' AND TransactionDate <= @endDate';
        params.endDate = endDate;
      }

      if (behaviorSegment) {
        query += ' AND customer_behavior_segment = @behaviorSegment';
        params.behaviorSegment = behaviorSegment;
      }

      query += ' ORDER BY TransactionDate DESC';

      const result = await dbConnection.executeQuery(query, params);

      res.json({
        success: true,
        data: result.recordset,
        metadata: {
          count: result.recordset.length,
          filters: { storeId, startDate, endDate, behaviorSegment },
          timestamp: new Date().toISOString()
        }
      });

    } catch (error) {
      console.error('Ultra-enriched dataset error:', error);
      res.status(500).json({
        error: 'Failed to fetch ultra-enriched dataset',
        details: error.message
      });
    }
  }
);

// GET /api/v1/analytics/conversation-intelligence
// Conversation intelligence insights
router.get('/conversation-intelligence',
  cacheMiddleware(600),
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('language').optional().isIn(['Filipino', 'English', 'Mixed', 'Silent']),
    query('minPoliteness').optional().isFloat({ min: 0, max: 1 }),
    query('startDate').optional().isISO8601(),
    query('endDate').optional().isISO8601()
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, language, minPoliteness, startDate, endDate } = req.query;

      let query = `
        SELECT
          language_detected,
          intent_classification,
          AVG(politeness_score) as avg_politeness,
          AVG(emotional_satisfaction_index) as avg_satisfaction,
          COUNT(*) as conversation_count,
          COUNT(DISTINCT StoreID) as store_count,
          STRING_AGG(DISTINCT product_mentions, ', ') as common_products
        FROM dbo.v_ultra_enriched_dataset
        WHERE conversation_processed = 1
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      if (language) {
        query += ' AND language_detected = @language';
        params.language = language;
      }

      if (minPoliteness) {
        query += ' AND politeness_score >= @minPoliteness';
        params.minPoliteness = parseFloat(minPoliteness);
      }

      if (startDate) {
        query += ' AND TransactionDate >= @startDate';
        params.startDate = startDate;
      }

      if (endDate) {
        query += ' AND TransactionDate <= @endDate';
        params.endDate = endDate;
      }

      query += `
        GROUP BY language_detected, intent_classification
        ORDER BY conversation_count DESC
      `;

      const result = await dbConnection.executeQuery(query, params);

      res.json({
        success: true,
        data: result.recordset,
        summary: {
          totalConversationGroups: result.recordset.length,
          filters: { storeId, language, minPoliteness, startDate, endDate }
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Conversation intelligence error:', error);
      res.status(500).json({
        error: 'Failed to fetch conversation intelligence data',
        details: error.message
      });
    }
  }
);

// GET /api/v1/analytics/cultural-patterns
// Filipino cultural patterns analysis
router.get('/cultural-patterns',
  cacheMiddleware(900),
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('culturalType').optional().isIn(['Traditional Sari-Sari', 'Relationship-Focused', 'Convenience-Focused', 'Transitional']),
    query('minSukiLoyalty').optional().isFloat({ min: 0, max: 1 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, culturalType, minSukiLoyalty } = req.query;

      let query = `
        SELECT
          StoreID,
          AVG(suki_loyalty_index) as avg_suki_loyalty,
          AVG(tingi_preference_score) as avg_tingi_preference,
          AVG(payday_correlation_score) as avg_payday_correlation,
          COUNT(CASE WHEN suki_loyalty_index >= 0.7 THEN 1 END) as strong_suki_customers,
          COUNT(CASE WHEN tingi_preference_score >= 0.7 THEN 1 END) as strong_tingi_customers,
          COUNT(CASE WHEN language_detected = 'Filipino' THEN 1 END) as filipino_conversations,
          COUNT(CASE WHEN language_detected = 'English' THEN 1 END) as english_conversations,
          COUNT(*) as total_transactions,
          CASE
            WHEN AVG(suki_loyalty_index) >= 0.6 AND AVG(tingi_preference_score) >= 0.6 THEN 'Traditional Sari-Sari'
            WHEN AVG(suki_loyalty_index) >= 0.6 THEN 'Relationship-Focused'
            WHEN AVG(tingi_preference_score) >= 0.6 THEN 'Convenience-Focused'
            ELSE 'Transitional'
          END as cultural_store_type
        FROM dbo.v_ultra_enriched_dataset
        WHERE StoreID IS NOT NULL
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      query += ' GROUP BY StoreID';

      if (culturalType) {
        query = `
          SELECT * FROM (${query}) as cultural_data
          WHERE cultural_store_type = @culturalType
        `;
        params.culturalType = culturalType;
      }

      if (minSukiLoyalty) {
        query = `
          SELECT * FROM (${query}) as cultural_data
          WHERE avg_suki_loyalty >= @minSukiLoyalty
        `;
        params.minSukiLoyalty = parseFloat(minSukiLoyalty);
      }

      query += ' ORDER BY avg_suki_loyalty DESC';

      const result = await dbConnection.executeQuery(query, params);

      res.json({
        success: true,
        data: result.recordset,
        insights: {
          storeCount: result.recordset.length,
          avgSukiLoyalty: result.recordset.reduce((sum, store) => sum + store.avg_suki_loyalty, 0) / result.recordset.length,
          avgTingiPreference: result.recordset.reduce((sum, store) => sum + store.avg_tingi_preference, 0) / result.recordset.length,
          culturalDistribution: result.recordset.reduce((dist, store) => {
            dist[store.cultural_store_type] = (dist[store.cultural_store_type] || 0) + 1;
            return dist;
          }, {})
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Cultural patterns error:', error);
      res.status(500).json({
        error: 'Failed to fetch cultural patterns data',
        details: error.message
      });
    }
  }
);

// POST /api/v1/analytics/daily-report
// Generate daily analytics report
router.post('/daily-report',
  [
    body('reportDate').optional().isISO8601().withMessage('Report date must be valid ISO date')
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { reportDate } = req.body;

      const params = {};
      if (reportDate) {
        params.report_date = { type: sql.Date, value: new Date(reportDate) };
      }

      const result = await dbConnection.executeProcedure('dbo.sp_generate_daily_analytics_report', params);

      res.json({
        success: true,
        report: result.recordset,
        metadata: {
          reportDate: reportDate || 'yesterday',
          generatedAt: new Date().toISOString(),
          metrics: result.recordset.length
        }
      });

    } catch (error) {
      console.error('Daily report error:', error);
      res.status(500).json({
        error: 'Failed to generate daily report',
        details: error.message
      });
    }
  }
);

// GET /api/v1/analytics/store-rankings
// Store performance rankings
router.get('/store-rankings',
  cacheMiddleware(600),
  [
    query('criteria').optional().isIn(['revenue', 'satisfaction', 'activity', 'suki_loyalty']),
    query('periodDays').optional().isInt({ min: 1, max: 365 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { criteria = 'revenue', periodDays = 7 } = req.query;

      const params = {
        ranking_period_days: { type: sql.Int, value: parseInt(periodDays) },
        ranking_criteria: { type: sql.VarChar, value: criteria }
      };

      const result = await dbConnection.executeProcedure('dbo.sp_store_performance_ranking', params);

      res.json({
        success: true,
        rankings: result.recordset,
        metadata: {
          criteria,
          periodDays: parseInt(periodDays),
          storeCount: result.recordset.length,
          generatedAt: new Date().toISOString()
        }
      });

    } catch (error) {
      console.error('Store rankings error:', error);
      res.status(500).json({
        error: 'Failed to fetch store rankings',
        details: error.message
      });
    }
  }
);

module.exports = router;