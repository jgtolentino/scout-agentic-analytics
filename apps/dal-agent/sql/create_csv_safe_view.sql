-- CSV-Safe Flat Export View
-- Eliminates JSON parsing issues by cleaning text fields and removing CR/LF characters

CREATE OR ALTER VIEW dbo.v_flat_export_csvsafe AS
WITH src AS (
  SELECT
      [Transaction_ID]
    , [Transaction_Value]
    , [Basket_Size]
    , [Category]
    , [Brand]
    , [Daypart]
    , [Demographics (Age/Gender/Role)]       AS Demographics
    , [Weekday_vs_Weekend]
    , [Time of transaction]                  AS TxTime
    , [Location]
    , [Other_Products]
    , [Was_Substitution]
  FROM dbo.v_flat_export_sheet
)
SELECT
  CAST([Transaction_ID]        AS nvarchar(100))                              AS Transaction_ID,
  CAST([Transaction_Value]     AS nvarchar(100))                              AS Transaction_Value,
  CAST([Basket_Size]           AS nvarchar(100))                              AS Basket_Size,
  REPLACE(REPLACE(ISNULL([Category],''),      CHAR(13), ' '), CHAR(10),' ')   AS Category,
  REPLACE(REPLACE(ISNULL([Brand],''),         CHAR(13), ' '), CHAR(10),' ')   AS Brand,
  REPLACE(REPLACE(ISNULL([Daypart],''),       CHAR(13), ' '), CHAR(10),' ')   AS Daypart,
  REPLACE(REPLACE(ISNULL(Demographics,''),    CHAR(13), ' '), CHAR(10),' ')   AS Demographics,
  REPLACE(REPLACE(ISNULL([Weekday_vs_Weekend],''),CHAR(13),' '),CHAR(10),' ') AS Weekday_vs_Weekend,
  REPLACE(REPLACE(ISNULL(TxTime,''),          CHAR(13), ' '), CHAR(10),' ')   AS [Time of transaction],
  REPLACE(REPLACE(ISNULL([Location],''),      CHAR(13), ' '), CHAR(10),' ')   AS Location,
  REPLACE(REPLACE(ISNULL([Other_Products],''),CHAR(13),' '), CHAR(10),' ')    AS Other_Products,
  REPLACE(REPLACE(ISNULL([Was_Substitution],''),CHAR(13),' '),CHAR(10),' ')   AS Was_Substitution
FROM src;
GO

-- Validation: Should return exactly 12,192 rows
SELECT COUNT(*) AS total_rows FROM dbo.v_flat_export_csvsafe;
GO