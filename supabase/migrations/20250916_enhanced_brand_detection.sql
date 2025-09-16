-- Enhanced Brand Detection Migration
-- Adds missed brands from audio transcription analysis
-- Improves fuzzy matching and contextual detection

BEGIN;

-- Create enhanced brand master table with fuzzy matching support
CREATE TABLE IF NOT EXISTS metadata.enhanced_brand_master (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Core Brand Information
    brand_name TEXT NOT NULL,
    official_name TEXT NOT NULL,
    parent_company TEXT,
    category TEXT NOT NULL,
    subcategory TEXT,
    
    -- Detection Configuration
    detection_aliases TEXT[] DEFAULT '{}', -- Alternative names/spellings
    fuzzy_threshold DECIMAL(3,2) DEFAULT 0.75, -- Minimum similarity score
    context_keywords TEXT[] DEFAULT '{}', -- Context clues for disambiguation
    
    -- Audio-Specific Detection
    phonetic_variations TEXT[] DEFAULT '{}', -- Sound-alike variations
    common_misspellings TEXT[] DEFAULT '{}', -- Frequent STT errors
    local_names TEXT[] DEFAULT '{}', -- Filipino/local terms
    
    -- Product Information
    typical_skus TEXT[] DEFAULT '{}',
    price_range_min DECIMAL(10,2),
    price_range_max DECIMAL(10,2),
    
    -- Detection Metadata
    detection_confidence DECIMAL(3,2) DEFAULT 0.8,
    priority_level INTEGER DEFAULT 1, -- 1=high, 2=medium, 3=low
    is_active BOOLEAN DEFAULT true,
    
    -- Audit Fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_by TEXT DEFAULT 'brand_enhancement_migration'
);

-- Insert missed brands from CSV analysis
INSERT INTO metadata.enhanced_brand_master (
    brand_name, official_name, category, subcategory, 
    detection_aliases, phonetic_variations, common_misspellings, 
    context_keywords, fuzzy_threshold, priority_level
) VALUES 
-- High Priority Missed Brands (>20 occurrences)
('Hello', 'Hello', 'Snacks', 'cookies', 
 ARRAY['hello'], ARRAY['halo', 'helo'], ARRAY['hallo', 'helo'], 
 ARRAY['cookies', 'snack', 'biscuit'], 0.70, 1),

('TM', 'TM Lucky Me', 'Instant Noodles', 'pancit_canton', 
 ARRAY['tm', 'lucky me'], ARRAY['tim', 'teem'], ARRAY['tm'], 
 ARRAY['noodles', 'pancit', 'canton'], 0.80, 1),

('Tang', 'Tang', 'Beverages', 'powdered_drinks', 
 ARRAY['tang'], ARRAY['tan', 'teng'], ARRAY['teng', 'ten'], 
 ARRAY['orange', 'drink', 'tubig'], 0.75, 1),

('Voice', 'Voice', 'Telecoms', 'mobile_load', 
 ARRAY['voice'], ARRAY['vois', 'bois'], ARRAY['voise', 'boise'], 
 ARRAY['load', 'prepaid', 'mobile'], 0.75, 1),

('Roller Coaster', 'Roller Coaster', 'Snacks', 'potato_rings', 
 ARRAY['roller coaster', 'rollercoaster'], ARRAY['roler', 'rolor'], ARRAY['roller'], 
 ARRAY['rings', 'snack', 'chips'], 0.70, 1),

-- Medium Priority (10-20 occurrences)
('Jimms', 'Jimm''s', 'Snacks', 'corn_snacks', 
 ARRAY['jimms', 'jims'], ARRAY['gems', 'jems'], ARRAY['jim', 'gems'], 
 ARRAY['corn', 'snack'], 0.70, 2),

('Sting', 'Sting', 'Energy Drinks', 'energy', 
 ARRAY['sting'], ARRAY['stin', 'sten'], ARRAY['steng', 'sten'], 
 ARRAY['energy', 'drink', 'malamig'], 0.75, 2),

('Smart', 'Smart', 'Telecoms', 'mobile_load', 
 ARRAY['smart'], ARRAY['smar', 'smart'], ARRAY['smat'], 
 ARRAY['load', 'prepaid', 'mobile'], 0.80, 2),

('TNT', 'TNT', 'Telecoms', 'mobile_load', 
 ARRAY['tnt'], ARRAY['tint', 'tent'], ARRAY['tnt'], 
 ARRAY['load', 'prepaid', 'mobile'], 0.75, 2),

('Extra Joss', 'Extra Joss', 'Energy Drinks', 'energy', 
 ARRAY['extra joss', 'extrajoss'], ARRAY['ekstra', 'joss'], ARRAY['joss'], 
 ARRAY['energy', 'drink'], 0.70, 2),

('Supreme', 'Supreme', 'Instant Noodles', 'pancit_canton', 
 ARRAY['supreme'], ARRAY['suprim', 'supremo'], ARRAY['suprem'], 
 ARRAY['noodles', 'pancit'], 0.75, 2),

('Magic', 'Magic', 'Snacks', 'crackers', 
 ARRAY['magic'], ARRAY['majik', 'magik'], ARRAY['majic'], 
 ARRAY['crackers', 'biskwit'], 0.75, 2),

-- Lower Priority but Important (5-10 occurrences)
('Globe', 'Globe', 'Telecoms', 'mobile_load', 
 ARRAY['globe'], ARRAY['glob', 'glof'], ARRAY['glof'], 
 ARRAY['load', 'prepaid'], 0.75, 3),

('Surf', 'Surf', 'Household', 'detergent', 
 ARRAY['surf'], ARRAY['serf', 'surf'], ARRAY['serf'], 
 ARRAY['detergent', 'sabon', 'washing'], 0.80, 3),

('Great Taste', 'Great Taste', 'Beverages', 'coffee', 
 ARRAY['great taste', 'greattaste'], ARRAY['gret', 'teis'], ARRAY['taste'], 
 ARRAY['coffee', 'kape'], 0.70, 3),

('Marca Leon', 'Marca Leon', 'Beverages', 'soda', 
 ARRAY['marca leon'], ARRAY['marka'], ARRAY['leon'], 
 ARRAY['soda', 'softdrink'], 0.70, 3),

('Tiger', 'Tiger', 'Beverages', 'beer', 
 ARRAY['tiger'], ARRAY['taiger', 'tigger'], ARRAY['tigger'], 
 ARRAY['beer', 'alak'], 0.80, 3),

('Presto', 'Presto', 'Snacks', 'cream_filled', 
 ARRAY['presto'], ARRAY['prest', 'prasto'], ARRAY['prest'], 
 ARRAY['cream', 'filled'], 0.75, 3);

-- Create brand aliases lookup table for faster searches
CREATE TABLE IF NOT EXISTS metadata.brand_aliases_lookup (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id UUID REFERENCES metadata.enhanced_brand_master(id),
    alias_text TEXT NOT NULL,
    alias_type TEXT NOT NULL, -- 'official', 'phonetic', 'misspelling', 'local'
    confidence_boost DECIMAL(3,2) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Populate aliases lookup for fast matching
WITH brand_aliases AS (
    SELECT 
        id as brand_id,
        brand_name,
        unnest(detection_aliases || phonetic_variations || common_misspellings) as alias_text
    FROM metadata.enhanced_brand_master
)
INSERT INTO metadata.brand_aliases_lookup (brand_id, alias_text, alias_type, confidence_boost)
SELECT 
    brand_id,
    lower(trim(alias_text)) as alias_text,
    CASE 
        WHEN alias_text = brand_name THEN 'official'
        ELSE 'variation'
    END as alias_type,
    CASE 
        WHEN alias_text = brand_name THEN 0.2
        ELSE 0.1
    END as confidence_boost
FROM brand_aliases
ON CONFLICT DO NOTHING;

-- Create fuzzy brand matching function
CREATE OR REPLACE FUNCTION match_brands_enhanced(
    audio_text TEXT,
    min_confidence DECIMAL DEFAULT 0.6
) RETURNS TABLE (
    brand_name TEXT,
    confidence DECIMAL,
    match_method TEXT,
    matched_phrase TEXT
) AS $$
DECLARE
    brand_record RECORD;
    alias_record RECORD;
    similarity_score DECIMAL;
    context_boost DECIMAL;
    final_confidence DECIMAL;
    context_word TEXT;
    keyword_array TEXT[];
BEGIN
    -- Direct exact matches first (highest confidence)
    FOR brand_record IN 
        SELECT b.brand_name, b.fuzzy_threshold, b.context_keywords, b.detection_confidence
        FROM metadata.enhanced_brand_master b
        WHERE b.is_active = true
    LOOP
        -- Check for exact brand name match
        IF position(lower(brand_record.brand_name) IN lower(audio_text)) > 0 THEN
            context_boost := 0.0;
            
            -- Check for context keywords to boost confidence
            IF brand_record.context_keywords IS NOT NULL THEN
                FOR i IN 1..array_length(brand_record.context_keywords, 1)
                LOOP
                    context_word := brand_record.context_keywords[i];
                    IF position(lower(context_word) IN lower(audio_text)) > 0 THEN
                        context_boost := context_boost + 0.05;
                    END IF;
                END LOOP;
            END IF;
            
            final_confidence := LEAST(brand_record.detection_confidence + context_boost, 1.0);
            
            IF final_confidence >= min_confidence THEN
                brand_name := brand_record.brand_name;
                confidence := final_confidence;
                match_method := 'exact_match';
                matched_phrase := brand_record.brand_name;
                RETURN NEXT;
            END IF;
        END IF;
    END LOOP;
    
    -- Alias-based matching (medium confidence)
    FOR alias_record IN
        SELECT 
            b.brand_name, 
            a.alias_text, 
            a.confidence_boost,
            b.detection_confidence,
            b.context_keywords
        FROM metadata.enhanced_brand_master b
        JOIN metadata.brand_aliases_lookup a ON b.id = a.brand_id
        WHERE b.is_active = true
    LOOP
        IF position(alias_record.alias_text IN lower(audio_text)) > 0 THEN
            context_boost := 0.0;
            
            -- Check context keywords
            IF alias_record.context_keywords IS NOT NULL THEN
                FOR i IN 1..array_length(alias_record.context_keywords, 1)
                LOOP
                    context_word := alias_record.context_keywords[i];
                    IF position(lower(context_word) IN lower(audio_text)) > 0 THEN
                        context_boost := context_boost + 0.03;
                    END IF;
                END LOOP;
            END IF;
            
            final_confidence := alias_record.detection_confidence + alias_record.confidence_boost + context_boost;
            
            IF final_confidence >= min_confidence THEN
                brand_name := alias_record.brand_name;
                confidence := final_confidence;
                match_method := 'alias_match';
                matched_phrase := alias_record.alias_text;
                RETURN NEXT;
            END IF;
        END IF;
    END LOOP;
    
    -- Fuzzy matching for partial/misspelled names (lower confidence)
    FOR brand_record IN
        SELECT b.brand_name, b.fuzzy_threshold, b.detection_confidence, b.context_keywords
        FROM metadata.enhanced_brand_master b
        WHERE b.is_active = true
    LOOP
        -- Use PostgreSQL's similarity function for fuzzy matching
        similarity_score := similarity(lower(brand_record.brand_name), lower(audio_text));
        
        IF similarity_score >= brand_record.fuzzy_threshold THEN
            context_boost := 0.0;
            
            -- Check context keywords
            IF brand_record.context_keywords IS NOT NULL THEN
                FOR i IN 1..array_length(brand_record.context_keywords, 1)
                LOOP
                    context_word := brand_record.context_keywords[i];
                    IF position(lower(context_word) IN lower(audio_text)) > 0 THEN
                        context_boost := context_boost + 0.02;
                    END IF;
                END LOOP;
            END IF;
            
            final_confidence := similarity_score + context_boost;
            
            IF final_confidence >= min_confidence THEN
                brand_name := brand_record.brand_name;
                confidence := final_confidence;
                match_method := 'fuzzy_match';
                matched_phrase := brand_record.brand_name;
                RETURN NEXT;
            END IF;
        END IF;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Create brand detection improvement tracking
CREATE TABLE IF NOT EXISTS metadata.brand_detection_improvements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Detection Details
    audio_transcript TEXT NOT NULL,
    original_brands JSONB, -- Previously detected brands
    enhanced_brands JSONB, -- Newly detected brands with enhanced algorithm
    
    -- Performance Metrics
    brands_before INTEGER DEFAULT 0,
    brands_after INTEGER DEFAULT 0,
    improvement_count INTEGER DEFAULT 0,
    confidence_improvement DECIMAL(5,3) DEFAULT 0.0,
    
    -- Processing Info
    processing_method TEXT DEFAULT 'enhanced_detection',
    processing_time_ms INTEGER,
    
    -- Timestamps
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable pg_trgm extension for fuzzy text matching if not exists
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_enhanced_brand_master_name ON metadata.enhanced_brand_master USING gin (brand_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_brand_aliases_lookup_text ON metadata.brand_aliases_lookup USING gin (alias_text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_brand_aliases_brand_id ON metadata.brand_aliases_lookup(brand_id);

-- Add comments for documentation
COMMENT ON TABLE metadata.enhanced_brand_master IS 'Master brand registry with enhanced detection capabilities for audio transcription';
COMMENT ON FUNCTION match_brands_enhanced IS 'Enhanced brand matching function with fuzzy logic and context awareness';
COMMENT ON TABLE metadata.brand_detection_improvements IS 'Tracks improvements in brand detection accuracy after enhancement';

COMMIT;