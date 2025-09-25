SET NOCOUNT ON;

IF COLPROPERTY(OBJECT_ID('dim.stores'), 'geometry', 'AllowsNull') IS NOT NULL
BEGIN
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='SIDX_dim_stores_geometry' AND object_id=OBJECT_ID('dim.stores'))
    CREATE SPATIAL INDEX SIDX_dim_stores_geometry ON dim.stores(geometry);
END
GO