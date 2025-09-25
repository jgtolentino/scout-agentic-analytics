/* ------------------------------------------------------------------
   One-Click Production DDL Dumper
   - Captures CREATE scripts for schemas, tables (incl. PK/FK/IX),
     and programmable objects (views / procs / functions / triggers)
   - Idempotent: emits CREATE OR ALTER for code objects
   ------------------------------------------------------------------ */

SET NOCOUNT ON;

-- Ensure a home for the dumped scripts
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
  EXEC('CREATE SCHEMA ops');
GO

IF OBJECT_ID('ops.ObjectScripts','U') IS NULL
BEGIN
  CREATE TABLE ops.ObjectScripts(
    ScriptId     int IDENTITY(1,1) PRIMARY KEY,
    SchemaName   sysname     NOT NULL,
    ObjectName   sysname     NOT NULL,
    ObjectType   nvarchar(40)NOT NULL,  -- SCHEMA | TABLE | VIEW | PROC | FUNCTION | TRIGGER | INDEX | FK | PK
    Script       nvarchar(max) NOT NULL,
    GeneratedAt  datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME()
  );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DumpSchema
  @Schemas nvarchar(max) = N'dbo,gold,ref,scout,bronze',
  @Purge   bit = 1
AS
BEGIN
  SET NOCOUNT ON;

  IF @Purge = 1
    TRUNCATE TABLE ops.ObjectScripts;

  /* Parse schema list */
  DECLARE @SchemasTbl TABLE(name sysname PRIMARY KEY);
  INSERT INTO @SchemasTbl(name)
  SELECT LTRIM(RTRIM(value))
  FROM STRING_SPLIT(@Schemas, ',')
  WHERE LTRIM(RTRIM(value)) <> '';

  /* 1) SCHEMA create lines */
  INSERT ops.ObjectScripts(SchemaName,ObjectName,ObjectType,Script)
  SELECT s.name, s.name, 'SCHEMA',
         CONCAT(
           'IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = ', QUOTENAME(s.name,''''),
           ') EXEC(''CREATE SCHEMA ', QUOTENAME(s.name), ''');', CHAR(13)+CHAR(10),'GO',CHAR(13)+CHAR(10)
         )
  FROM sys.schemas s
  JOIN @SchemasTbl ss ON ss.name = s.name;

  /* 2) TABLE DDL (columns + PK + FKs + non-PK indexes) */
  ;WITH t AS (
    SELECT s.name AS schema_name, o.name AS table_name, o.object_id
    FROM sys.objects o
    JOIN sys.schemas s ON s.schema_id = o.schema_id
    JOIN @SchemasTbl ss ON ss.name = s.name
    WHERE o.type = 'U' AND o.is_ms_shipped = 0
  ),
  cols AS (
    SELECT t.*, c.column_id, c.name AS col_name,
           TYPE_NAME(c.user_type_id) AS typ, c.max_length, c.precision, c.scale,
           c.is_nullable, c.is_identity, dc.[definition] AS default_def
    FROM t
    JOIN sys.columns c ON c.object_id = t.object_id
    LEFT JOIN sys.default_constraints dc
      ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
  ),
  pkcols AS (
    SELECT t.schema_name, t.table_name, ic.key_ordinal, c.name AS col_name, k.name AS pk_name
    FROM t
    JOIN sys.key_constraints k  ON k.parent_object_id = t.object_id AND k.[type] = 'PK'
    JOIN sys.index_columns ic   ON ic.object_id = t.object_id AND ic.index_id = k.unique_index_id
    JOIN sys.columns c          ON c.object_id = ic.object_id AND c.column_id = ic.column_id
  ),
  fks AS (
    SELECT
      sch_parent.name AS schema_name, tp.name AS table_name, fk.name AS fk_name,
      sch_ref.name AS ref_schema, tr.name AS ref_table,
      STUFF((
        SELECT ',' + pc.name
        FROM sys.foreign_key_columns fkc2
        JOIN sys.columns pc ON pc.object_id=fkc2.parent_object_id AND pc.column_id=fkc2.parent_column_id
        WHERE fkc2.constraint_object_id = fk.object_id
        ORDER BY fkc2.constraint_column_id
        FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS fk_cols,
      STUFF((
        SELECT ',' + rc.name
        FROM sys.foreign_key_columns fkc2
        JOIN sys.columns rc ON rc.object_id=fkc2.referenced_object_id AND rc.column_id=fkc2.referenced_column_id
        WHERE fkc2.constraint_object_id = fk.object_id
        ORDER BY fkc2.constraint_column_id
        FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS ref_cols
    FROM sys.foreign_keys fk
    JOIN sys.tables tp          ON tp.object_id = fk.parent_object_id
    JOIN sys.schemas sch_parent ON sch_parent.schema_id = tp.schema_id
    JOIN sys.tables tr          ON tr.object_id = fk.referenced_object_id
    JOIN sys.schemas sch_ref    ON sch_ref.schema_id = tr.schema_id
    WHERE sch_parent.name IN (SELECT name FROM @SchemasTbl)
  ),
  ix AS (
    SELECT
      sch.name AS schema_name, t.name AS table_name, i.name AS index_name,
      i.is_unique, i.is_primary_key, i.type_desc,
      STUFF((
        SELECT ',' + c.name
        FROM sys.index_columns ic2
        JOIN sys.columns c ON c.object_id = ic2.object_id AND c.column_id = ic2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.is_included_column = 0
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS key_cols,
      STUFF((
        SELECT ',' + c.name
        FROM sys.index_columns ic2
        JOIN sys.columns c ON c.object_id = ic2.object_id AND c.column_id = ic2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id AND ic2.is_included_column = 1
        ORDER BY c.name
        FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,1,'') AS incl_cols
    FROM sys.indexes i
    JOIN sys.tables t    ON t.object_id = i.object_id
    JOIN sys.schemas sch ON sch.schema_id = t.schema_id
    WHERE sch.name IN (SELECT name FROM @SchemasTbl)
      AND i.is_hypothetical = 0 AND i.name IS NOT NULL
  )
  INSERT ops.ObjectScripts(SchemaName,ObjectName,ObjectType,Script)
  SELECT t.schema_name, t.table_name, 'TABLE',
         CONCAT(
           '-- TABLE ',QUOTENAME(t.schema_name),'.',QUOTENAME(t.table_name),CHAR(13)+CHAR(10),
           'IF OBJECT_ID(',QUOTENAME(t.schema_name,''''),
           '.',QUOTENAME(t.table_name,''''),
           ',''U'') IS NULL',CHAR(13)+CHAR(10),
           'BEGIN',CHAR(13)+CHAR(10),
           'CREATE TABLE ',QUOTENAME(t.schema_name),'.',QUOTENAME(t.table_name),' (',CHAR(13)+CHAR(10),
           STUFF((
             SELECT CHAR(13)+CHAR(10)+'  ' + QUOTENAME(c.col_name) + ' ' +
               CASE
                 WHEN c.typ IN ('varchar','nvarchar','char','nchar','binary','varbinary')
                   THEN c.typ + '(' + CASE WHEN c.max_length = -1 THEN 'MAX'
                                           WHEN c.typ LIKE 'n%' THEN CAST(c.max_length/2 AS varchar(10))
                                           ELSE CAST(c.max_length AS varchar(10)) END + ')'
                 WHEN c.typ IN ('decimal','numeric')
                   THEN c.typ + '('+CAST(c.[precision] AS varchar(10))+','+CAST(c.scale AS varchar(10))+')'
                 ELSE c.typ END +
               CASE WHEN c.is_identity=1 THEN ' IDENTITY(1,1)' ELSE '' END +
               CASE WHEN c.is_nullable=1 THEN ' NULL' ELSE ' NOT NULL' END +
               COALESCE(' DEFAULT '+c.default_def,'')
             FROM cols c
             WHERE c.object_id = t.object_id
             ORDER BY c.column_id
             FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,2,'')
           + CHAR(13)+CHAR(10) + ');'+CHAR(13)+CHAR(10)+'END;'+CHAR(13)+CHAR(10)+'GO'+CHAR(13)+CHAR(10),

           /* PK */
           COALESCE((
             SELECT CHAR(13)+CHAR(10)+'ALTER TABLE '+QUOTENAME(t.schema_name)+'.'+QUOTENAME(t.table_name)+
               ' ADD CONSTRAINT '+QUOTENAME(MIN(pk.pk_name))+' PRIMARY KEY ('+
               STUFF((SELECT ','+QUOTENAME(pkc.col_name)
                      FROM pkcols pkc
                      WHERE pkc.schema_name=t.schema_name AND pkc.table_name=t.table_name
                      ORDER BY pkc.key_ordinal
                      FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,'')+');'+CHAR(13)+CHAR(10)+'GO'
             FROM pkcols pk WHERE pk.schema_name=t.schema_name AND pk.table_name=t.table_name
           ), ''),

           /* FKs */
           COALESCE((
             SELECT STUFF((
               SELECT CHAR(13)+CHAR(10)+
                 'IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = '+QUOTENAME(f.fk_name,'''')+
                 ') ALTER TABLE '+QUOTENAME(f.schema_name)+'.'+QUOTENAME(f.table_name)+
                 ' ADD CONSTRAINT '+QUOTENAME(f.fk_name)+' FOREIGN KEY ('+f.fk_cols+') REFERENCES '+
                 QUOTENAME(f.ref_schema)+'.'+QUOTENAME(f.ref_table)+' ('+f.ref_cols+');'+CHAR(13)+CHAR(10)+'GO'
               FROM fks f
               WHERE f.schema_name=t.schema_name AND f.table_name=t.table_name
               FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,0,'')
           ), ''),

           /* non-PK indexes */
           COALESCE((
             SELECT STUFF((
               SELECT CHAR(13)+CHAR(10)+
                 'IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = '+QUOTENAME(i.index_name,'''')+
                 ' AND object_id = OBJECT_ID('+QUOTENAME(i.schema_name+'.'+i.table_name,'''')+')) '+
                 'CREATE ' + CASE WHEN i.is_unique=1 THEN 'UNIQUE ' ELSE '' END +
                 CASE WHEN i.type_desc='CLUSTERED' AND i.is_primary_key=0 THEN 'CLUSTERED ' ELSE 'NONCLUSTERED ' END +
                 'INDEX '+QUOTENAME(i.index_name)+' ON '+QUOTENAME(i.schema_name)+'.'+QUOTENAME(i.table_name)+
                 ' ('+i.key_cols+')' +
                 CASE WHEN i.incl_cols IS NOT NULL AND i.incl_cols<>'' THEN ' INCLUDE ('+i.incl_cols+')' ELSE '' END +
                 ';'+CHAR(13)+CHAR(10)+'GO'
               FROM ix i
               WHERE i.schema_name=t.schema_name AND i.table_name=t.table_name AND i.is_primary_key=0
               FOR XML PATH(''), TYPE).value('.','nvarchar(max)'),1,0,'')
           ), '')
         )
  FROM t;

  /* 3) Programmable objects: views, procs, functions, triggers */
  INSERT ops.ObjectScripts(SchemaName,ObjectName,ObjectType,Script)
  SELECT
    s.name, o.name,
    CASE o.type WHEN 'V' THEN 'VIEW' WHEN 'P' THEN 'PROC'
                WHEN 'FN' THEN 'FUNCTION' WHEN 'TF' THEN 'FUNCTION'
                WHEN 'IF' THEN 'FUNCTION' WHEN 'TR' THEN 'TRIGGER' ELSE o.type_desc END,
    CONCAT(
      '-- ', o.type_desc, ' ', QUOTENAME(s.name),'.',QUOTENAME(o.name), CHAR(13)+CHAR(10),
      REPLACE(REPLACE(REPLACE(REPLACE(
        REPLACE(REPLACE(REPLACE(REPLACE(
          sm.[definition],
          'CREATE VIEW','CREATE OR ALTER VIEW'),
          'Create View','CREATE OR ALTER VIEW'),
          'create view','CREATE OR ALTER VIEW'),
          'CREATE PROCEDURE','CREATE OR ALTER PROCEDURE'),
          'Create Procedure','CREATE OR ALTER PROCEDURE'),
          'create procedure','CREATE OR ALTER PROCEDURE'),
          'CREATE FUNCTION','CREATE OR ALTER FUNCTION'),
          'create function','CREATE OR ALTER FUNCTION'),
      CHAR(13)+CHAR(10),'GO',CHAR(13)+CHAR(10),CHAR(13)+CHAR(10)
    )
  FROM sys.objects o
  JOIN sys.schemas s     ON s.schema_id = o.schema_id
  JOIN @SchemasTbl ss    ON ss.name = s.name
  JOIN sys.sql_modules sm ON sm.object_id = o.object_id
  WHERE o.is_ms_shipped = 0
    AND o.type IN ('V','P','FN','TF','IF','TR');

  /* Return a small summary */
  SELECT
    COUNT(*)                       AS total_scripts,
    SUM(CASE WHEN ObjectType='TABLE' THEN 1 ELSE 0 END) AS tables,
    SUM(CASE WHEN ObjectType='VIEW' THEN 1 ELSE 0 END)  AS views,
    SUM(CASE WHEN ObjectType='PROC' THEN 1 ELSE 0 END)  AS procs
  FROM ops.ObjectScripts;
END
GO