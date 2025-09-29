-- =============================================================================
-- Enhance Nielsen SKU dimension with parent company, logos, and fuzzy matching
-- For STT (Speech-to-Text) brand detection model support
-- =============================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- Add parent company and brand logo columns to existing table
ALTER TABLE dbo.dim_sku_nielsen
ADD parent_company nvarchar(200) NULL,
    brand_logo_url nvarchar(500) NULL;
GO

-- Create brand aliases table for fuzzy matching
CREATE TABLE dbo.brand_aliases (
    alias_id int IDENTITY(1,1) NOT NULL,
    brand_name nvarchar(200) NOT NULL,
    alias_text nvarchar(200) NOT NULL,
    alias_type varchar(50) NOT NULL, -- 'phonetic', 'misspelling', 'abbreviation', 'local_name'
    confidence_score decimal(5,3) DEFAULT 0.8,
    language_code varchar(5) DEFAULT 'en-PH',
    created_date datetime2(0) DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_brand_aliases PRIMARY KEY (alias_id),
    CONSTRAINT FK_brand_aliases_brand FOREIGN KEY (brand_name)
        REFERENCES dbo.dim_sku_nielsen(brand_name)
);
GO

CREATE INDEX IX_brand_aliases_brand ON dbo.brand_aliases(brand_name);
CREATE INDEX IX_brand_aliases_text ON dbo.brand_aliases(alias_text);
GO

-- Update existing SKUs with parent company information
UPDATE dbo.dim_sku_nielsen
SET parent_company = CASE brand_name
    -- Nestlé Group
    WHEN 'Nescafé' THEN 'Nestlé Philippines'
    WHEN 'Milo' THEN 'Nestlé Philippines'
    WHEN 'Bear Brand' THEN 'Nestlé Philippines'
    WHEN 'Maggi' THEN 'Nestlé Philippines'
    WHEN 'Nestea' THEN 'Nestlé Philippines'

    -- Unilever Group
    WHEN 'Surf' THEN 'Unilever Philippines'
    WHEN 'Dove' THEN 'Unilever Philippines'
    WHEN 'Closeup' THEN 'Unilever Philippines'
    WHEN 'Sunsilk' THEN 'Unilever Philippines'
    WHEN 'Cream Silk' THEN 'Unilever Philippines'
    WHEN 'Safeguard' THEN 'Unilever Philippines'
    WHEN 'Rexona' THEN 'Unilever Philippines'
    WHEN 'Knorr' THEN 'Unilever Philippines'
    WHEN 'Breyers' THEN 'Unilever Philippines'

    -- Procter & Gamble
    WHEN 'Head & Shoulders' THEN 'Procter & Gamble Philippines'
    WHEN 'Pantene' THEN 'Procter & Gamble Philippines'
    WHEN 'Olay' THEN 'Procter & Gamble Philippines'
    WHEN 'Tide' THEN 'Procter & Gamble Philippines'
    WHEN 'Ariel' THEN 'Procter & Gamble Philippines'
    WHEN 'Downy' THEN 'Procter & Gamble Philippines'
    WHEN 'Joy' THEN 'Procter & Gamble Philippines'
    WHEN 'Pampers' THEN 'Procter & Gamble Philippines'

    -- Coca-Cola Company
    WHEN 'Coca-Cola' THEN 'Coca-Cola Philippines'
    WHEN 'Sprite' THEN 'Coca-Cola Philippines'
    WHEN 'Royal' THEN 'Coca-Cola Philippines'
    WHEN 'Minute Maid' THEN 'Coca-Cola Philippines'
    WHEN 'Powerade' THEN 'Coca-Cola Philippines'

    -- Universal Robina Corporation
    WHEN 'C2' THEN 'Universal Robina Corporation'
    WHEN 'Great Taste' THEN 'Universal Robina Corporation'
    WHEN 'Jack n Jill' THEN 'Universal Robina Corporation'
    WHEN 'Piattos' THEN 'Universal Robina Corporation'
    WHEN 'Nova' THEN 'Universal Robina Corporation'

    -- San Miguel Corporation
    WHEN 'San Miguel' THEN 'San Miguel Corporation'
    WHEN 'Magnolia' THEN 'San Miguel Corporation'
    WHEN 'Monterey' THEN 'San Miguel Corporation'

    -- Other major groups
    WHEN 'Lucky Me!' THEN 'Monde Nissin Corporation'
    WHEN 'Argentina' THEN 'Monde Nissin Corporation'
    WHEN 'Ricoa' THEN 'Ricoa & Company'
    WHEN 'Kopiko' THEN 'Mayora Indah'
    WHEN 'Rebisco' THEN 'JG Summit Holdings'
    WHEN 'Richeese' THEN 'Richeese Factory'
    WHEN 'Oishi' THEN 'Liwayway Holdings'
    WHEN 'Chippy' THEN 'Liwayway Holdings'
    WHEN 'Zesto' THEN 'Zesto Corporation'
    WHEN 'Vitamilk' THEN 'Vitamilk (Thai-Danish Dairy)'

    -- Independent/Local brands
    ELSE brand_name + ' Corporation'
END;
GO

-- Update brand logo URLs (placeholder structure for actual logo management)
UPDATE dbo.dim_sku_nielsen
SET brand_logo_url = CASE brand_name
    WHEN 'Coca-Cola' THEN 'https://cdn.scout.ph/logos/coca-cola.png'
    WHEN 'Nescafé' THEN 'https://cdn.scout.ph/logos/nescafe.png'
    WHEN 'Milo' THEN 'https://cdn.scout.ph/logos/milo.png'
    WHEN 'Lucky Me!' THEN 'https://cdn.scout.ph/logos/lucky-me.png'
    WHEN 'Surf' THEN 'https://cdn.scout.ph/logos/surf.png'
    WHEN 'Head & Shoulders' THEN 'https://cdn.scout.ph/logos/head-shoulders.png'
    WHEN 'Pantene' THEN 'https://cdn.scout.ph/logos/pantene.png'
    WHEN 'Jack n Jill' THEN 'https://cdn.scout.ph/logos/jack-n-jill.png'
    WHEN 'C2' THEN 'https://cdn.scout.ph/logos/c2.png'
    WHEN 'Great Taste' THEN 'https://cdn.scout.ph/logos/great-taste.png'
    ELSE 'https://cdn.scout.ph/logos/' + LOWER(REPLACE(REPLACE(brand_name, ' ', '-'), '&', 'and')) + '.png'
END;
GO

-- Insert comprehensive brand aliases for STT recognition
INSERT INTO dbo.brand_aliases (brand_name, alias_text, alias_type, confidence_score, language_code)
VALUES
    -- Coca-Cola variations
    ('Coca-Cola', 'coke', 'abbreviation', 0.95, 'en-PH'),
    ('Coca-Cola', 'coca cola', 'phonetic', 0.9, 'en-PH'),
    ('Coca-Cola', 'koka kola', 'phonetic', 0.85, 'fil-PH'),
    ('Coca-Cola', 'koka', 'abbreviation', 0.8, 'fil-PH'),

    -- Nescafé variations
    ('Nescafé', 'nescafe', 'misspelling', 0.95, 'en-PH'),
    ('Nescafé', 'nes cafe', 'phonetic', 0.9, 'en-PH'),
    ('Nescafé', 'neskape', 'phonetic', 0.85, 'fil-PH'),

    -- Lucky Me! variations
    ('Lucky Me!', 'lucky me', 'phonetic', 0.95, 'en-PH'),
    ('Lucky Me!', 'laki mi', 'phonetic', 0.85, 'fil-PH'),
    ('Lucky Me!', 'lucky', 'abbreviation', 0.8, 'en-PH'),

    -- Head & Shoulders variations
    ('Head & Shoulders', 'head and shoulders', 'phonetic', 0.95, 'en-PH'),
    ('Head & Shoulders', 'head shoulders', 'abbreviation', 0.9, 'en-PH'),
    ('Head & Shoulders', 'hed en solders', 'phonetic', 0.8, 'fil-PH'),

    -- Jack n Jill variations
    ('Jack n Jill', 'jack and jill', 'phonetic', 0.95, 'en-PH'),
    ('Jack n Jill', 'jack jill', 'abbreviation', 0.9, 'en-PH'),
    ('Jack n Jill', 'jak en jil', 'phonetic', 0.8, 'fil-PH'),

    -- Great Taste variations
    ('Great Taste', 'great taste coffee', 'phonetic', 0.9, 'en-PH'),
    ('Great Taste', 'greyt teyst', 'phonetic', 0.85, 'fil-PH'),
    ('Great Taste', 'gt coffee', 'abbreviation', 0.8, 'en-PH'),

    -- Surf variations
    ('Surf', 'surf powder', 'phonetic', 0.9, 'en-PH'),
    ('Surf', 'sarp', 'phonetic', 0.8, 'fil-PH'),

    -- Milo variations
    ('Milo', 'milo drink', 'phonetic', 0.9, 'en-PH'),
    ('Milo', 'mailo', 'phonetic', 0.8, 'fil-PH'),

    -- C2 variations
    ('C2', 'c two', 'phonetic', 0.95, 'en-PH'),
    ('C2', 'si tu', 'phonetic', 0.8, 'fil-PH'),
    ('C2', 'c2 tea', 'phonetic', 0.9, 'en-PH'),

    -- Pantene variations
    ('Pantene', 'pantene pro v', 'phonetic', 0.9, 'en-PH'),
    ('Pantene', 'pantin', 'phonetic', 0.8, 'fil-PH'),

    -- Sprite variations
    ('Sprite', 'sprite soda', 'phonetic', 0.9, 'en-PH'),
    ('Sprite', 'sprayt', 'phonetic', 0.8, 'fil-PH'),

    -- Bear Brand variations
    ('Bear Brand', 'bear brand milk', 'phonetic', 0.9, 'en-PH'),
    ('Bear Brand', 'ber brand', 'phonetic', 0.85, 'fil-PH'),
    ('Bear Brand', 'bear', 'abbreviation', 0.8, 'en-PH'),

    -- Safeguard variations
    ('Safeguard', 'safeguard soap', 'phonetic', 0.9, 'en-PH'),
    ('Safeguard', 'seyp gard', 'phonetic', 0.8, 'fil-PH'),

    -- Dove variations
    ('Dove', 'dove soap', 'phonetic', 0.9, 'en-PH'),
    ('Dove', 'dav', 'phonetic', 0.8, 'fil-PH'),

    -- Closeup variations
    ('Closeup', 'close up', 'phonetic', 0.95, 'en-PH'),
    ('Closeup', 'klows ap', 'phonetic', 0.8, 'fil-PH'),

    -- Ariel variations
    ('Ariel', 'ariel powder', 'phonetic', 0.9, 'en-PH'),
    ('Ariel', 'aryel', 'phonetic', 0.85, 'fil-PH'),

    -- Tide variations
    ('Tide', 'tide powder', 'phonetic', 0.9, 'en-PH'),
    ('Tide', 'tayd', 'phonetic', 0.8, 'fil-PH'),

    -- Downy variations
    ('Downy', 'downy fabric softener', 'phonetic', 0.9, 'en-PH'),
    ('Downy', 'dawni', 'phonetic', 0.8, 'fil-PH'),

    -- Oishi variations
    ('Oishi', 'oishi snacks', 'phonetic', 0.9, 'en-PH'),
    ('Oishi', 'oyshi', 'phonetic', 0.85, 'fil-PH'),

    -- Chippy variations
    ('Chippy', 'chippy corn chips', 'phonetic', 0.9, 'en-PH'),
    ('Chippy', 'chipi', 'phonetic', 0.8, 'fil-PH'),

    -- Piattos variations
    ('Piattos', 'piattos chips', 'phonetic', 0.9, 'en-PH'),
    ('Piattos', 'pyatos', 'phonetic', 0.8, 'fil-PH'),

    -- Nova variations
    ('Nova', 'nova chips', 'phonetic', 0.9, 'en-PH'),
    ('Nova', 'noba', 'phonetic', 0.8, 'fil-PH'),

    -- Knorr variations
    ('Knorr', 'knorr cubes', 'phonetic', 0.9, 'en-PH'),
    ('Knorr', 'nor', 'phonetic', 0.8, 'fil-PH'),

    -- Maggi variations
    ('Maggi', 'maggi cubes', 'phonetic', 0.9, 'en-PH'),
    ('Maggi', 'magi', 'phonetic', 0.85, 'fil-PH'),

    -- Royal variations
    ('Royal', 'royal tru orange', 'phonetic', 0.9, 'en-PH'),
    ('Royal', 'royal soda', 'phonetic', 0.85, 'en-PH'),

    -- Kopiko variations
    ('Kopiko', 'kopiko coffee', 'phonetic', 0.9, 'en-PH'),
    ('Kopiko', 'kopyo', 'phonetic', 0.8, 'fil-PH'),

    -- Ricoa variations
    ('Ricoa', 'ricoa chocolate', 'phonetic', 0.9, 'en-PH'),
    ('Ricoa', 'rikoa', 'phonetic', 0.85, 'fil-PH'),

    -- Argentina variations
    ('Argentina', 'argentina beef', 'phonetic', 0.9, 'en-PH'),
    ('Argentina', 'arhentina', 'phonetic', 0.8, 'fil-PH'),

    -- Sunsilk variations
    ('Sunsilk', 'sunsilk shampoo', 'phonetic', 0.9, 'en-PH'),
    ('Sunsilk', 'sanslik', 'phonetic', 0.8, 'fil-PH'),

    -- Joy variations
    ('Joy', 'joy dishwashing', 'phonetic', 0.9, 'en-PH'),
    ('Joy', 'hoy', 'phonetic', 0.75, 'fil-PH'),

    -- Olay variations
    ('Olay', 'olay total effects', 'phonetic', 0.9, 'en-PH'),
    ('Olay', 'oley', 'phonetic', 0.8, 'fil-PH');
GO

PRINT 'Nielsen dimension table enhanced with parent company, brand logos, and fuzzy matching aliases.';

-- Summary of enhancements
SELECT
    'Parent Companies Added' as enhancement,
    COUNT(DISTINCT parent_company) as count
FROM dbo.dim_sku_nielsen
WHERE parent_company IS NOT NULL

UNION ALL

SELECT
    'Brand Logos Added' as enhancement,
    COUNT(DISTINCT brand_logo_url) as count
FROM dbo.dim_sku_nielsen
WHERE brand_logo_url IS NOT NULL

UNION ALL

SELECT
    'Brand Aliases Created' as enhancement,
    COUNT(*) as count
FROM dbo.brand_aliases

UNION ALL

SELECT
    'Unique Brands with Aliases' as enhancement,
    COUNT(DISTINCT brand_name) as count
FROM dbo.brand_aliases;