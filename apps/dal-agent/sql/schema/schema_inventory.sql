-- Scout v7 Database Schema Inventory
-- Complete inventory across all schemas with ERD generation
-- Created: 2025-09-26

-- =====================================================
-- SECTION 1: COMPLETE DATABASE INVENTORY
-- =====================================================

-- All tables across schemas
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    'TABLE' AS obj_type,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS column_count,
    (SELECT COUNT(*) FROM sys.indexes i WHERE i.object_id = t.object_id AND i.type > 0) AS index_count
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
ORDER BY s.name, t.name;

-- All views across schemas
SELECT
    s.name AS schema_name,
    v.name AS view_name,
    'VIEW' AS obj_type,
    (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = v.object_id) AS column_count
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
ORDER BY s.name, v.name;

-- All stored procedures
SELECT
    s.name AS schema_name,
    p.name AS proc_name,
    'PROC' AS obj_type,
    p.create_date,
    p.modify_date
FROM sys.procedures p
JOIN sys.schemas s ON s.schema_id = p.schema_id
ORDER BY s.name, p.name;

-- =====================================================
-- SECTION 2: COMPREHENSIVE DATA DICTIONARY
-- =====================================================

SELECT
    s.name AS schema_name,
    o.name AS object_name,
    CASE o.type
        WHEN 'U' THEN 'TABLE'
        WHEN 'V' THEN 'VIEW'
        WHEN 'P' THEN 'PROC'
        ELSE 'OTHER'
    END AS object_type,
    c.column_id,
    c.name AS column_name,
    TYPE_NAME(c.user_type_id) AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    c.is_identity,
    ISNULL(pk.is_primary_key, 0) AS is_primary_key,
    ISNULL(fk.is_foreign_key, 0) AS is_foreign_key,
    ISNULL(fk.referenced_schema, '') AS fk_references_schema,
    ISNULL(fk.referenced_table, '') AS fk_references_table,
    ISNULL(fk.referenced_column, '') AS fk_references_column,
    ISNULL(idx.index_names, '') AS indexes
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN sys.columns c ON c.object_id = o.object_id
LEFT JOIN (
    -- Primary key detection
    SELECT
        ic.object_id,
        ic.column_id,
        1 AS is_primary_key
    FROM sys.index_columns ic
    JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.is_primary_key = 1
) pk ON pk.object_id = o.object_id AND pk.column_id = c.column_id
LEFT JOIN (
    -- Foreign key detection
    SELECT
        fkc.parent_object_id AS object_id,
        fkc.parent_column_id AS column_id,
        1 AS is_foreign_key,
        rs.name AS referenced_schema,
        rt.name AS referenced_table,
        rc.name AS referenced_column
    FROM sys.foreign_key_columns fkc
    JOIN sys.objects rt ON rt.object_id = fkc.referenced_object_id
    JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
    JOIN sys.columns rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
) fk ON fk.object_id = o.object_id AND fk.column_id = c.column_id
LEFT JOIN (
    -- Index information
    SELECT
        ic.object_id,
        ic.column_id,
        STRING_AGG(i.name, ', ') AS index_names
    FROM sys.index_columns ic
    JOIN sys.indexes i ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE i.type > 0 -- Exclude heaps
    GROUP BY ic.object_id, ic.column_id
) idx ON idx.object_id = o.object_id AND idx.column_id = c.column_id
WHERE o.type IN ('U','V') -- Tables and Views only
ORDER BY s.name, o.name, c.column_id;

-- =====================================================
-- SECTION 3: FOREIGN KEY RELATIONSHIPS (ERD EDGES)
-- =====================================================

WITH fk_relationships AS (
    SELECT
        pk_schema = sch1.name,
        pk_table = t1.name,
        pk_column = c1.name,
        fk_schema = sch2.name,
        fk_table = t2.name,
        fk_column = c2.name,
        fk_name = f.name,
        f.delete_referential_action_desc,
        f.update_referential_action_desc
    FROM sys.foreign_keys f
    JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = f.object_id
    JOIN sys.tables t1 ON t1.object_id = f.referenced_object_id
    JOIN sys.schemas sch1 ON sch1.schema_id = t1.schema_id
    JOIN sys.columns c1 ON c1.object_id = t1.object_id AND c1.column_id = fkc.referenced_column_id
    JOIN sys.tables t2 ON t2.object_id = f.parent_object_id
    JOIN sys.schemas sch2 ON sch2.schema_id = t2.schema_id
    JOIN sys.columns c2 ON c2.object_id = t2.object_id AND c2.column_id = fkc.parent_column_id
)
SELECT
    CONCAT('"', pk_schema, '.', pk_table, '" -> "', fk_schema, '.', fk_table, '" [label="', fk_name, '\\n', pk_column, ' -> ', fk_column, '"];') AS erd_edge_dot,
    pk_schema,
    pk_table,
    pk_column,
    fk_schema,
    fk_table,
    fk_column,
    fk_name,
    delete_referential_action_desc,
    update_referential_action_desc
FROM fk_relationships
ORDER BY pk_schema, pk_table, fk_schema, fk_table;

-- =====================================================
-- SECTION 4: SCHEMA ANALYSIS BY CANONICAL PATTERNS
-- =====================================================

-- Schema organization analysis
SELECT
    schema_name,
    COUNT(CASE WHEN obj_type = 'TABLE' THEN 1 END) AS table_count,
    COUNT(CASE WHEN obj_type = 'VIEW' THEN 1 END) AS view_count,
    COUNT(CASE WHEN obj_type = 'PROC' THEN 1 END) AS proc_count,

    -- Canonical schema classification
    CASE
        WHEN schema_name IN ('canonical') THEN 'Canonical Facts & Contract'
        WHEN schema_name IN ('dbo') THEN 'Public Dimensions'
        WHEN schema_name IN ('intel') THEN 'Derived Analytics'
        WHEN schema_name IN ('ref') THEN 'Reference Data'
        WHEN schema_name IN ('mart') THEN 'Data Mart Views'
        WHEN schema_name IN ('dim') THEN 'Dimension Tables'
        WHEN schema_name IN ('fact') THEN 'Fact Tables'
        ELSE 'Other/Legacy'
    END AS schema_purpose
FROM (
    SELECT s.name AS schema_name, 'TABLE' AS obj_type FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
    UNION ALL
    SELECT s.name AS schema_name, 'VIEW' AS obj_type FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
    UNION ALL
    SELECT s.name AS schema_name, 'PROC' AS obj_type FROM sys.procedures p JOIN sys.schemas s ON s.schema_id = p.schema_id
) all_objects
GROUP BY schema_name
ORDER BY schema_name;

-- =====================================================
-- SECTION 5: NAMING CONVENTION ANALYSIS
-- =====================================================

-- Table naming patterns
SELECT
    schema_name,
    table_name,
    CASE
        WHEN table_name LIKE '%Fact' THEN 'Fact Table'
        WHEN table_name LIKE '%Dim' OR table_name LIKE 'Dim%' THEN 'Dimension Table'
        WHEN table_name LIKE 'v_%' THEN 'View (v_ prefix)'
        WHEN table_name LIKE '%_staging' THEN 'Staging Table'
        WHEN table_name LIKE '%_temp' THEN 'Temporary Table'
        WHEN table_name LIKE '%_log' THEN 'Log Table'
        WHEN table_name LIKE '%_history' THEN 'History Table'
        WHEN table_name LIKE '%_archive' THEN 'Archive Table'
        WHEN UPPER(table_name) = table_name THEN 'ALL CAPS'
        WHEN table_name LIKE '%[_]%' THEN 'Snake Case'
        WHEN table_name LIKE '%[A-Z]%[a-z]%[A-Z]%' THEN 'Pascal Case'
        ELSE 'Other Pattern'
    END AS naming_pattern,
    LEN(table_name) AS name_length,
    CASE WHEN table_name LIKE '% %' THEN 1 ELSE 0 END AS has_spaces
FROM (
    SELECT s.name AS schema_name, t.name AS table_name
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
) tables
ORDER BY schema_name, naming_pattern, table_name;

-- =====================================================
-- SECTION 6: RECOMMENDATIONS FOR CANONICAL STRUCTURE
-- =====================================================

-- Tables that should potentially be moved to canonical schemas
SELECT
    'Schema Recommendation' AS analysis_type,
    schema_name,
    table_name,
    CASE
        WHEN table_name LIKE '%transaction%' OR table_name LIKE '%sales%' OR table_name LIKE '%interaction%'
            THEN 'canonical schema (facts)'
        WHEN table_name LIKE '%brand%' OR table_name LIKE '%product%' OR table_name LIKE '%store%' OR table_name LIKE '%region%'
            THEN 'dbo schema (dimensions)'
        WHEN table_name LIKE '%substitution%' OR table_name LIKE '%basket%' OR table_name LIKE '%affinity%'
            THEN 'intel schema (analytics)'
        WHEN table_name LIKE '%rule%' OR table_name LIKE '%pattern%' OR table_name LIKE '%lookup%'
            THEN 'ref schema (reference)'
        ELSE 'Current schema OK'
    END AS recommended_schema,
    CASE
        WHEN table_name LIKE '% %' THEN 'Remove spaces from name'
        WHEN LEN(table_name) > 50 THEN 'Shorten table name'
        WHEN table_name NOT LIKE '%[A-Z]%' THEN 'Consider PascalCase'
        ELSE 'Naming OK'
    END AS naming_recommendation
FROM (
    SELECT s.name AS schema_name, t.name AS table_name
    FROM sys.tables t
    JOIN sys.schemas s ON s.schema_id = t.schema_id
) tables
WHERE schema_name NOT IN ('sys', 'INFORMATION_SCHEMA')
ORDER BY recommended_schema, schema_name, table_name;

PRINT 'Schema inventory and analysis completed';
PRINT 'Use ERD edges output to generate Graphviz DOT file';