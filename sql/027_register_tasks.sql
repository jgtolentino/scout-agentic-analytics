-- Register all ETL tasks for Scout v7 system
-- Run after 026_task_framework.sql

-- Register core ETL tasks
EXEC system.sp_task_register
  @task_code='AUTO_SYNC_FLAT',
  @task_name='Auto Sync Flat Export',
  @description='CT-driven export of gold.vw_FlatExport to CSV/XLSX/Parquet',
  @owner='DataOps';

EXEC system.sp_task_register
  @task_code='MAIN_ETL',
  @task_name='Main Incremental ETL',
  @description='Bronze->Silver->Gold medallion pipeline with PayloadTransactions processing',
  @owner='DataOps';

EXEC system.sp_task_register
  @task_code='EXPORT_FULL',
  @task_name='Full Enriched Export',
  @description='Validated enriched dataset export in multiple formats',
  @owner='Analytics';

EXEC system.sp_task_register
  @task_code='PARITY_CHECK',
  @task_name='Flat vs Crosstab Parity',
  @description='Windowed parity validation between flat and crosstab datasets',
  @owner='QA';

EXEC system.sp_task_register
  @task_code='HEALTH_CHECK',
  @task_name='Scout Health Monitor',
  @description='Row counts, JSON health, timestamp coverage validation',
  @owner='SRE';

EXEC system.sp_task_register
  @task_code='COLUMN_MAPPER',
  @task_name='Dynamic Column Mapping',
  @description='ML-based column mapping for new Excel file structures',
  @owner='DataOps';

EXEC system.sp_task_register
  @task_code='INTERACTION_SYNC',
  @task_name='SalesInteractions Sync',
  @description='Sync SalesInteractions with PayloadTransactions using canonical IDs',
  @owner='DataOps';

EXEC system.sp_task_register
  @task_code='DASHBOARD_REFRESH',
  @task_name='Dashboard Data Refresh',
  @description='Refresh dashboard aggregations and KPI calculations',
  @owner='Analytics';

-- View current task status
SELECT * FROM system.v_task_status ORDER BY task_code;