/* =========================================================================
   SYSTEM TASK FRAMEWORK (Idempotent)
   Schemas: system.task_definitions / task_schedules / task_runs / task_events
   Procs   : sp_task_register / sp_task_start / sp_task_heartbeat / sp_task_finish / sp_task_fail / sp_task_next_due
   Views   : v_task_status / v_task_run_history
   ========================================================================= */

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='system') EXEC('CREATE SCHEMA system');

-- 1.1 Task definitions (one row per logical task)
IF OBJECT_ID('system.task_definitions','U') IS NULL
CREATE TABLE system.task_definitions(
  task_id            INT IDENTITY(1,1) PRIMARY KEY,
  task_code          SYSNAME     NOT NULL UNIQUE,   -- e.g., AUTO_SYNC_FLAT, MAIN_ETL
  task_name          NVARCHAR(200) NOT NULL,
  description        NVARCHAR(1000) NULL,
  enabled            BIT NOT NULL DEFAULT(1),
  owner              NVARCHAR(200) NULL,
  created_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- 1.2 Optional schedules (cron-like text for reference; real scheduling handled externally)
IF OBJECT_ID('system.task_schedules','U') IS NULL
CREATE TABLE system.task_schedules(
  schedule_id        INT IDENTITY(1,1) PRIMARY KEY,
  task_id            INT NOT NULL,
  schedule_cron      NVARCHAR(100) NULL,           -- doc only
  schedule_tz        NVARCHAR(50)  NULL,
  next_run_after     DATETIME2     NULL,
  created_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  updated_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_task_schedules_task FOREIGN KEY(task_id) REFERENCES system.task_definitions(task_id)
);

-- 1.3 Task runs (one row per execution attempt)
IF OBJECT_ID('system.task_runs','U') IS NULL
CREATE TABLE system.task_runs(
  run_id             BIGINT IDENTITY(1,1) PRIMARY KEY,
  task_id            INT NOT NULL,
  run_uid            UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
  start_time         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  end_time           DATETIME2 NULL,
  status             VARCHAR(20) NOT NULL DEFAULT 'RUNNING', -- RUNNING|SUCCEEDED|FAILED|CANCELLED
  pid                NVARCHAR(100) NULL,                      -- host/process info if applicable
  host               NVARCHAR(200) NULL,
  version_start      BIGINT NULL, -- change_tracking_current_version() at start
  version_end        BIGINT NULL, -- change_tracking_current_version() at end
  min_valid_version  BIGINT NULL, -- change_tracking_min_valid_version(silver.Transactions)
  rows_read          INT NULL,
  rows_written       INT NULL,
  artifacts          NVARCHAR(2000) NULL,  -- file paths or blob urls (CSV/XLSX/Parquet)
  note               NVARCHAR(MAX) NULL,
  created_at         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_task_runs_task FOREIGN KEY(task_id) REFERENCES system.task_definitions(task_id)
);

-- 1.4 Task events (append-only detailed breadcrumbs)
IF OBJECT_ID('system.task_events','U') IS NULL
CREATE TABLE system.task_events(
  event_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
  run_id             BIGINT NOT NULL,
  event_time         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  level              VARCHAR(10) NOT NULL DEFAULT 'INFO', -- INFO|WARN|ERROR|DEBUG
  message            NVARCHAR(MAX) NOT NULL,
  meta_json          NVARCHAR(MAX) NULL,
  CONSTRAINT FK_task_events_run FOREIGN KEY(run_id) REFERENCES system.task_runs(run_id)
);

-- Helpful indexes
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_task_runs_task_time' AND object_id=OBJECT_ID('system.task_runs'))
  CREATE INDEX IX_task_runs_task_time ON system.task_runs(task_id, start_time DESC) INCLUDE(status, end_time);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_task_events_run' AND object_id=OBJECT_ID('system.task_events'))
  CREATE INDEX IX_task_events_run ON system.task_events(run_id, event_time);

-- 1.5 Register task (upsert)
IF OBJECT_ID('system.sp_task_register','P') IS NULL EXEC('CREATE PROCEDURE system.sp_task_register AS RETURN;');
GO
ALTER PROCEDURE system.sp_task_register
  @task_code SYSNAME,
  @task_name NVARCHAR(200),
  @description NVARCHAR(1000)=NULL,
  @owner NVARCHAR(200)=NULL,
  @enabled BIT = 1
AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM system.task_definitions WHERE task_code=@task_code)
  BEGIN
    UPDATE system.task_definitions
      SET task_name=@task_name, description=@description, owner=@owner, enabled=@enabled, updated_at=SYSUTCDATETIME()
    WHERE task_code=@task_code;
  END
  ELSE
  BEGIN
    INSERT INTO system.task_definitions(task_code,task_name,description,owner,enabled)
    VALUES(@task_code,@task_name,@description,@owner,@enabled);
  END

  SELECT task_id FROM system.task_definitions WHERE task_code=@task_code;
END
GO

-- 1.6 Start run (captures CT versions)
IF OBJECT_ID('system.sp_task_start','P') IS NULL EXEC('CREATE PROCEDURE system.sp_task_start AS RETURN;');
GO
ALTER PROCEDURE system.sp_task_start
  @task_code SYSNAME,
  @pid NVARCHAR(100)=NULL,
  @host NVARCHAR(200)=NULL,
  @note NVARCHAR(MAX)=NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @task_id INT = (SELECT task_id FROM system.task_definitions WHERE task_code=@task_code AND enabled=1);
  IF @task_id IS NULL
    THROW 50000, 'Task not found or disabled', 1;

  DECLARE @ver BIGINT = CHANGE_TRACKING_CURRENT_VERSION();
  DECLARE @minv BIGINT = CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('silver.Transactions'));

  INSERT INTO system.task_runs(task_id,pid,host,version_start,min_valid_version,note)
  VALUES(@task_id,@pid,@host,@ver,@minv,@note);

  SELECT run_id, @task_id AS task_id, @ver AS version_start, @minv AS min_valid_version FROM system.task_runs WHERE run_id=SCOPE_IDENTITY();
END
GO

-- 1.7 Heartbeat + event
IF OBJECT_ID('system.sp_task_heartbeat','P') IS NULL EXEC('CREATE PROCEDURE system.sp_task_heartbeat AS RETURN;');
GO
ALTER PROCEDURE system.sp_task_heartbeat
  @run_id BIGINT,
  @level VARCHAR(10)='INFO',
  @message NVARCHAR(MAX),
  @meta_json NVARCHAR(MAX)=NULL
AS
BEGIN
  SET NOCOUNT ON;
  INSERT INTO system.task_events(run_id,level,message,meta_json) VALUES(@run_id,@level,@message,@meta_json);
  SELECT 1 AS ok;
END
GO

-- 1.8 Finish run (success)
IF OBJECT_ID('system.sp_task_finish','P') IS NULL EXEC('CREATE PROCEDURE system.sp_task_finish AS RETURN;');
GO
ALTER PROCEDURE system.sp_task_finish
  @run_id BIGINT,
  @rows_read INT = NULL,
  @rows_written INT = NULL,
  @artifacts NVARCHAR(2000)=NULL,
  @note NVARCHAR(MAX)=NULL
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @ver BIGINT = CHANGE_TRACKING_CURRENT_VERSION();
  UPDATE system.task_runs
    SET status='SUCCEEDED',
        end_time=SYSUTCDATETIME(),
        rows_read=@rows_read,
        rows_written=@rows_written,
        artifacts=@artifacts,
        note=COALESCE(@note,note),
        version_end=@ver
  WHERE run_id=@run_id;

  INSERT INTO system.task_events(run_id,level,message)
  VALUES(@run_id,'INFO', CONCAT('Finished. ver_end=',@ver, '; rows_read=',COALESCE(CAST(@rows_read AS NVARCHAR(20)),'-'), '; rows_written=',COALESCE(CAST(@rows_written AS NVARCHAR(20)),'-')));
END
GO

-- 1.9 Fail run
IF OBJECT_ID('system.sp_task_fail','P') IS NULL EXEC('CREATE PROCEDURE system.sp_task_fail AS RETURN;');
GO
ALTER PROCEDURE system.sp_task_fail
  @run_id BIGINT,
  @error_message NVARCHAR(MAX),
  @note NVARCHAR(MAX)=NULL
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @ver BIGINT = CHANGE_TRACKING_CURRENT_VERSION();
  UPDATE system.task_runs
    SET status='FAILED',
        end_time=SYSUTCDATETIME(),
        note=CONCAT(COALESCE(note,''),' | ',COALESCE(@note,''),' | ERR: ',@error_message),
        version_end=@ver
  WHERE run_id=@run_id;

  INSERT INTO system.task_events(run_id,level,message)
  VALUES(@run_id,'ERROR', CONCAT('Failed. ver_end=',@ver,'; ',LEFT(@error_message,1500)));
END
GO

-- 1.10 Helper: next due (informational)
IF OBJECT_ID('system.sp_task_next_due','P') IS NULL EXEC('CREATE PROCEDURE system.sp_task_next_due AS RETURN;');
GO
ALTER PROCEDURE system.sp_task_next_due
  @task_code SYSNAME
AS
BEGIN
  SET NOCOUNT ON;
  SELECT TOP 1 ts.*
  FROM system.task_schedules ts
  JOIN system.task_definitions td ON td.task_id=ts.task_id
  WHERE td.task_code=@task_code AND td.enabled=1
  ORDER BY ISNULL(ts.next_run_after,'1900-01-01') DESC;
END
GO

-- 1.11 Status views
IF OBJECT_ID('system.v_task_status','V') IS NULL EXEC('CREATE VIEW system.v_task_status AS SELECT 1 x;');
GO
CREATE OR ALTER VIEW system.v_task_status
AS
SELECT
  td.task_code, td.task_name, td.enabled, td.owner,
  last_run = (SELECT TOP 1 start_time FROM system.task_runs r WHERE r.task_id=td.task_id ORDER BY r.start_time DESC),
  last_status = (SELECT TOP 1 status FROM system.task_runs r WHERE r.task_id=td.task_id ORDER BY r.start_time DESC),
  last_note = (SELECT TOP 1 note FROM system.task_runs r WHERE r.task_id=td.task_id ORDER BY r.start_time DESC),
  last_version_end = (SELECT TOP 1 version_end FROM system.task_runs r WHERE r.task_id=td.task_id ORDER BY r.start_time DESC)
FROM system.task_definitions td;

IF OBJECT_ID('system.v_task_run_history','V') IS NULL EXEC('CREATE VIEW system.v_task_run_history AS SELECT 1 x;');
GO
CREATE OR ALTER VIEW system.v_task_run_history
AS
SELECT r.run_id, td.task_code, r.start_time, r.end_time, r.status,
       r.version_start, r.version_end, r.min_valid_version,
       r.rows_read, r.rows_written, r.artifacts, r.note
FROM system.task_runs r
JOIN system.task_definitions td ON td.task_id=r.task_id;
GO