# Stored Procedures

## cdc.sp_batchinsert_125243501

```sql
create
```

## procedure [cdc].[sp_batchinsert_125243501].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 varchar(60), @c8_1 int, @c9_1 bit, @c10_1 datetime, @.

```sql

```

## cdc.sp_batchinsert_1856725667

```sql
create
```

## procedure [cdc].[sp_batchinsert_1856725667].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 varchar(60), @c7_1 int, @c8_1 int, @c9_1 datetime, @c10_1 nvarc.

```sql

```

## cdc.sp_batchinsert_1984726123

```sql
create
```

## procedure [cdc].[sp_batchinsert_1984726123].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 nvarchar(255), @c7_1 int, @c8_1 nvarchar(50), @c9_1 nvarchar(10.

```sql

```

## cdc.sp_batchinsert_2080726465

```sql
create
```

## procedure [cdc].[sp_batchinsert_2080726465].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 nvarchar(200), @c8_1 nvarchar(100), @c9_1 nvarchar(4.

```sql

```

## cdc.sp_batchinsert_221243843

```sql
create
```

## procedure [cdc].[sp_batchinsert_221243843].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 datetime, @c8_1 float, @c9_1 int, @c10_1 nvarchar(500.

```sql

```

## cdc.sp_batchinsert_29243159

```sql
create
```

## procedure [cdc].[sp_batchinsert_29243159].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 nvarchar(200), @c8_1 nvarchar(200), @c9_1 nvarchar(100.

```sql

```

## cdc.sp_batchinsert_317244185

```sql
create
```

## procedure [cdc].[sp_batchinsert_317244185].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 int, @c8_1 int, @c9_1 int, @c10_1 float, @c11_1 float.

```sql

```

## cdc.sp_batchinsert_413244527

```sql
create
```

## procedure [cdc].[sp_batchinsert_413244527].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 nvarchar(500), @c8_1 nvarchar(500), @c9_1 bit, @c10_1.

```sql

```

## cdc.sp_batchinsert_509244869

```sql
create
```

## procedure [cdc].[sp_batchinsert_509244869].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 nvarchar(500), @c8_1 int, @c9_1 nvarchar(500), @c10_1.

```sql

```

## cdc.sp_batchinsert_605245211

```sql
create
```

## procedure [cdc].[sp_batchinsert_605245211].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 nvarchar(500), @c8_1 nvarchar(500), @c9_1 nvarchar(50.

```sql

```

## cdc.sp_batchinsert_701245553

```sql
create
```

## procedure [cdc].[sp_batchinsert_701245553].

```sql

```

## (.

```sql

```

##  @rowcount int,.

```sql

```

##   @__$start_lsn_1 binary(10), @__$seqval_1 binary(10), @__$operation_1 int, @__$update_mask_1 varbinary(128), @c6_1 int, @c7_1 int, @c8_1 nvarchar(500), @c9_1 int, @c10_1 nvarchar(.

```sql

```

## cdc.sp_batchinsert_lsn_time_mapping

```sql

```

## --.

```sql

```

## -- Name: [cdc].[sp_batchinsert_lsn_time_mapping].

```sql

```

## --.

```sql

```

## -- Description:.

```sql

```

## --.Stored procedure used internally to batch populate cdc.lsn_time_mapping table

```sql

```

## --.

```sql

```

## -- Parameters: .

```sql

```

## --   @rowcount                     int -- the number of rows to be i.

```sql

```

## cdc.sp_ins_dummy_lsn_time_mapping 

```sql

```

## --.

```sql

```

## -- Name: [cdc].[sp_ins_dummy_lsn_time_mapping].

```sql

```

## --.

```sql

```

## -- Description: append a dummy entry. A dummy entry has 0x0 for the column tran_id.

```sql

```

## --.

```sql

```

## -- Parameters: .

```sql

```

## --.@lastflushed_lsn

```sql
binary(10)			
```

## --.

```sql

```

## -- Returns:.0

```sql
success
```

## --.1   failure 

```sql

```

## .

```sql

```

## cdc.sp_ins_instance_enabling_lsn_time_mapping 

```sql

```

## --.

```sql

```

## -- Name: [cdc].[sp_ins_instance_enabling_lsn_time_mapping].

```sql

```

## --.

```sql

```

## -- Description:query change_tables for the specified capture instance and insert its start_lsn and create_date .

```sql

```

## --          into lsn_time_mapping.

```sql

```

## --.

```sql

```

## -- Parameters: .

```sql

```

## --.@chang

```sql

```

## cdc.sp_ins_lsn_time_mapping

```sql

```

## --.

```sql

```

## -- Name: [cdc].[sp_ins_lsn_time_mapping].

```sql

```

## --.

```sql

```

## -- Description:.

```sql

```

## --.Stored procedure used internally to populate cdc.lsn_time_mapping table

```sql

```

## --.

```sql

```

## -- Parameters: .

```sql

```

## --.@start_lsn

```sql
binary(10)			-- Commit lsn associated with change table entry
```

## -.

```sql

```

## cdc.sp_insdel_125243501

```sql
create
```

## procedure [cdc].[sp_insdel_125243501].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 varchar(60), @c8 int, @c9 bit, @c10 datetime, @c11 varchar(100),.

```sql

```

## @__$command_id.

```sql

```

## cdc.sp_insdel_1856725667

```sql
create
```

## procedure [cdc].[sp_insdel_1856725667].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 varchar(60), @c7 int, @c8 int, @c9 datetime, @c10 nvarchar(100), @c11 nvarchar(255), @c12 .

```sql

```

## cdc.sp_insdel_1984726123

```sql
create
```

## procedure [cdc].[sp_insdel_1984726123].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 nvarchar(255), @c7 int, @c8 nvarchar(50), @c9 nvarchar(100), @c10 datetime,.

```sql

```

## @__$command.

```sql

```

## cdc.sp_insdel_2080726465

```sql
create
```

## procedure [cdc].[sp_insdel_2080726465].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 nvarchar(200), @c8 nvarchar(100), @c9 nvarchar(400), @c10 nvarchar(400), @c11 nva.

```sql

```

## cdc.sp_insdel_221243843

```sql
create
```

## procedure [cdc].[sp_insdel_221243843].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 datetime, @c8 float, @c9 int, @c10 nvarchar(500), @c11 nvarchar(500), @c12 int, @c.

```sql

```

## cdc.sp_insdel_29243159

```sql
create
```

## procedure [cdc].[sp_insdel_29243159].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 nvarchar(200), @c8 nvarchar(200), @c9 nvarchar(100), @c10 float, @c11 float, @c12 n.

```sql

```

## cdc.sp_insdel_317244185

```sql
create
```

## procedure [cdc].[sp_insdel_317244185].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 int, @c8 int, @c9 int, @c10 float, @c11 float, @c12 datetime,.

```sql

```

## @__$command_id in.

```sql

```

## cdc.sp_insdel_413244527

```sql
create
```

## procedure [cdc].[sp_insdel_413244527].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 nvarchar(500), @c8 nvarchar(500), @c9 bit, @c10 datetime,.

```sql

```

## @__$command_id int = .

```sql

```

## cdc.sp_insdel_509244869

```sql
create
```

## procedure [cdc].[sp_insdel_509244869].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 nvarchar(500), @c8 int, @c9 nvarchar(500), @c10 datetime,.

```sql

```

## @__$command_id int = .

```sql

```

## cdc.sp_insdel_605245211

```sql
create
```

## procedure [cdc].[sp_insdel_605245211].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 nvarchar(500), @c8 nvarchar(500), @c9 nvarchar(500), @c10 nvarchar(500), @c11 nvar.

```sql

```

## cdc.sp_insdel_701245553

```sql
create
```

## procedure [cdc].[sp_insdel_701245553].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$operation int,.

```sql

```

## @__$update_mask varbinary(128) , @c6 int, @c7 int, @c8 nvarchar(500), @c9 int, @c10 nvarchar(500), @c11 nvarchar(500), @c12 nvar.

```sql

```

## cdc.sp_upd_125243501

```sql
create
```

## procedure [cdc].[sp_upd_125243501].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old varchar(60), @c8_old int, @c9_old bit, @c10_old datetime, @c11_old varchar(100), @c6_new int, @c7_n.

```sql

```

## cdc.sp_upd_1856725667

```sql
create
```

## procedure [cdc].[sp_upd_1856725667].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old varchar(60), @c7_old int, @c8_old int, @c9_old datetime, @c10_old nvarchar(100), @c11_old nvarchar(255), @c12_o.

```sql

```

## cdc.sp_upd_1984726123

```sql
create
```

## procedure [cdc].[sp_upd_1984726123].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old nvarchar(255), @c7_old int, @c8_old nvarchar(50), @c9_old nvarchar(100), @c10_old datetime, @c6_new nvarchar(25.

```sql

```

## cdc.sp_upd_2080726465

```sql
create
```

## procedure [cdc].[sp_upd_2080726465].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old nvarchar(200), @c8_old nvarchar(100), @c9_old nvarchar(400), @c10_old nvarchar(400), @c11_old nvar.

```sql

```

## cdc.sp_upd_221243843

```sql
create
```

## procedure [cdc].[sp_upd_221243843].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old datetime, @c8_old float, @c9_old int, @c10_old nvarchar(500), @c11_old nvarchar(500), @c12_old int,.

```sql

```

## cdc.sp_upd_29243159

```sql
create
```

## procedure [cdc].[sp_upd_29243159].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old nvarchar(200), @c8_old nvarchar(200), @c9_old nvarchar(100), @c10_old float, @c11_old float, @c12_ol.

```sql

```

## cdc.sp_upd_317244185

```sql
create
```

## procedure [cdc].[sp_upd_317244185].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old int, @c8_old int, @c9_old int, @c10_old float, @c11_old float, @c12_old datetime, @c6_new int, @c7_.

```sql

```

## cdc.sp_upd_413244527

```sql
create
```

## procedure [cdc].[sp_upd_413244527].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old nvarchar(500), @c8_old nvarchar(500), @c9_old bit, @c10_old datetime, @c6_new int, @c7_new nvarchar.

```sql

```

## cdc.sp_upd_509244869

```sql
create
```

## procedure [cdc].[sp_upd_509244869].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old nvarchar(500), @c8_old int, @c9_old nvarchar(500), @c10_old datetime, @c6_new int, @c7_new nvarchar.

```sql

```

## cdc.sp_upd_605245211

```sql
create
```

## procedure [cdc].[sp_upd_605245211].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old nvarchar(500), @c8_old nvarchar(500), @c9_old nvarchar(500), @c10_old nvarchar(500), @c11_old nvarc.

```sql

```

## cdc.sp_upd_701245553

```sql
create
```

## procedure [cdc].[sp_upd_701245553].

```sql

```

## (.@__$start_lsn binary(10),

```sql

```

## @__$seqval binary(10),.

```sql

```

## @__$update_mask varbinary(128) , @c6_old int, @c7_old int, @c8_old nvarchar(500), @c9_old int, @c10_old nvarchar(500), @c11_old nvarchar(500), @c12_old n.

```sql

```

## dbo.PopulateSessionMatches

```sql
CREATE PROCEDURE dbo.PopulateSessionMatches
```

## AS.

```sql

```

## BEGIN.

```sql

```

##     INSERT INTO dbo.SessionMatches (InteractionID,TranscriptID,DetectionID,MatchConfidence,TimeOffsetMs).

```sql

```

##     SELECT.

```sql

```

##       si.InteractionID,.

```sql

```

##       bt.TranscriptID,.

```sql

```

##       bvd.DetectionID,.

```sql

```

##       0.9,.

```sql

```

##       .

```sql

```

## dbo.sp_AddBrandMapping

```sql

```

## CREATE PROCEDURE dbo.sp_AddBrandMapping.

```sql

```

##     @BrandName NVARCHAR(100),.

```sql

```

##     @CategoryCode NVARCHAR(30),.

```sql

```

##     @IsMandatory BIT = 1,.

```sql

```

##     @Source NVARCHAR(50) = 'Manual Addition'.

```sql

```

## AS.

```sql

```

## BEGIN.

```sql

```

##     SET NOCOUNT ON;.

```sql

```

## .

```sql

```

##     DECLARE @CategoryId INT;.

```sql

```

## .

```sql

```

##     -- Get category ID.

```sql

```

## dbo.sp_adsbot_validation_summary

```sql
-- === Stored Procedures ===
```

## .

```sql

```

## -- AdsBot validation summary procedure.

```sql

```

## CREATE   PROCEDURE sp_adsbot_validation_summary.

```sql

```

##     @campaign_id NVARCHAR(100) = NULL,.

```sql

```

##     @start_date DATETIMEOFFSET = NULL,.

```sql

```

##     @end_date DATETIMEOFFSET = NULL.

```sql

```

## AS.

```sql

```

## BEGIN.

```sql

```

##     SET NOCOUNT .

```sql

```

## dbo.sp_create_v_transactions_flat_authoritative

```sql
CREATE PROCEDURE dbo.sp_create_v_transactions_flat_authoritative
```

## AS.

```sql

```

## BEGIN.

```sql

```

##   SET NOCOUNT ON;.

```sql

```

## .

```sql

```

##   -- Base table we summarize from.

```sql

```

##   DECLARE @t sysname = 'dbo.PayloadTransactions';.

```sql

```

##   IF OBJECT_ID(@t,'U') IS NULL.

```sql

```

##     THROW 50000, 'Required table dbo.PayloadTran.

```sql

```

## dbo.sp_create_v_transactions_flat_min

```sql
CREATE PROCEDURE dbo.sp_create_v_transactions_flat_min
```

## AS.

```sql

```

## BEGIN.

```sql

```

##   SET NOCOUNT ON;.

```sql

```

## .

```sql

```

##   IF OBJECT_ID('dbo.PayloadTransactions','U') IS NULL.

```sql

```

##     THROW 50000, 'dbo.PayloadTransactions not found', 1;.

```sql

```

## .

```sql

```

##   IF OBJECT_ID('dbo.SalesInteractions','U') IS NULL.

```sql

```

##     THROW.

```sql

```

## dbo.sp_refresh_analytics_views

```sql

```

## -- Refresh views metadata.

```sql

```

## CREATE   PROCEDURE dbo.sp_refresh_analytics_views.

```sql

```

## AS.

```sql

```

## BEGIN.

```sql

```

##   SET NOCOUNT ON;.

```sql

```

##   EXEC sys.sp_refreshview N'dbo.v_transactions_flat_production';.

```sql

```

##   EXEC sys.sp_refreshview N'dbo.v_transactions_crosstab_production';.

```sql

```

##   EXEC sys.sp_refr.

```sql

```

## dbo.sp_scout_health_check

```sql

```

## -- Health check procedure.

```sql

```

## CREATE   PROCEDURE dbo.sp_scout_health_check.

```sql

```

## AS.

```sql

```

## BEGIN.

```sql

```

##   SET NOCOUNT ON;.

```sql

```

## .

```sql

```

##   SELECT 'payload' AS src,.

```sql

```

##          COUNT(*) AS rows_total,.

```sql

```

##          SUM(CASE WHEN ISJSON(payload_json)=0 THEN 1 ELSE 0 END) AS bad_json.

```sql

```

##   FROM dbo.PayloadT.

```sql

```

## dbo.sp_upsert_device_store

```sql

```

## -- =========================================================================.

```sql

```

## -- 5) Operational Stored Procedures.

```sql

```

## -- =========================================================================.

```sql

```

## .

```sql

```

## -- Device-store mapping upsert.

```sql

```

## CREATE   PROCEDURE dbo.sp_upsert_.

```sql

```

## dbo.sp_validate_v24

```sql
/* v24 contract validator
```

##    - Verifies column ORDER, NAMES, and TYPES of dbo.v_transactions_flat_v24.

```sql

```

##    - Parity: row count equals dbo.v_transactions_flat.

```sql

```

##    - Null ratios reported (warn threshold 0.10).

```sql

```

##    - TimeOfDay format check: exactly 4 chars, ends w.

```sql

```

## dbo.sp_ValidateCanonicalTaxonomy

```sql

```

## -- Update the stored procedure with correct column names.

```sql

```

## CREATE   PROCEDURE sp_ValidateCanonicalTaxonomy.

```sql

```

## AS.

```sql

```

## BEGIN.

```sql

```

##     DECLARE @total_transactions INT;.

```sql

```

##     DECLARE @mapped_transactions INT;.

```sql

```

##     DECLARE @unmapped_transactions INT;.

```sql

```

##     DECLARE @quality_rate .

```sql

```

## dbo.VerifyScoutMigration

```sql
CREATE PROCEDURE dbo.VerifyScoutMigration
```

## AS.

```sql

```

## BEGIN.

```sql

```

##     DECLARE @errors INT = 0;.

```sql

```

##     IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name='SessionMatches')        SET @errors+=1;.

```sql

```

##     IF COL_LENGTH('dbo.SalesInteractions','TransactionDuration') IS NULL        S.

```sql

```

## gold.sp_extract_scout_dashboard_data

```sql

```

## -- Main extraction procedure.

```sql

```

## CREATE   PROCEDURE [gold].[sp_extract_scout_dashboard_data].

```sql

```

## AS.

```sql

```

## BEGIN.

```sql

```

##     SET NOCOUNT ON;.

```sql

```

## .

```sql

```

##     -- Clear existing data.

```sql

```

##     TRUNCATE TABLE gold.scout_dashboard_transactions;.

```sql

```

## .

```sql

```

##     -- Extract data with comprehensive mapping.

```sql

```

##     INS.

```sql

```

## .

```sql

```

## (49 rows affected).

```sql

```

