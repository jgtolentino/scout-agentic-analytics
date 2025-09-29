const express = require('express');
const { query, body, validationResult } = require('express-validator');
const NodeCache = require('node-cache');
const router = express.Router();
const dbConnection = require('../config/database');

// Cache for cultural data (longer TTL since cultural patterns change slowly)
const cache = new NodeCache({ stdTTL: 900 }); // 15 minutes

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

// GET /api/v1/cultural/store-patterns
// Filipino cultural patterns by store
router.get('/store-patterns',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('culturalType').optional().isIn([
      'Traditional Sari-Sari',
      'Relationship-Focused Store',
      'Convenience-Focused Store',
      'Transitional Store'
    ])
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, culturalType } = req.query;

      let query = `
        SELECT
          StoreID,
          avg_suki_loyalty * 100 as suki_loyalty_percentage,
          strong_suki_customers,
          developing_suki_customers,
          transactional_customers,
          avg_tingi_preference * 100 as tingi_preference_percentage,
          strong_tingi_customers,
          avg_payday_correlation * 100 as payday_correlation_percentage,
          payday_dependent_customers,
          filipino_transactions,
          english_transactions,
          mixed_language_transactions,
          silent_transactions,
          avg_politeness * 100 as politeness_percentage,
          avg_satisfaction * 100 as satisfaction_percentage,
          cultural_store_type,
          communication_pattern,
          total_transactions,
          unique_customers
        FROM dbo.v_store_cultural_patterns
        WHERE 1=1
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      if (culturalType) {
        query += ' AND cultural_store_type = @culturalType';
        params.culturalType = culturalType;
      }

      query += ' ORDER BY suki_loyalty_percentage DESC';

      const result = await dbConnection.executeQuery(query, params);

      // Calculate insights
      const insights = {
        totalStores: result.recordset.length,
        culturalDistribution: {},
        communicationDistribution: {},
        avgMetrics: {
          sukiLoyalty: 0,
          tingiPreference: 0,
          paydayCorrelation: 0,
          satisfaction: 0
        }
      };

      result.recordset.forEach(store => {
        // Cultural distribution
        insights.culturalDistribution[store.cultural_store_type] =
          (insights.culturalDistribution[store.cultural_store_type] || 0) + 1;

        // Communication distribution
        insights.communicationDistribution[store.communication_pattern] =
          (insights.communicationDistribution[store.communication_pattern] || 0) + 1;

        // Average metrics
        insights.avgMetrics.sukiLoyalty += store.suki_loyalty_percentage;
        insights.avgMetrics.tingiPreference += store.tingi_preference_percentage;
        insights.avgMetrics.paydayCorrelation += store.payday_correlation_percentage;
        insights.avgMetrics.satisfaction += store.satisfaction_percentage;
      });

      // Calculate averages
      if (result.recordset.length > 0) {
        Object.keys(insights.avgMetrics).forEach(key => {
          insights.avgMetrics[key] = insights.avgMetrics[key] / result.recordset.length;
        });
      }

      res.json({
        success: true,
        data: result.recordset,
        insights,
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Store cultural patterns error:', error);
      res.status(500).json({
        error: 'Failed to fetch store cultural patterns',
        details: error.message
      });
    }
  }
);

// GET /api/v1/cultural/customer-personas
// Filipino customer personas from NCR clustering
router.get('/customer-personas',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('persona').optional().isString(),
    query('minTransactions').optional().isInt({ min: 1, max: 100 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, persona, minTransactions = 5 } = req.query;

      let query = `
        SELECT
          customer_behavior_segment as persona,
          neighborhood_persona,
          AVG(suki_loyalty_index) * 100 as avg_suki_loyalty,
          AVG(tingi_preference_score) * 100 as avg_tingi_preference,
          AVG(payday_correlation_score) * 100 as avg_payday_correlation,
          AVG(emotional_satisfaction_index) * 100 as avg_satisfaction,
          AVG(politeness_score) * 100 as avg_politeness,
          COUNT(*) as transaction_count,
          COUNT(DISTINCT FacialID) as customer_count,
          COUNT(DISTINCT StoreID) as store_count,
          AVG(amount) as avg_spending,
          SUM(amount) as total_spending,
          AVG(Age) as avg_age,
          MODE() WITHIN GROUP (ORDER BY Gender) as primary_gender,
          MODE() WITHIN GROUP (ORDER BY language_detected) as preferred_language
        FROM dbo.v_ultra_enriched_dataset
        WHERE customer_behavior_segment IS NOT NULL
          AND FacialID IS NOT NULL
      `;

      const params = {};

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      if (persona) {
        query += ' AND customer_behavior_segment LIKE @persona';
        params.persona = `%${persona}%`;
      }

      query += `
        GROUP BY customer_behavior_segment, neighborhood_persona
        HAVING COUNT(*) >= @minTransactions
        ORDER BY transaction_count DESC
      `;

      params.minTransactions = parseInt(minTransactions);

      const result = await dbConnection.executeQuery(query, params);

      // Add cultural insights for each persona
      const personasWithInsights = result.recordset.map(persona => ({
        ...persona,
        culturalInsights: {
          sukiRelationshipStrength: persona.avg_suki_loyalty >= 70 ? 'Strong' :
            persona.avg_suki_loyalty >= 40 ? 'Moderate' : 'Weak',
          tingiCultureAdaptation: persona.avg_tingi_preference >= 70 ? 'High' :
            persona.avg_tingi_preference >= 40 ? 'Moderate' : 'Low',
          paydayDependency: persona.avg_payday_correlation >= 60 ? 'High' :
            persona.avg_payday_correlation >= 30 ? 'Moderate' : 'Low',
          communicationStyle: persona.preferred_language === 'Filipino' ? 'Traditional' :
            persona.preferred_language === 'English' ? 'Modern' :
            persona.preferred_language === 'Silent' ? 'Reserved' : 'Mixed'
        },
        recommendations: generatePersonaRecommendations(persona)
      }));

      res.json({
        success: true,
        personas: personasWithInsights,
        summary: {
          totalPersonas: personasWithInsights.length,
          totalCustomers: personasWithInsights.reduce((sum, p) => sum + p.customer_count, 0),
          totalTransactions: personasWithInsights.reduce((sum, p) => sum + p.transaction_count, 0),
          avgSatisfaction: personasWithInsights.reduce((sum, p) => sum + p.avg_satisfaction, 0) / personasWithInsights.length
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Customer personas error:', error);
      res.status(500).json({
        error: 'Failed to fetch customer personas',
        details: error.message
      });
    }
  }
);

// POST /api/v1/cultural/analysis
// Generate cultural insights analysis
router.post('/analysis',
  [
    body('analysisPeriodDays').optional().isInt({ min: 7, max: 365 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { analysisPeriodDays = 30 } = req.body;

      const params = {
        analysis_period_days: { type: sql.Int, value: analysisPeriodDays }
      };

      const result = await dbConnection.executeProcedure('dbo.sp_cultural_insights_analysis', params);

      res.json({
        success: true,
        analysis: result.recordset,
        metadata: {
          analysisPeriod: `${analysisPeriodDays} days`,
          generatedAt: new Date().toISOString(),
          storeGroups: result.recordset.length
        }
      });

    } catch (error) {
      console.error('Cultural analysis error:', error);
      res.status(500).json({
        error: 'Failed to generate cultural analysis',
        details: error.message
      });
    }
  }
);

// GET /api/v1/cultural/language-patterns
// Language and communication patterns
router.get('/language-patterns',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('timeframe').optional().isIn(['day', 'week', 'month'])
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, timeframe = 'week' } = req.query;

      const daysBack = timeframe === 'day' ? 1 : timeframe === 'week' ? 7 : 30;

      let query = `
        SELECT
          language_detected,
          COUNT(*) as conversation_count,
          COUNT(DISTINCT StoreID) as store_count,
          COUNT(DISTINCT FacialID) as customer_count,
          AVG(politeness_score) * 100 as avg_politeness,
          AVG(emotional_satisfaction_index) * 100 as avg_satisfaction,
          AVG(suki_loyalty_index) * 100 as avg_suki_loyalty,
          STRING_AGG(DISTINCT intent_classification, ', ') as common_intents
        FROM dbo.v_ultra_enriched_dataset
        WHERE TransactionDate >= DATEADD(DAY, -@daysBack, GETDATE())
          AND language_detected IS NOT NULL
      `;

      const params = { daysBack };

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      query += `
        GROUP BY language_detected
        ORDER BY conversation_count DESC
      `;

      const result = await dbConnection.executeQuery(query, params);

      // Calculate percentages
      const totalConversations = result.recordset.reduce((sum, lang) => sum + lang.conversation_count, 0);

      const languageData = result.recordset.map(lang => ({
        ...lang,
        percentage: (lang.conversation_count / totalConversations * 100).toFixed(1),
        culturalSignificance: getCulturalSignificance(lang.language_detected, lang.avg_politeness, lang.avg_suki_loyalty)
      }));

      res.json({
        success: true,
        data: languageData,
        insights: {
          totalConversations,
          timeframeDays: daysBack,
          dominantLanguage: languageData[0]?.language_detected || 'Unknown',
          silentPercentage: languageData.find(l => l.language_detected === 'Silent')?.percentage || 0,
          filipinoAdaptation: languageData.find(l => l.language_detected === 'Filipino')?.percentage || 0
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Language patterns error:', error);
      res.status(500).json({
        error: 'Failed to fetch language patterns',
        details: error.message
      });
    }
  }
);

// GET /api/v1/cultural/suki-relationships
// Suki relationship analysis
router.get('/suki-relationships',
  [
    query('storeId').optional().isInt({ min: 100, max: 999 }),
    query('minLoyalty').optional().isFloat({ min: 0, max: 1 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { storeId, minLoyalty = 0.4 } = req.query;

      let query = `
        SELECT
          StoreID,
          FacialID,
          suki_loyalty_index,
          COUNT(*) as visit_frequency,
          AVG(amount) as avg_spending,
          SUM(amount) as total_spending,
          MIN(TransactionDate) as first_visit,
          MAX(TransactionDate) as last_visit,
          DATEDIFF(DAY, MIN(TransactionDate), MAX(TransactionDate)) as relationship_days,
          AVG(emotional_satisfaction_index) * 100 as avg_satisfaction,
          AVG(politeness_score) * 100 as avg_politeness,
          MODE() WITHIN GROUP (ORDER BY language_detected) as preferred_language,
          customer_behavior_segment as persona
        FROM dbo.v_ultra_enriched_dataset
        WHERE suki_loyalty_index >= @minLoyalty
          AND FacialID IS NOT NULL
      `;

      const params = { minLoyalty: parseFloat(minLoyalty) };

      if (storeId) {
        query += ' AND StoreID = @storeId';
        params.storeId = parseInt(storeId);
      }

      query += `
        GROUP BY StoreID, FacialID, suki_loyalty_index, customer_behavior_segment
        HAVING COUNT(*) >= 3
        ORDER BY suki_loyalty_index DESC, visit_frequency DESC
      `;

      const result = await dbConnection.executeQuery(query, params);

      // Analyze suki relationship patterns
      const sukiAnalysis = {
        strongSuki: result.recordset.filter(r => r.suki_loyalty_index >= 0.7),
        moderateSuki: result.recordset.filter(r => r.suki_loyalty_index >= 0.4 && r.suki_loyalty_index < 0.7),
        totalRelationships: result.recordset.length,
        avgRelationshipDays: result.recordset.reduce((sum, r) => sum + r.relationship_days, 0) / result.recordset.length,
        avgVisitFrequency: result.recordset.reduce((sum, r) => sum + r.visit_frequency, 0) / result.recordset.length
      };

      res.json({
        success: true,
        relationships: result.recordset,
        analysis: {
          strongSukiCount: sukiAnalysis.strongSuki.length,
          moderateSukiCount: sukiAnalysis.moderateSuki.length,
          totalSukiRelationships: sukiAnalysis.totalRelationships,
          avgRelationshipDuration: Math.round(sukiAnalysis.avgRelationshipDays),
          avgVisitFrequency: Math.round(sukiAnalysis.avgVisitFrequency),
          strongSukiAvgSpending: sukiAnalysis.strongSuki.reduce((sum, r) => sum + r.avg_spending, 0) / sukiAnalysis.strongSuki.length || 0,
          moderateSukiAvgSpending: sukiAnalysis.moderateSuki.reduce((sum, r) => sum + r.avg_spending, 0) / sukiAnalysis.moderateSuki.length || 0
        },
        culturalInsights: {
          traditionPreservation: sukiAnalysis.strongSuki.length > sukiAnalysis.moderateSuki.length ?
            'Strong traditional sari-sari culture' : 'Evolving customer relationships',
          communityStrength: sukiAnalysis.totalRelationships > 50 ? 'Strong community ties' : 'Developing community',
          loyaltyRewards: 'Implement suki recognition programs and special privileges'
        },
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      console.error('Suki relationships error:', error);
      res.status(500).json({
        error: 'Failed to fetch suki relationships data',
        details: error.message
      });
    }
  }
);

// Helper functions
function generatePersonaRecommendations(persona) {
  const recommendations = [];

  if (persona.avg_suki_loyalty >= 70) {
    recommendations.push('Maintain personal relationships with loyalty rewards and recognition');
  }

  if (persona.avg_tingi_preference >= 70) {
    recommendations.push('Offer small quantity packages and flexible payment options');
  }

  if (persona.avg_payday_correlation >= 60) {
    recommendations.push('Plan promotions around 15th and 30th of each month');
  }

  if (persona.preferred_language === 'Filipino') {
    recommendations.push('Train staff in Filipino communication and cultural sensitivity');
  }

  if (persona.avg_satisfaction < 50) {
    recommendations.push('Focus on service quality improvements and staff training');
  }

  return recommendations;
}

function getCulturalSignificance(language, politeness, sukiLoyalty) {
  if (language === 'Filipino') {
    return {
      significance: 'High',
      description: 'Traditional Filipino culture preserved',
      recommendation: 'Maintain Filipino-first approach with cultural sensitivity'
    };
  } else if (language === 'English') {
    return {
      significance: 'Moderate',
      description: 'Modern urban customer preference',
      recommendation: 'Balance English service with Filipino warmth'
    };
  } else if (language === 'Silent') {
    return {
      significance: 'Attention Needed',
      description: 'Customers may be uncomfortable or rushed',
      recommendation: 'Train staff to engage customers warmly and patiently'
    };
  }
  return {
    significance: 'Unknown',
    description: 'Mixed communication patterns',
    recommendation: 'Analyze individual customer preferences'
  };
}

module.exports = router;