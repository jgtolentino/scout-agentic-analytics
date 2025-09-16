-- Scout v7.1 Competitive Analysis - Dimension Tables
-- Migration: 001_dimensions.sql

-- Store dimension with hierarchical location data
CREATE TABLE dim_store (
  store_id TEXT PRIMARY KEY,
  store_name TEXT NOT NULL,
  store_type TEXT NOT NULL, -- 'Mall', 'Convenience', 'Supermarket', 'Hypermarket'
  size_category TEXT, -- 'Small', 'Medium', 'Large'
  region TEXT NOT NULL,
  province TEXT,
  city TEXT,
  address TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  opening_date DATE,
  floor_area_sqm INTEGER,
  parking_spaces INTEGER,
  is_active BOOLEAN DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Product dimension with hierarchical categorization
CREATE TABLE dim_product (
  sku TEXT PRIMARY KEY,
  product_name TEXT NOT NULL,
  brand TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  product_type TEXT,
  package_size TEXT,
  unit_of_measure TEXT,
  barcode TEXT,
  supplier TEXT,
  cost_price DECIMAL(10,2),
  retail_price DECIMAL(10,2),
  weight_grams INTEGER,
  is_active BOOLEAN DEFAULT true,
  launch_date DATE,
  discontinue_date DATE,
  metadata JSONB, -- For extensible properties
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Customer dimension with segmentation data
CREATE TABLE dim_customer (
  customer_id TEXT PRIMARY KEY,
  customer_type TEXT, -- 'Individual', 'Business'
  segment TEXT, -- 'New', 'Returning', 'Loyal', 'Whale'
  loyalty_tier TEXT, -- 'Bronze', 'Silver', 'Gold', 'Platinum'
  first_visit_date DATE,
  registration_date DATE,
  birth_date DATE,
  gender TEXT,
  age_bracket TEXT, -- '18-24', '25-34', etc.
  income_bracket TEXT,
  education_level TEXT,
  preferred_store TEXT REFERENCES dim_store(store_id),
  preferred_categories TEXT[],
  is_active BOOLEAN DEFAULT true,
  lifetime_value DECIMAL(12,2),
  total_visits INTEGER DEFAULT 0,
  total_spend DECIMAL(12,2) DEFAULT 0,
  avg_basket_value DECIMAL(10,2),
  last_visit_date DATE,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Time dimension for efficient time-based queries
CREATE TABLE dim_time (
  date_day DATE PRIMARY KEY,
  year INTEGER NOT NULL,
  quarter INTEGER NOT NULL,
  month INTEGER NOT NULL,
  month_name TEXT NOT NULL,
  week INTEGER NOT NULL,
  day_of_year INTEGER NOT NULL,
  day_of_month INTEGER NOT NULL,
  day_of_week INTEGER NOT NULL, -- 1=Monday, 7=Sunday
  day_name TEXT NOT NULL,
  is_weekend BOOLEAN NOT NULL,
  is_holiday BOOLEAN DEFAULT false,
  holiday_name TEXT,
  season TEXT, -- 'Spring', 'Summer', 'Fall', 'Winter'
  fiscal_quarter INTEGER,
  fiscal_year INTEGER
);

-- Campaign dimension for promotional analysis
CREATE TABLE dim_campaign (
  campaign_id TEXT PRIMARY KEY,
  campaign_name TEXT NOT NULL,
  campaign_type TEXT, -- 'Discount', 'BOGO', 'Seasonal', 'Brand'
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  target_category TEXT,
  target_brand TEXT,
  discount_percentage DECIMAL(5,2),
  description TEXT,
  budget DECIMAL(12,2),
  is_active BOOLEAN DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Zone dimension for in-store location tracking
CREATE TABLE dim_zone (
  zone_id TEXT PRIMARY KEY,
  store_id TEXT NOT NULL REFERENCES dim_store(store_id),
  zone_name TEXT NOT NULL,
  zone_type TEXT, -- 'Entrance', 'Aisle', 'Checkout', 'Service', 'Storage'
  primary_category TEXT, -- Main product category for this zone
  floor_level INTEGER DEFAULT 1,
  zone_area_sqm DECIMAL(8,2),
  parent_zone_id TEXT REFERENCES dim_zone(zone_id),
  is_active BOOLEAN DEFAULT true,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX idx_store_region ON dim_store(region);
CREATE INDEX idx_store_city ON dim_store(city);
CREATE INDEX idx_store_type ON dim_store(store_type);
CREATE INDEX idx_store_active ON dim_store(is_active) WHERE is_active = true;

CREATE INDEX idx_product_brand ON dim_product(brand);
CREATE INDEX idx_product_category ON dim_product(category);
CREATE INDEX idx_product_active ON dim_product(is_active) WHERE is_active = true;
CREATE INDEX idx_product_brand_category ON dim_product(brand, category);

CREATE INDEX idx_customer_segment ON dim_customer(segment);
CREATE INDEX idx_customer_tier ON dim_customer(loyalty_tier);
CREATE INDEX idx_customer_first_visit ON dim_customer(first_visit_date);
CREATE INDEX idx_customer_active ON dim_customer(is_active) WHERE is_active = true;

CREATE INDEX idx_time_year_month ON dim_time(year, month);
CREATE INDEX idx_time_quarter ON dim_time(year, quarter);
CREATE INDEX idx_time_week ON dim_time(year, week);
CREATE INDEX idx_time_dow ON dim_time(day_of_week);
CREATE INDEX idx_time_weekend ON dim_time(is_weekend);

CREATE INDEX idx_campaign_dates ON dim_campaign(start_date, end_date);
CREATE INDEX idx_campaign_type ON dim_campaign(campaign_type);
CREATE INDEX idx_campaign_brand ON dim_campaign(target_brand);

CREATE INDEX idx_zone_store ON dim_zone(store_id);
CREATE INDEX idx_zone_type ON dim_zone(zone_type);
CREATE INDEX idx_zone_category ON dim_zone(primary_category);

-- Views for hierarchical queries
CREATE VIEW v_store_hierarchy AS
SELECT 
  store_id,
  store_name,
  region,
  province,
  city,
  region || ' > ' || COALESCE(province, 'N/A') || ' > ' || COALESCE(city, 'N/A') AS location_path
FROM dim_store
WHERE is_active = true;

CREATE VIEW v_product_hierarchy AS
SELECT 
  sku,
  product_name,
  brand,
  category,
  subcategory,
  category || ' > ' || brand || ' > ' || product_name AS product_path
FROM dim_product
WHERE is_active = true;

-- Function to populate dim_time
CREATE OR REPLACE FUNCTION populate_dim_time(start_date DATE, end_date DATE)
RETURNS VOID AS $$
DECLARE
  current_date DATE := start_date;
BEGIN
  WHILE current_date <= end_date LOOP
    INSERT INTO dim_time (
      date_day, year, quarter, month, month_name, week, day_of_year,
      day_of_month, day_of_week, day_name, is_weekend
    ) VALUES (
      current_date,
      EXTRACT(YEAR FROM current_date),
      EXTRACT(QUARTER FROM current_date),
      EXTRACT(MONTH FROM current_date),
      TO_CHAR(current_date, 'Month'),
      EXTRACT(WEEK FROM current_date),
      EXTRACT(DOY FROM current_date),
      EXTRACT(DAY FROM current_date),
      EXTRACT(DOW FROM current_date) + 1, -- Convert 0-6 to 1-7
      TO_CHAR(current_date, 'Day'),
      EXTRACT(DOW FROM current_date) IN (0, 6) -- Sunday=0, Saturday=6
    ) ON CONFLICT (date_day) DO NOTHING;
    
    current_date := current_date + INTERVAL '1 day';
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Populate time dimension for current year and next year
SELECT populate_dim_time('2024-01-01'::DATE, '2025-12-31'::DATE);

-- Comments
COMMENT ON TABLE dim_store IS 'Store master data with hierarchical location information';
COMMENT ON TABLE dim_product IS 'Product master data with brand and category hierarchy';
COMMENT ON TABLE dim_customer IS 'Customer dimension with segmentation and loyalty data';
COMMENT ON TABLE dim_time IS 'Time dimension for efficient date-based analytics';
COMMENT ON TABLE dim_campaign IS 'Marketing campaign master data';
COMMENT ON TABLE dim_zone IS 'In-store zone/location dimension for customer journey tracking';