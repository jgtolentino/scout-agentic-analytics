-- Scout v7.1 Competitive Analysis - Fact Tables
-- Migration: 002_facts.sql

-- Visit fact table - core customer journey events
CREATE TABLE fact_visit (
  visit_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  store_id TEXT NOT NULL REFERENCES dim_store(store_id),
  visit_date DATE NOT NULL REFERENCES dim_time(date_day),
  entry_timestamp TIMESTAMPTZ NOT NULL,
  exit_timestamp TIMESTAMPTZ,
  duration_minutes INTEGER,
  total_steps INTEGER DEFAULT 0,
  zones_visited INTEGER DEFAULT 0,
  items_picked INTEGER DEFAULT 0,
  items_purchased INTEGER DEFAULT 0,
  basket_value DECIMAL(10,2) DEFAULT 0,
  payment_method TEXT, -- 'Cash', 'Card', 'Digital', 'Mixed'
  visit_source TEXT, -- 'Walk-in', 'Online-to-Store', 'Promotion', 'Loyalty'
  weather TEXT, -- 'Sunny', 'Rainy', 'Cloudy'
  temperature_celsius INTEGER,
  is_weekend BOOLEAN,
  day_part TEXT, -- 'Morning', 'Afternoon', 'Evening', 'Night'
  campaign_id TEXT REFERENCES dim_campaign(campaign_id),
  referral_source TEXT,
  device_id TEXT, -- For digital tracking integration
  satisfaction_score INTEGER CHECK (satisfaction_score BETWEEN 1 AND 5),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Step fact table - detailed customer journey tracking
CREATE TABLE fact_step (
  step_id TEXT PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES fact_visit(visit_id),
  step_sequence INTEGER NOT NULL,
  zone_id TEXT NOT NULL REFERENCES dim_zone(zone_id),
  step_timestamp TIMESTAMPTZ NOT NULL,
  action_type TEXT NOT NULL, -- 'Enter', 'Browse', 'Pickup', 'Putback', 'Queue', 'Pay', 'Exit'
  duration_seconds INTEGER,
  sku TEXT REFERENCES dim_product(sku), -- NULL for non-product actions
  quantity INTEGER DEFAULT 0,
  interaction_method TEXT, -- 'Manual', 'Scan', 'Voice', 'App'
  dwell_time_seconds INTEGER,
  movement_pattern TEXT, -- 'Direct', 'Browse', 'Search', 'Wander'
  next_zone_id TEXT REFERENCES dim_zone(zone_id),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_visit_step UNIQUE (visit_id, step_sequence)
);

-- Transaction fact table - purchase events
CREATE TABLE fact_transaction (
  transaction_id TEXT PRIMARY KEY,
  visit_id TEXT NOT NULL REFERENCES fact_visit(visit_id),
  line_item_id TEXT NOT NULL,
  sku TEXT NOT NULL REFERENCES dim_product(sku),
  transaction_timestamp TIMESTAMPTZ NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  line_total DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  promotion_applied TEXT,
  campaign_id TEXT REFERENCES dim_campaign(campaign_id),
  loyalty_points_earned INTEGER DEFAULT 0,
  loyalty_points_redeemed INTEGER DEFAULT 0,
  is_return BOOLEAN DEFAULT false,
  return_reason TEXT,
  cost_of_goods DECIMAL(10,2),
  gross_margin DECIMAL(10,2),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_transaction_line UNIQUE (transaction_id, line_item_id)
);

-- Customer cohort fact table - for cohort analysis
CREATE TABLE fact_customer_cohort (
  cohort_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  cohort_period TEXT NOT NULL, -- 'july_2024', 'august_2024', etc.
  cohort_type TEXT NOT NULL, -- 'monthly', 'weekly', 'quarterly'
  first_purchase_date DATE NOT NULL,
  cohort_start_date DATE NOT NULL,
  periods_active INTEGER DEFAULT 1,
  total_purchases INTEGER DEFAULT 1,
  total_spend DECIMAL(12,2) DEFAULT 0,
  last_activity_date DATE,
  is_retained BOOLEAN DEFAULT true,
  churn_date DATE,
  churn_reason TEXT,
  lifetime_value DECIMAL(12,2),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  CONSTRAINT unique_customer_cohort UNIQUE (customer_id, cohort_period, cohort_type)
);

-- Brand switching fact table - for competitive analysis
CREATE TABLE fact_brand_switch (
  switch_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  from_brand TEXT NOT NULL,
  to_brand TEXT NOT NULL,
  category TEXT NOT NULL,
  switch_date DATE NOT NULL REFERENCES dim_time(date_day),
  from_visit_id TEXT REFERENCES fact_visit(visit_id),
  to_visit_id TEXT NOT NULL REFERENCES fact_visit(visit_id),
  days_between_purchases INTEGER,
  from_spend DECIMAL(10,2),
  to_spend DECIMAL(10,2),
  price_sensitivity_factor DECIMAL(5,3), -- How much price influenced the switch
  promotion_influenced BOOLEAN DEFAULT false,
  switch_type TEXT, -- 'Permanent', 'Temporary', 'Occasional'
  confidence_score DECIMAL(3,2), -- ML model confidence in switch detection
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Marketing touchpoint fact table
CREATE TABLE fact_marketing_touch (
  touch_id TEXT PRIMARY KEY,
  customer_id TEXT REFERENCES dim_customer(customer_id),
  campaign_id TEXT NOT NULL REFERENCES dim_campaign(campaign_id),
  visit_id TEXT REFERENCES fact_visit(visit_id),
  touch_timestamp TIMESTAMPTZ NOT NULL,
  channel TEXT NOT NULL, -- 'Email', 'SMS', 'Push', 'Display', 'Social', 'In-Store'
  message_type TEXT, -- 'Promotional', 'Educational', 'Retention', 'Winback'
  content_variant TEXT,
  was_clicked BOOLEAN DEFAULT false,
  was_converted BOOLEAN DEFAULT false,
  attribution_weight DECIMAL(3,2) DEFAULT 0, -- For attribution modeling
  cost DECIMAL(8,2),
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance optimization
-- Visit fact indexes
CREATE INDEX idx_visit_customer ON fact_visit(customer_id);
CREATE INDEX idx_visit_store ON fact_visit(store_id);
CREATE INDEX idx_visit_date ON fact_visit(visit_date);
CREATE INDEX idx_visit_timestamp ON fact_visit(entry_timestamp);
CREATE INDEX idx_visit_composite ON fact_visit(store_id, visit_date, customer_id);
CREATE INDEX idx_visit_source ON fact_visit(visit_source);
CREATE INDEX idx_visit_daypart ON fact_visit(day_part);

-- Step fact indexes
CREATE INDEX idx_step_visit ON fact_step(visit_id);
CREATE INDEX idx_step_zone ON fact_step(zone_id);
CREATE INDEX idx_step_timestamp ON fact_step(step_timestamp);
CREATE INDEX idx_step_action ON fact_step(action_type);
CREATE INDEX idx_step_sku ON fact_step(sku) WHERE sku IS NOT NULL;
CREATE INDEX idx_step_sequence ON fact_step(visit_id, step_sequence);

-- Transaction fact indexes
CREATE INDEX idx_transaction_visit ON fact_transaction(visit_id);
CREATE INDEX idx_transaction_sku ON fact_transaction(sku);
CREATE INDEX idx_transaction_timestamp ON fact_transaction(transaction_timestamp);
CREATE INDEX idx_transaction_date ON fact_transaction(DATE(transaction_timestamp));
CREATE INDEX idx_transaction_value ON fact_transaction(line_total);
CREATE INDEX idx_transaction_campaign ON fact_transaction(campaign_id) WHERE campaign_id IS NOT NULL;

-- Cohort fact indexes
CREATE INDEX idx_cohort_customer ON fact_customer_cohort(customer_id);
CREATE INDEX idx_cohort_period ON fact_customer_cohort(cohort_period);
CREATE INDEX idx_cohort_type ON fact_customer_cohort(cohort_type);
CREATE INDEX idx_cohort_start_date ON fact_customer_cohort(cohort_start_date);
CREATE INDEX idx_cohort_retained ON fact_customer_cohort(is_retained);

-- Brand switching indexes
CREATE INDEX idx_switch_customer ON fact_brand_switch(customer_id);
CREATE INDEX idx_switch_brands ON fact_brand_switch(from_brand, to_brand);
CREATE INDEX idx_switch_category ON fact_brand_switch(category);
CREATE INDEX idx_switch_date ON fact_brand_switch(switch_date);
CREATE INDEX idx_switch_type ON fact_brand_switch(switch_type);

-- Marketing touch indexes
CREATE INDEX idx_touch_customer ON fact_marketing_touch(customer_id);
CREATE INDEX idx_touch_campaign ON fact_marketing_touch(campaign_id);
CREATE INDEX idx_touch_timestamp ON fact_marketing_touch(touch_timestamp);
CREATE INDEX idx_touch_channel ON fact_marketing_touch(channel);
CREATE INDEX idx_touch_converted ON fact_marketing_touch(was_converted) WHERE was_converted = true;

-- Partitioning for large fact tables (if needed)
-- This can be uncommented for high-volume production environments

-- -- Partition fact_visit by month
-- CREATE TABLE fact_visit_y2024m01 PARTITION OF fact_visit
--     FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
-- CREATE TABLE fact_visit_y2024m02 PARTITION OF fact_visit
--     FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
-- -- Continue for other months...

-- Materialized views for common aggregations
CREATE MATERIALIZED VIEW mv_daily_store_metrics AS
SELECT 
  store_id,
  visit_date,
  COUNT(DISTINCT visit_id) AS total_visits,
  COUNT(DISTINCT customer_id) AS unique_customers,
  AVG(duration_minutes) AS avg_duration_minutes,
  AVG(basket_value) AS avg_basket_value,
  SUM(basket_value) AS total_revenue,
  AVG(satisfaction_score) AS avg_satisfaction
FROM fact_visit
WHERE exit_timestamp IS NOT NULL
GROUP BY store_id, visit_date;

CREATE UNIQUE INDEX idx_daily_store_metrics ON mv_daily_store_metrics(store_id, visit_date);

CREATE MATERIALIZED VIEW mv_monthly_brand_performance AS
SELECT 
  p.brand,
  p.category,
  DATE_TRUNC('month', t.transaction_timestamp) AS month,
  COUNT(DISTINCT t.visit_id) AS transactions,
  SUM(t.quantity) AS units_sold,
  SUM(t.line_total) AS revenue,
  AVG(t.unit_price) AS avg_price,
  COUNT(DISTINCT v.customer_id) AS unique_customers
FROM fact_transaction t
JOIN dim_product p ON t.sku = p.sku
JOIN fact_visit v ON t.visit_id = v.visit_id
GROUP BY p.brand, p.category, DATE_TRUNC('month', t.transaction_timestamp);

CREATE UNIQUE INDEX idx_monthly_brand_perf ON mv_monthly_brand_performance(brand, category, month);

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION refresh_analytics_views()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_store_metrics;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_brand_performance;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE fact_visit IS 'Customer visit events with journey metadata';
COMMENT ON TABLE fact_step IS 'Detailed customer journey steps within visits';
COMMENT ON TABLE fact_transaction IS 'Purchase transaction line items';
COMMENT ON TABLE fact_customer_cohort IS 'Customer cohort membership and retention data';
COMMENT ON TABLE fact_brand_switch IS 'Brand switching behavior for competitive analysis';
COMMENT ON TABLE fact_marketing_touch IS 'Marketing campaign touchpoints and attribution';

COMMENT ON MATERIALIZED VIEW mv_daily_store_metrics IS 'Daily aggregated store performance metrics';
COMMENT ON MATERIALIZED VIEW mv_monthly_brand_performance IS 'Monthly brand performance aggregations';