-- =====================================
-- Scout Edge Fact Transactions Location
-- NCR Store Analysis with Substitution Events
-- =====================================

-- Create table for Scout Edge transactions with location dimensions
CREATE TABLE IF NOT EXISTS fact_transactions_location (
    -- Primary Keys
    canonical_tx_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id TEXT NOT NULL,

    -- Device & Store Dimensions
    device_id TEXT NOT NULL,
    store_id INTEGER NOT NULL,

    -- Location Dimensions (NCR)
    region TEXT DEFAULT 'NCR',
    province_name TEXT DEFAULT 'Metro Manila',
    municipality_name TEXT,
    barangay_name TEXT,
    geo_latitude DECIMAL(10,8),
    geo_longitude DECIMAL(11,8),

    -- Transaction Core Data
    total_amount DECIMAL(10,2) NOT NULL,
    total_items INTEGER NOT NULL,
    branded_amount DECIMAL(10,2) DEFAULT 0,
    unbranded_amount DECIMAL(10,2) DEFAULT 0,
    branded_count INTEGER DEFAULT 0,
    unbranded_count INTEGER DEFAULT 0,
    unique_brands_count INTEGER DEFAULT 0,

    -- Audio & Detection Context
    audio_transcript TEXT,
    processing_duration DECIMAL(6,2),
    payment_method TEXT,
    time_of_day TEXT,
    day_type TEXT,

    -- Substitution Event Analysis
    substitution_detected BOOLEAN DEFAULT FALSE,
    substitution_reason TEXT,
    requested_brands JSONB,
    purchased_brands JSONB,
    brand_switching_score DECIMAL(4,3),

    -- Privacy & Compliance
    audio_stored BOOLEAN DEFAULT FALSE,
    facial_recognition BOOLEAN DEFAULT FALSE,
    anonymization_level TEXT DEFAULT 'high',
    data_retention_days INTEGER DEFAULT 30,
    consent_timestamp TIMESTAMPTZ,

    -- Technical Metadata
    edge_version TEXT,
    processing_methods TEXT[],
    source_file_path TEXT,

    -- Timestamps
    processed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_store_id ON fact_transactions_location(store_id);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_device_id ON fact_transactions_location(device_id);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_municipality ON fact_transactions_location(municipality_name);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_substitution ON fact_transactions_location(substitution_detected);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_processed_at ON fact_transactions_location(processed_at);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_total_amount ON fact_transactions_location(total_amount);

-- GIN index for JSONB brand data
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_requested_brands ON fact_transactions_location USING GIN(requested_brands);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_purchased_brands ON fact_transactions_location USING GIN(purchased_brands);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_store_date ON fact_transactions_location(store_id, processed_at);
CREATE INDEX IF NOT EXISTS idx_fact_tx_location_municipality_amount ON fact_transactions_location(municipality_name, total_amount);

-- Create items detail table for normalized structure
CREATE TABLE IF NOT EXISTS fact_transaction_items (
    item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_tx_id UUID NOT NULL REFERENCES fact_transactions_location(canonical_tx_id) ON DELETE CASCADE,

    -- Item Details
    brand_name TEXT,
    product_name TEXT,
    generic_name TEXT,
    local_name TEXT,
    sku TEXT,

    -- Quantities & Pricing
    quantity INTEGER NOT NULL DEFAULT 1,
    unit TEXT DEFAULT 'pc',
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),

    -- Categorization
    category TEXT,
    subcategory TEXT,
    is_unbranded BOOLEAN DEFAULT FALSE,
    is_bulk BOOLEAN DEFAULT FALSE,

    -- Detection Analysis
    detection_method TEXT,
    confidence DECIMAL(4,3),
    brand_confidence DECIMAL(4,3),
    suggested_brands JSONB,

    -- Customer Behavior
    customer_request_type TEXT, -- branded, unbranded, specific
    specific_brand_requested BOOLEAN DEFAULT FALSE,
    pointed_to_product BOOLEAN DEFAULT FALSE,
    accepted_suggestion BOOLEAN DEFAULT FALSE,

    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for items table
CREATE INDEX IF NOT EXISTS idx_fact_tx_items_canonical_tx ON fact_transaction_items(canonical_tx_id);
CREATE INDEX IF NOT EXISTS idx_fact_tx_items_brand ON fact_transaction_items(brand_name);
CREATE INDEX IF NOT EXISTS idx_fact_tx_items_category ON fact_transaction_items(category);
CREATE INDEX IF NOT EXISTS idx_fact_tx_items_detection ON fact_transaction_items(detection_method);

-- Store location dimension table for NCR mapping
CREATE TABLE IF NOT EXISTS dim_ncr_stores (
    store_id INTEGER PRIMARY KEY,
    store_name TEXT,
    municipality_name TEXT NOT NULL,
    barangay_name TEXT,
    region TEXT DEFAULT 'NCR',
    province_name TEXT DEFAULT 'Metro Manila',
    geo_latitude DECIMAL(10,8),
    geo_longitude DECIMAL(11,8),
    psgc_region CHAR(9),
    psgc_citymun CHAR(9),
    psgc_barangay CHAR(9),
    store_polygon TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize NCR store mappings (7 stores with data)
INSERT INTO dim_ncr_stores (store_id, municipality_name) VALUES
(102, 'Manila'),
(103, 'Quezon City'),
(104, 'Makati'),
(108, 'Pasig'),
(109, 'Mandaluyong'),
(110, 'Parañaque'),
(112, 'Taguig')
ON CONFLICT (store_id) DO NOTHING;

-- Function to detect substitution events
CREATE OR REPLACE FUNCTION detect_substitution_event(
    p_transcript TEXT,
    p_purchased_brands JSONB
) RETURNS TABLE (
    is_substitution BOOLEAN,
    substitution_reason TEXT,
    brand_switching_score DECIMAL(4,3)
) AS $$
DECLARE
    v_transcript_lower TEXT;
    v_brand_mentioned BOOLEAN := FALSE;
    v_brand_record RECORD;
    v_score DECIMAL(4,3) := 0.0;
    v_reason TEXT := '';
BEGIN
    -- Normalize transcript
    v_transcript_lower := LOWER(TRIM(p_transcript));

    -- Check if any purchased brand appears in transcript
    FOR v_brand_record IN
        SELECT jsonb_array_elements_text(p_purchased_brands) as brand_name
    LOOP
        IF POSITION(LOWER(v_brand_record.brand_name) IN v_transcript_lower) > 0 THEN
            v_brand_mentioned := TRUE;
            EXIT;
        END IF;
    END LOOP;

    -- Determine substitution
    IF LENGTH(v_transcript_lower) > 0 AND NOT v_brand_mentioned THEN
        -- Calculate switching score based on transcript complexity
        v_score := CASE
            WHEN LENGTH(v_transcript_lower) > 50 THEN 0.9
            WHEN LENGTH(v_transcript_lower) > 20 THEN 0.7
            ELSE 0.5
        END;

        v_reason := 'Brand not mentioned in transcript';

        RETURN QUERY SELECT TRUE, v_reason, v_score;
    ELSE
        RETURN QUERY SELECT FALSE, NULL::TEXT, 0.0::DECIMAL(4,3);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to generate canonical transaction ID
CREATE OR REPLACE FUNCTION generate_canonical_tx_id(
    p_store_id TEXT,
    p_timestamp TIMESTAMPTZ,
    p_amount DECIMAL,
    p_device_id TEXT
) RETURNS UUID AS $$
BEGIN
    RETURN (
        SELECT MD5(
            COALESCE(p_store_id, '') || '|' ||
            COALESCE(p_timestamp::TEXT, '') || '|' ||
            COALESCE(p_amount::TEXT, '') || '|' ||
            COALESCE(p_device_id, '')
        )::UUID
    );
END;
$$ LANGUAGE plpgsql;

-- Comments for documentation
COMMENT ON TABLE fact_transactions_location IS 'Scout Edge transactions with NCR location enrichment and substitution analysis';
COMMENT ON TABLE fact_transaction_items IS 'Individual items purchased in Scout Edge transactions';
COMMENT ON TABLE dim_ncr_stores IS 'NCR store locations and geographic boundaries';
COMMENT ON FUNCTION detect_substitution_event IS 'Analyzes transcript vs purchased brands to detect substitution events';
COMMENT ON FUNCTION generate_canonical_tx_id IS 'Generates deterministic UUID for transaction deduplication';