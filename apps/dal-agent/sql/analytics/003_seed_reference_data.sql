-- ========================================================================
-- Scout Analytics - Seed Reference Data
-- File: 003_seed_reference_data.sql
-- Purpose: Populate reference tables with initial data for analytics
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

SET NOCOUNT ON;

PRINT '🌱 Seeding reference tables with initial data...';
PRINT '📅 Started: ' + CONVERT(varchar(20), GETDATE(), 120);
PRINT '';

-- ========================================================================
-- SEED TOBACCO PACK SPECIFICATIONS
-- ========================================================================

PRINT '🚬 Seeding tobacco pack specifications...';

-- Clear existing data
DELETE FROM ref.tobacco_pack_specs;

-- Popular Philippines cigarette brands with stick counts
INSERT INTO ref.tobacco_pack_specs (brand, sku, pack_type, sticks_per_pack) VALUES
-- Marlboro variants
('Marlboro', NULL, 'softpack', 20),
('Marlboro', 'Red', 'softpack', 20),
('Marlboro', 'Gold', 'softpack', 20),
('Marlboro', 'Ice Blast', 'softpack', 20),
('Marlboro', 'Black Menthol', 'softpack', 20),

-- Philip Morris brands
('Philip Morris', NULL, 'softpack', 20),
('Philip Morris', 'Blue', 'softpack', 20),
('Philip Morris', 'Red', 'softpack', 20),

-- Fortune brands
('Fortune', NULL, 'softpack', 20),
('Fortune', 'Red', 'softpack', 20),
('Fortune', 'Blue', 'softpack', 20),
('Fortune', 'Menthol', 'softpack', 20),

-- Hope brands
('Hope', NULL, 'softpack', 20),
('Hope', 'Premium', 'softpack', 20),

-- Local brands
('More', NULL, 'softpack', 20),
('More', 'Menthol', 'softpack', 20),
('Champion', NULL, 'softpack', 20),
('Champion', 'Green', 'softpack', 20),

-- Single stick sales (common in sari-sari stores)
('Marlboro', 'Single', 'stick', 1),
('Philip Morris', 'Single', 'stick', 1),
('Fortune', 'Single', 'stick', 1),
('Hope', 'Single', 'stick', 1),
('More', 'Single', 'stick', 1),
('Champion', 'Single', 'stick', 1),

-- Generic fallback for unmapped brands
('Generic Cigarette', NULL, 'softpack', 20),
('Unknown Brand', NULL, 'stick', 1);

DECLARE @tobacco_count int = @@ROWCOUNT;
PRINT '✅ Inserted ' + CAST(@tobacco_count AS varchar(10)) + ' tobacco pack specifications';

-- ========================================================================
-- SEED DETERGENT SPECIFICATIONS
-- ========================================================================

PRINT '';
PRINT '🧼 Seeding detergent specifications...';

-- Clear existing data
DELETE FROM ref.detergent_specs;

-- Popular Philippines detergent brands by form
INSERT INTO ref.detergent_specs (brand, sku, detergent_form) VALUES
-- Tide variants
('Tide', NULL, 'powder'),
('Tide', 'Original', 'powder'),
('Tide', 'Ultra', 'powder'),
('Tide', 'Liquid', 'liquid'),

-- Ariel variants
('Ariel', NULL, 'powder'),
('Ariel', 'Original', 'powder'),
('Ariel', 'Ultra Clean', 'powder'),
('Ariel', 'Liquid', 'liquid'),

-- Surf variants
('Surf', NULL, 'powder'),
('Surf', 'Fab', 'powder'),
('Surf', 'Bango', 'powder'),

-- Local/Popular bar soaps
('Perla', NULL, 'bar'),
('Speed', NULL, 'bar'),
('Master', NULL, 'bar'),
('Fels', NULL, 'bar'),
('Lucky Me', NULL, 'bar'),

-- Breeze variants
('Breeze', NULL, 'powder'),
('Breeze', 'Ultra Clean', 'powder'),

-- Pride variants
('Pride', NULL, 'powder'),
('Pride', 'Ultra', 'powder'),

-- Generic fallbacks
('Generic Powder', NULL, 'powder'),
('Generic Bar', NULL, 'bar'),
('Generic Liquid', NULL, 'liquid'),
('Unknown Detergent', NULL, 'powder');

DECLARE @detergent_count int = @@ROWCOUNT;
PRINT '✅ Inserted ' + CAST(@detergent_count AS varchar(10)) + ' detergent specifications';

-- ========================================================================
-- SEED TRANSCRIPT TERM DICTIONARY
-- ========================================================================

PRINT '';
PRINT '📝 Seeding transcript term dictionary...';

-- Clear existing data
DELETE FROM ref.term_dictionary;

-- Tobacco-related terms (Filipino/Taglish)
INSERT INTO ref.term_dictionary (term_type, phrase, weight) VALUES
-- High-confidence tobacco terms
('tobacco_intent', 'yosi', 1.0),
('tobacco_intent', 'sigarilyo', 1.0),
('tobacco_intent', 'cigarette', 1.0),
('tobacco_intent', 'usok', 0.9),
('tobacco_intent', 'stick', 0.8),
('tobacco_intent', 'tobacco', 1.0),

-- Tobacco brands (common Filipino pronunciations/slang)
('tobacco_brand', 'marlboro', 1.0),
('tobacco_brand', 'malboro', 1.0),  -- common mispronunciation
('tobacco_brand', 'red marlboro', 1.0),
('tobacco_brand', 'philip morris', 1.0),
('tobacco_brand', 'fortune', 1.0),
('tobacco_brand', 'hope', 1.0),
('tobacco_brand', 'more', 0.9),     -- could be ambiguous
('tobacco_brand', 'champion', 0.9),

-- Laundry-related terms
('laundry_intent', 'sabon', 1.0),
('laundry_intent', 'soap', 1.0),
('laundry_intent', 'detergent', 1.0),
('laundry_intent', 'labada', 1.0),
('laundry_intent', 'hugos', 1.0),
('laundry_intent', 'washing', 0.9),
('laundry_intent', 'laba', 1.0),

-- Laundry brands
('laundry_brand', 'tide', 1.0),
('laundry_brand', 'ariel', 1.0),
('laundry_brand', 'surf', 1.0),
('laundry_brand', 'perla', 1.0),
('laundry_brand', 'speed', 1.0),
('laundry_brand', 'master', 1.0),
('laundry_brand', 'breeze', 1.0),
('laundry_brand', 'pride', 1.0),

-- Product form indicators
('product_form', 'powder', 0.8),
('product_form', 'pulbos', 0.8),   -- Filipino for powder
('product_form', 'liquid', 0.8),
('product_form', 'bar', 0.8),
('product_form', 'sabon bar', 0.9),

-- Fabric conditioner terms
('fabcon_intent', 'fabcon', 1.0),
('fabcon_intent', 'fabric conditioner', 1.0),
('fabcon_intent', 'conditioner', 0.7), -- could be ambiguous
('fabcon_intent', 'softener', 0.8),
('fabcon_intent', 'lambot', 0.9),      -- Filipino for soft

-- Common Taglish filler words (lower weight)
('filler', 'yung', 0.1),
('filler', 'kasi', 0.1),
('filler', 'pero', 0.1),
('filler', 'tapos', 0.1),
('filler', 'syempre', 0.1);

DECLARE @term_count int = @@ROWCOUNT;
PRINT '✅ Inserted ' + CAST(@term_count AS varchar(10)) + ' transcript terms';

-- ========================================================================
-- VALIDATION
-- ========================================================================

PRINT '';
PRINT '🔍 Validating seed data...';

DECLARE @total_tobacco int, @total_detergent int, @total_terms int;

SELECT @total_tobacco = COUNT(*) FROM ref.tobacco_pack_specs;
SELECT @total_detergent = COUNT(*) FROM ref.detergent_specs;
SELECT @total_terms = COUNT(*) FROM ref.term_dictionary;

PRINT '📊 Seed data summary:';
PRINT '   Tobacco specifications: ' + CAST(@total_tobacco AS varchar(10));
PRINT '   Detergent specifications: ' + CAST(@total_detergent AS varchar(10));
PRINT '   Dictionary terms: ' + CAST(@total_terms AS varchar(10));

-- Validate minimum expected data
IF @total_tobacco >= 10 AND @total_detergent >= 10 AND @total_terms >= 20
BEGIN
    PRINT '✅ Seed data validation PASSED - All tables populated with minimum expected data';

    -- Show sample data
    PRINT '';
    PRINT '📋 Sample tobacco specifications:';
    SELECT TOP 3 brand, pack_type, sticks_per_pack FROM ref.tobacco_pack_specs ORDER BY brand;

    PRINT '';
    PRINT '📋 Sample detergent specifications:';
    SELECT TOP 3 brand, detergent_form FROM ref.detergent_specs ORDER BY brand;

    PRINT '';
    PRINT '📋 Sample dictionary terms:';
    SELECT TOP 5 term_type, phrase, weight FROM ref.term_dictionary ORDER BY weight DESC, phrase;
END
ELSE
BEGIN
    PRINT '❌ Seed data validation FAILED - Insufficient data populated';
    THROW 50003, 'Seed data validation failed - minimum data requirements not met', 1;
END

PRINT '';
PRINT '🎉 Reference data seeding completed successfully!';
PRINT '📅 Finished: ' + CONVERT(varchar(20), GETDATE(), 120);

GO