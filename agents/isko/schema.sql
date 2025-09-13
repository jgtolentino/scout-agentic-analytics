-- Isko Agent Database Schema
-- For Supabase/PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- SKU Catalog table (main storage)
CREATE TABLE IF NOT EXISTS sku_catalog (
    sku_id VARCHAR(100) PRIMARY KEY,
    brand_name VARCHAR(200),
    sku_name VARCHAR(500) NOT NULL,
    pack_size DECIMAL(10,2),
    pack_unit VARCHAR(50),
    category VARCHAR(100),
    msrp DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_sku_catalog_category ON sku_catalog(category);
CREATE INDEX idx_sku_catalog_brand ON sku_catalog(brand_name);
CREATE INDEX idx_sku_catalog_updated ON sku_catalog(updated_at DESC);

-- Scraping history table
CREATE TABLE IF NOT EXISTS isko_scraping_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    scrape_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    category VARCHAR(100),
    url TEXT,
    items_found INTEGER,
    items_new INTEGER,
    items_updated INTEGER,
    status VARCHAR(50),
    error_message TEXT,
    metadata JSONB
);

-- Create index for history queries
CREATE INDEX idx_scraping_history_date ON isko_scraping_history(scrape_date DESC);
CREATE INDEX idx_scraping_history_status ON isko_scraping_history(status);

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_sku_catalog_updated_at 
    BEFORE UPDATE ON sku_catalog 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- View for recent SKU changes
CREATE OR REPLACE VIEW recent_sku_changes AS
SELECT 
    sku_id,
    sku_name,
    category,
    brand_name,
    msrp,
    updated_at
FROM sku_catalog
WHERE updated_at > NOW() - INTERVAL '7 days'
ORDER BY updated_at DESC;

-- Function to get scraping stats
CREATE OR REPLACE FUNCTION get_scraping_stats(days_back INTEGER DEFAULT 30)
RETURNS TABLE (
    total_scrapes BIGINT,
    successful_scrapes BIGINT,
    total_items_found BIGINT,
    categories_scraped BIGINT,
    last_scrape_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_scrapes,
        COUNT(CASE WHEN status = 'success' THEN 1 END)::BIGINT as successful_scrapes,
        COALESCE(SUM(items_found), 0)::BIGINT as total_items_found,
        COUNT(DISTINCT category)::BIGINT as categories_scraped,
        MAX(scrape_date) as last_scrape_date
    FROM isko_scraping_history
    WHERE scrape_date > NOW() - INTERVAL '1 day' * days_back;
END;
$$ LANGUAGE plpgsql;

-- Row Level Security (if using Supabase Auth)
ALTER TABLE sku_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE isko_scraping_history ENABLE ROW LEVEL SECURITY;

-- Policy for read access (adjust based on your auth needs)
CREATE POLICY "Allow public read access to SKU catalog" 
    ON sku_catalog FOR SELECT 
    USING (true);

CREATE POLICY "Allow authenticated read access to scraping history" 
    ON isko_scraping_history FOR SELECT 
    TO authenticated
    USING (true);