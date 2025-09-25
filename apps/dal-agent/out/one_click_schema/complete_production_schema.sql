=== EXPORTING COMPLETE PRODUCTION DDL ===
Generating single portable SQL script...
 
FullProductionScript                                                                                                                                                                                                                                            
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA [bronze]');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'cdc') EXEC('CREATE SCHEMA [cdc]');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'c

