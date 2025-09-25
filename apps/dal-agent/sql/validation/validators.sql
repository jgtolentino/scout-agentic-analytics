SET NOCOUNT ON;

-- Missing column descriptions (for data dictionary)
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name='MS_Description'
WHERE ep.value IS NULL
ORDER BY 1,2,3;

-- Orphan / untrusted FKs
SELECT fk.name, SCHEMA_NAME(t.schema_id) AS schema_name, t.name AS table_name, fk.is_disabled, fk.is_not_trusted
FROM sys.foreign_keys fk
JOIN sys.tables t ON t.object_id = fk.parent_object_id
WHERE fk.is_disabled = 1 OR fk.is_not_trusted = 1;

-- Temporal integrity
SELECT SCHEMA_NAME(t.schema_id) AS schema_name, t.name AS table_name, t.temporal_type_desc
FROM sys.tables t
WHERE t.temporal_type <> 0 AND (t.history_table_id IS NULL);

-- CDC parity
SELECT SCHEMA_NAME(t.schema_id) AS schema_name, t.name AS table_name, ci.capture_instance
FROM sys.tables t
LEFT JOIN sys.capture_instances ci ON ci.object_id = t.object_id
WHERE EXISTS (SELECT 1 WHERE sys.fn_cdc_is_db_enabled() = 1)
  AND (SELECT is_tracked_by_cdc FROM sys.tables WHERE object_id=t.object_id) = 1
  AND ci.object_id IS NULL;

-- Index coverage & columnstore presence
SELECT SCHEMA_NAME(t.schema_id) AS schema_name, t.name AS table_name,
       COUNT(*) AS index_count,
       SUM(CASE WHEN i.type_desc LIKE '%COLUMNSTORE%' THEN 1 ELSE 0 END) AS columnstore_count
FROM sys.tables t
JOIN sys.indexes i ON i.object_id=t.object_id AND i.index_id>0
GROUP BY SCHEMA_NAME(t.schema_id), t.name;

-- RLS policies
SELECT p.name AS policy_name, p.is_enabled,
       OBJECT_SCHEMA_NAME(pr.target_object_id) AS target_schema,
       OBJECT_NAME(pr.target_object_id) AS target_object,
       OBJECT_SCHEMA_NAME(pr.predicate_id) AS fn_schema,
       OBJECT_NAME(pr.predicate_id) AS fn_name,
       pr.type_desc AS predicate_type
FROM sys.security_policies p
JOIN sys.security_predicates pr ON pr.security_policy_id = p.object_id
ORDER BY policy_name, target_schema, target_object;