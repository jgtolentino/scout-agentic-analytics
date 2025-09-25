SET NOCOUNT ON;

-- Load template SKU data
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'C2-250ML',N'C2 Green Tea 250ml',N'C2',N'BEV_SOFT_CITRUS',N'250ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'C2-500ML',N'C2 Green Tea 500ml',N'C2',N'BEV_SOFT_CITRUS',N'500ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'COKE-250ML',N'Coca-Cola 250ml',N'Coke',N'BEV_SOFT_COLA',N'250ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'COKE-500ML',N'Coca-Cola 500ml',N'Coke',N'BEV_SOFT_COLA',N'500ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'COKE-1L',N'Coca-Cola 1L',N'Coke',N'BEV_SOFT_COLA',N'1000ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'PEPSI-250ML',N'Pepsi 250ml',N'Pepsi',N'BEV_SOFT_COLA',N'250ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'PEPSI-500ML',N'Pepsi 500ml',N'Pepsi',N'BEV_SOFT_COLA',N'500ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'SPRITE-250ML',N'Sprite 250ml',N'Sprite',N'BEV_SOFT_CITRUS',N'250ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'SPRITE-500ML',N'Sprite 500ml',N'Sprite',N'BEV_SOFT_CITRUS',N'500ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'NESCAFE-3IN1-10G',N'Nescafe 3-in-1 Original 10g',N'Nescafe',N'BEV_COFFEE_3IN1',N'10g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'NESCAFE-3IN1-20G',N'Nescafe 3-in-1 Original 20g',N'Nescafe',N'BEV_COFFEE_3IN1',N'20g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'GREATTASTE-3IN1-10G',N'Great Taste 3-in-1 10g',N'Great Taste',N'BEV_COFFEE_3IN1',N'10g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'GREATTASTE-3IN1-20G',N'Great Taste 3-in-1 20g',N'Great Taste',N'BEV_COFFEE_3IN1',N'20g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'ALASKA-3IN1-10G',N'Alaska Milk Coffee 3-in-1 10g',N'Alaska',N'BEV_COFFEE_3IN1',N'10g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'LUCKYME-BEEF-55G',N'Lucky Me! Beef na Beef 55g',N'Lucky Me',N'FOOD_INSTANT_NOODLES_PACK',N'55g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'LUCKYME-CHICKEN-55G',N'Lucky Me! Chicken na Chicken 55g',N'Lucky Me',N'FOOD_INSTANT_NOODLES_PACK',N'55g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'LUCKYME-PORK-55G',N'Lucky Me! Pork Chop 55g',N'Lucky Me',N'FOOD_INSTANT_NOODLES_PACK',N'55g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'NISSIN-CUP-60G',N'Nissin Cup Noodles Beef 60g',N'Nissin',N'FOOD_INSTANT_NOODLES_CUP',N'60g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'NISSIN-CUP-75G',N'Nissin Cup Noodles Seafood 75g',N'Nissin',N'FOOD_INSTANT_NOODLES_CUP',N'75g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'CENTURY-155G',N'Century Tuna Flakes in Oil 155g',N'Century Tuna',N'FOOD_CANNED_FISH',N'155g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'CENTURY-180G',N'Century Tuna Chunks in Brine 180g',N'Century Tuna',N'FOOD_CANNED_FISH',N'180g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'LIGO-155G',N'Ligo Sardines in Tomato Sauce 155g',N'Ligo',N'FOOD_CANNED_FISH',N'155g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'ARIEL-35G',N'Ariel Powder Detergent 35g',N'Ariel',N'HH_LAUNDRY_POWDER',N'35g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'ARIEL-1KG',N'Ariel Powder Detergent 1kg',N'Ariel',N'HH_LAUNDRY_POWDER',N'1000g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'TIDE-35G',N'Tide Powder Detergent 35g',N'Tide',N'HH_LAUNDRY_POWDER',N'35g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'TIDE-1KG',N'Tide Powder Detergent 1kg',N'Tide',N'HH_LAUNDRY_POWDER',N'1000g');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'DOWNY-20ML',N'Downy Fabric Softener 20ml',N'Downy',N'HH_LAUNDRY_SOFTENER',N'20ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'DOWNY-250ML',N'Downy Fabric Softener 250ml',N'Downy',N'HH_LAUNDRY_SOFTENER',N'250ml');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'MARLBORO-RED-20S',N'Marlboro Red 20s',N'Marlboro',N'TOB_CIGARETTES_REG',N'20s');
INSERT INTO ref.stg_SkuMap(SkuCode,SkuName,BrandName,CategoryCode,PackSize) VALUES(N'MARLBORO-GOLD-20S',N'Marlboro Gold 20s',N'Marlboro',N'TOB_CIGARETTES_REG',N'20s');

-- Run the upsert logic from the migration
;WITH stg AS (
    SELECT DISTINCT
        SkuCode      = LTRIM(RTRIM(SkuCode)),
        SkuName      = LTRIM(RTRIM(SkuName)),
        BrandName    = LTRIM(RTRIM(BrandName)),
        CategoryCode = NULLIF(LTRIM(RTRIM(CategoryCode)),''),
        PackSize     = NULLIF(LTRIM(RTRIM(PackSize)),'')
    FROM ref.stg_SkuMap
    WHERE LTRIM(RTRIM(SkuCode)) != ''
      AND LTRIM(RTRIM(SkuName)) != ''
      AND LTRIM(RTRIM(BrandName)) != ''
)
MERGE ref.SkuDimensions AS T
USING stg S ON T.SkuCode = S.SkuCode
WHEN MATCHED THEN UPDATE SET
     T.SkuName    = S.SkuName,
     T.BrandName  = S.BrandName,
     T.CategoryCode = S.CategoryCode,
     T.PackSize   = S.PackSize,
     T.UpdatedUtc = SYSUTCDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (SkuCode,SkuName,BrandName,CategoryCode,PackSize)
    VALUES (S.SkuCode,S.SkuName,S.BrandName,S.CategoryCode,S.PackSize);

-- Show results
SELECT sku_dimensions_total = COUNT(*) FROM ref.SkuDimensions;
SELECT sku_with_categories = COUNT(*) FROM ref.SkuDimensions WHERE CategoryCode IS NOT NULL;
SELECT TOP 10 * FROM ref.SkuDimensions ORDER BY sku_id;