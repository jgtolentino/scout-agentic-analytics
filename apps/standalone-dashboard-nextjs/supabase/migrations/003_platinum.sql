-- Scout v7.1 Competitive Analysis - Platinum Tables (ML/Derived Data)
-- Migration: 003_platinum.sql

-- Journey transition probabilities (Markov chain analysis)
CREATE TABLE platinum_journey_transitions (
  transition_id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL REFERENCES dim_store(store_id),
  from_zone TEXT NOT NULL,
  to_zone TEXT NOT NULL,
  from_action TEXT NOT NULL,
  to_action TEXT NOT NULL,
  transition_probability DECIMAL(8,6) NOT NULL,
  confidence_interval_lower DECIMAL(8,6),
  confidence_interval_upper DECIMAL(8,6),
  sample_size INTEGER NOT NULL,
  avg_transition_time_seconds INTEGER,
  category_filter TEXT, -- For category-specific transitions
  customer_segment TEXT, -- For segment-specific transitions
  time_period TEXT, -- 'morning', 'afternoon', 'evening', 'night'
  analysis_date DATE NOT NULL,
  model_version TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT valid_probability CHECK (transition_probability BETWEEN 0 AND 1)
);

-- Customer lifetime value predictions
CREATE TABLE platinum_customer_ltv (
  customer_id TEXT PRIMARY KEY REFERENCES dim_customer(customer_id),
  predicted_ltv DECIMAL(12,2) NOT NULL,
  current_ltv DECIMAL(12,2) NOT NULL,
  ltv_percentile INTEGER CHECK (ltv_percentile BETWEEN 1 AND 100),
  risk_score DECIMAL(5,3) CHECK (risk_score BETWEEN 0 AND 1), -- Churn risk
  predicted_churn_date DATE,
  churn_probability DECIMAL(5,3) CHECK (churn_probability BETWEEN 0 AND 1),
  value_segment TEXT, -- 'Low', 'Medium', 'High', 'Premium'
  next_purchase_probability DECIMAL(5,3),
  predicted_next_purchase_date DATE,
  recommended_actions TEXT[],
  model_features JSONB, -- Features used in prediction
  prediction_confidence DECIMAL(5,3),
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Brand affinity and switching predictions
CREATE TABLE platinum_brand_affinity (
  affinity_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  brand TEXT NOT NULL,
  category TEXT NOT NULL,
  affinity_score DECIMAL(5,3) NOT NULL CHECK (affinity_score BETWEEN 0 AND 1),
  purchase_probability DECIMAL(5,3) CHECK (purchase_probability BETWEEN 0 AND 1),
  switch_likelihood DECIMAL(5,3) CHECK (switch_likelihood BETWEEN 0 AND 1),
  price_sensitivity DECIMAL(5,3) CHECK (price_sensitivity BETWEEN 0 AND 1),
  promotion_responsiveness DECIMAL(5,3) CHECK (promotion_responsiveness BETWEEN 0 AND 1),
  last_purchase_date DATE,
  purchase_frequency_score DECIMAL(5,3),
  recency_score DECIMAL(5,3),
  monetary_score DECIMAL(5,3),
  competitive_brands TEXT[], -- Brands customer is likely to switch to
  switching_triggers TEXT[], -- 'Price', 'Promotion', 'Quality', 'Availability'
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_customer_brand_category UNIQUE (customer_id, brand, category, analysis_date)
);

-- Market basket analysis and product recommendations
CREATE TABLE platinum_market_basket (
  basket_rule_id TEXT PRIMARY KEY,
  antecedent_skus TEXT[] NOT NULL, -- Products that predict consequent
  consequent_skus TEXT[] NOT NULL, -- Products that are predicted
  support DECIMAL(8,6) NOT NULL, -- Frequency of rule in transactions
  confidence DECIMAL(8,6) NOT NULL, -- Conditional probability
  lift DECIMAL(8,4) NOT NULL, -- Strength of association
  conviction DECIMAL(8,4), -- Measure of rule dependence
  antecedent_support DECIMAL(8,6),
  consequent_support DECIMAL(8,6),
  transaction_count INTEGER NOT NULL,
  store_id TEXT REFERENCES dim_store(store_id),
  customer_segment TEXT,
  time_filter TEXT, -- 'weekday', 'weekend', 'holiday'
  min_basket_value DECIMAL(10,2),
  max_basket_value DECIMAL(10,2),
  analysis_period_start DATE NOT NULL,
  analysis_period_end DATE NOT NULL,
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT valid_support CHECK (support BETWEEN 0 AND 1),
  CONSTRAINT valid_confidence CHECK (confidence BETWEEN 0 AND 1),
  CONSTRAINT valid_lift CHECK (lift > 0)
);

-- Customer journey clustering and personas
CREATE TABLE platinum_journey_clusters (
  cluster_id TEXT PRIMARY KEY,
  cluster_name TEXT NOT NULL,
  cluster_description TEXT,
  typical_journey_pattern TEXT[], -- Sequence of zones/actions
  avg_visit_duration INTEGER, -- Minutes
  avg_basket_value DECIMAL(10,2),
  avg_items_purchased DECIMAL(6,2),
  dominant_categories TEXT[],
  customer_count INTEGER,
  percentage_of_customers DECIMAL(5,2),
  journey_efficiency_score DECIMAL(5,3), -- How direct their paths are
  conversion_rate DECIMAL(5,3),
  satisfaction_score DECIMAL(3,2),
  seasonal_patterns JSONB, -- When this cluster is most active
  demographic_profile JSONB, -- Age, gender, income patterns
  behavioral_traits TEXT[], -- 'Impulsive', 'Planned', 'Browser', etc.
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Customer cluster membership
CREATE TABLE platinum_customer_clusters (
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  cluster_id TEXT NOT NULL REFERENCES platinum_journey_clusters(cluster_id),
  membership_probability DECIMAL(5,3) NOT NULL CHECK (membership_probability BETWEEN 0 AND 1),
  primary_cluster BOOLEAN DEFAULT false,
  analysis_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  
  PRIMARY KEY (customer_id, cluster_id, analysis_date)
);

-- Demand forecasting at SKU level
CREATE TABLE platinum_demand_forecast (
  forecast_id TEXT PRIMARY KEY,
  sku TEXT NOT NULL REFERENCES dim_product(sku),
  store_id TEXT NOT NULL REFERENCES dim_store(store_id),
  forecast_date DATE NOT NULL,
  forecast_horizon_days INTEGER NOT NULL, -- How many days ahead
  predicted_demand DECIMAL(10,2) NOT NULL,
  demand_lower_bound DECIMAL(10,2),
  demand_upper_bound DECIMAL(10,2),
  confidence_level DECIMAL(5,3) DEFAULT 0.95,
  seasonal_component DECIMAL(8,4),
  trend_component DECIMAL(8,4),
  promotional_impact DECIMAL(8,4),
  external_factors JSONB, -- Weather, events, etc.
  model_accuracy_mae DECIMAL(8,4), -- Mean Absolute Error
  model_accuracy_mape DECIMAL(8,4), -- Mean Absolute Percentage Error
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_forecast UNIQUE (sku, store_id, forecast_date, forecast_horizon_days, analysis_date)
);

-- Competitive intelligence and market share predictions
CREATE TABLE platinum_competitive_intel (
  intel_id TEXT PRIMARY KEY,
  brand TEXT NOT NULL,
  category TEXT NOT NULL,
  competitor_brand TEXT NOT NULL,
  market_share_current DECIMAL(5,3) CHECK (market_share_current BETWEEN 0 AND 1),
  market_share_predicted DECIMAL(5,3) CHECK (market_share_predicted BETWEEN 0 AND 1),
  share_change_probability DECIMAL(5,3) CHECK (share_change_probability BETWEEN 0 AND 1),
  competitive_pressure_score DECIMAL(5,3) CHECK (competitive_pressure_score BETWEEN 0 AND 1),
  price_competitiveness DECIMAL(5,3) CHECK (price_competitiveness BETWEEN 0 AND 1),
  promotion_intensity DECIMAL(5,3) CHECK (promotion_intensity BETWEEN 0 AND 1),
  availability_advantage DECIMAL(5,3) CHECK (availability_advantage BETWEEN 0 AND 1),
  customer_loyalty_score DECIMAL(5,3) CHECK (customer_loyalty_score BETWEEN 0 AND 1),
  switching_vulnerability DECIMAL(5,3) CHECK (switching_vulnerability BETWEEN 0 AND 1),
  recommended_strategies TEXT[],
  key_threats TEXT[],
  opportunities TEXT[],
  analysis_period_start DATE NOT NULL,
  analysis_period_end DATE NOT NULL,
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_brand_competitor UNIQUE (brand, category, competitor_brand, analysis_date)
);

-- Attribution modeling results
CREATE TABLE platinum_attribution (
  attribution_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  visit_id TEXT NOT NULL REFERENCES fact_visit(visit_id),
  conversion_value DECIMAL(10,2) NOT NULL,
  attribution_model TEXT NOT NULL, -- 'First-touch', 'Last-touch', 'Linear', 'Time-decay', 'Markov'
  touchpoint_contributions JSONB NOT NULL, -- Channel/campaign attributions
  primary_driver TEXT, -- Most influential touchpoint
  secondary_drivers TEXT[],
  time_to_conversion_hours INTEGER,
  touchpoint_count INTEGER,
  conversion_probability DECIMAL(5,3),
  incrementality_score DECIMAL(5,3), -- How much did marketing contribute
  organic_probability DECIMAL(5,3), -- Likelihood of organic conversion
  analysis_date DATE NOT NULL,
  model_version TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_customer_visit_model UNIQUE (customer_id, visit_id, attribution_model, analysis_date)
);

-- Performance indexes for platinum tables
CREATE INDEX idx_transitions_store_zones ON platinum_journey_transitions(store_id, from_zone, to_zone);
CREATE INDEX idx_transitions_probability ON platinum_journey_transitions(transition_probability DESC);
CREATE INDEX idx_transitions_analysis_date ON platinum_journey_transitions(analysis_date);

CREATE INDEX idx_ltv_predicted ON platinum_customer_ltv(predicted_ltv DESC);
CREATE INDEX idx_ltv_risk ON platinum_customer_ltv(risk_score DESC);
CREATE INDEX idx_ltv_segment ON platinum_customer_ltv(value_segment);
CREATE INDEX idx_ltv_analysis_date ON platinum_customer_ltv(analysis_date);

CREATE INDEX idx_affinity_customer ON platinum_brand_affinity(customer_id);
CREATE INDEX idx_affinity_brand ON platinum_brand_affinity(brand, category);
CREATE INDEX idx_affinity_score ON platinum_brand_affinity(affinity_score DESC);
CREATE INDEX idx_affinity_analysis_date ON platinum_brand_affinity(analysis_date);

CREATE INDEX idx_basket_confidence ON platinum_market_basket(confidence DESC);
CREATE INDEX idx_basket_lift ON platinum_market_basket(lift DESC);
CREATE INDEX idx_basket_store ON platinum_market_basket(store_id);
CREATE INDEX idx_basket_analysis_date ON platinum_market_basket(analysis_date);

CREATE INDEX idx_clusters_customer_count ON platinum_journey_clusters(customer_count DESC);
CREATE INDEX idx_clusters_analysis_date ON platinum_journey_clusters(analysis_date);

CREATE INDEX idx_customer_clusters_primary ON platinum_customer_clusters(customer_id, primary_cluster) WHERE primary_cluster = true;
CREATE INDEX idx_customer_clusters_analysis_date ON platinum_customer_clusters(analysis_date);

CREATE INDEX idx_forecast_sku_store ON platinum_demand_forecast(sku, store_id);
CREATE INDEX idx_forecast_date ON platinum_demand_forecast(forecast_date);
CREATE INDEX idx_forecast_analysis_date ON platinum_demand_forecast(analysis_date);

CREATE INDEX idx_competitive_brand ON platinum_competitive_intel(brand, category);
CREATE INDEX idx_competitive_pressure ON platinum_competitive_intel(competitive_pressure_score DESC);
CREATE INDEX idx_competitive_analysis_date ON platinum_competitive_intel(analysis_date);

CREATE INDEX idx_attribution_customer ON platinum_attribution(customer_id);
CREATE INDEX idx_attribution_model ON platinum_attribution(attribution_model);
CREATE INDEX idx_attribution_value ON platinum_attribution(conversion_value DESC);
CREATE INDEX idx_attribution_analysis_date ON platinum_attribution(analysis_date);

-- Materialized views for competitive analysis
CREATE MATERIALIZED VIEW mv_brand_switching_matrix AS
SELECT 
  bs.from_brand,
  bs.to_brand,
  bs.category,
  COUNT(*) AS switch_count,
  AVG(bs.days_between_purchases) AS avg_days_between,
  AVG(bs.price_sensitivity_factor) AS avg_price_sensitivity,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY bs.from_brand, bs.category) AS switch_percentage
FROM fact_brand_switch bs
WHERE bs.switch_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY bs.from_brand, bs.to_brand, bs.category
HAVING COUNT(*) >= 5; -- Minimum threshold for statistical significance

CREATE UNIQUE INDEX idx_switching_matrix ON mv_brand_switching_matrix(from_brand, to_brand, category);

CREATE MATERIALIZED VIEW mv_cohort_retention_summary AS
SELECT 
  fc.cohort_period,
  fc.cohort_type,
  fc.cohort_start_date,
  COUNT(DISTINCT fc.customer_id) AS cohort_size,
  SUM(fc.total_spend) AS cohort_revenue,
  AVG(fc.total_spend) AS avg_customer_value,
  SUM(CASE WHEN fc.is_retained THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS retention_rate,
  AVG(fc.periods_active) AS avg_periods_active,
  MAX(fc.periods_active) AS max_periods_active
FROM fact_customer_cohort fc
GROUP BY fc.cohort_period, fc.cohort_type, fc.cohort_start_date;

CREATE UNIQUE INDEX idx_cohort_summary ON mv_cohort_retention_summary(cohort_period, cohort_type);

-- Functions for platinum data processing
CREATE OR REPLACE FUNCTION calculate_brand_switching_matrix(
  analysis_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '90 days',
  analysis_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  from_brand TEXT,
  to_brand TEXT,
  category TEXT,
  switch_count BIGINT,
  switch_rate DECIMAL(8,4)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    bs.from_brand,
    bs.to_brand,
    bs.category,
    COUNT(*)::BIGINT AS switch_count,
    (COUNT(*) * 100.0 / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY bs.from_brand, bs.category), 0))::DECIMAL(8,4) AS switch_rate
  FROM fact_brand_switch bs
  WHERE bs.switch_date BETWEEN analysis_start_date AND analysis_end_date
  GROUP BY bs.from_brand, bs.to_brand, bs.category
  ORDER BY bs.from_brand, switch_count DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_platinum_views()
RETURNS VOID AS $$
BEGIN
  -- Refresh all platinum materialized views
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_brand_switching_matrix;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_cohort_retention_summary;
  
  -- Also refresh fact views
  PERFORM refresh_analytics_views();
END;
$$ LANGUAGE plpgsql;

-- Schedule view refreshes (requires pg_cron extension)
-- SELECT cron.schedule('refresh-platinum-views', '0 2 * * *', 'SELECT refresh_platinum_views();');

-- Comments
COMMENT ON TABLE platinum_journey_transitions IS 'ML-derived journey transition probabilities for path optimization';
COMMENT ON TABLE platinum_customer_ltv IS 'Customer lifetime value predictions and churn risk scoring';
COMMENT ON TABLE platinum_brand_affinity IS 'Brand affinity scores and switching likelihood predictions';
COMMENT ON TABLE platinum_market_basket IS 'Market basket analysis rules for cross-selling optimization';
COMMENT ON TABLE platinum_journey_clusters IS 'Customer journey behavior clusters and personas';
COMMENT ON TABLE platinum_customer_clusters IS 'Customer membership in journey behavior clusters';
COMMENT ON TABLE platinum_demand_forecast IS 'SKU-level demand forecasting with confidence intervals';
COMMENT ON TABLE platinum_competitive_intel IS 'Competitive intelligence and market share predictions';
COMMENT ON TABLE platinum_attribution IS 'Marketing attribution modeling results and incrementality';

COMMENT ON MATERIALIZED VIEW mv_brand_switching_matrix IS 'Aggregated brand switching patterns for competitive analysis';
COMMENT ON MATERIALIZED VIEW mv_cohort_retention_summary IS 'Cohort retention metrics summary for performance tracking';