-- Scout Power BI Security Table Setup
-- Run this in your Fabric Warehouse to create the security assignments table

-- Create security schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS security;

-- Create the assignments table
CREATE TABLE IF NOT EXISTS security.assignments (
    email              NVARCHAR(256) NOT NULL,     -- must match USERPRINCIPALNAME() in prod
    role_name          NVARCHAR(64)  NOT NULL,     -- e.g., 'region_manager','store_manager'
    region_name        NVARCHAR(100) NULL,         -- for regional managers
    province_name      NVARCHAR(100) NULL,         -- for provincial scope
    municipality_name  NVARCHAR(100) NULL,         -- for municipal scope
    store_id           INT           NULL,          -- for store managers
    category_filter    NVARCHAR(50)  NULL,         -- 'tobacco', 'laundry', 'premium'
    is_active          BIT           NOT NULL DEFAULT 1,
    created_date       DATETIME2     DEFAULT GETDATE(),
    modified_date      DATETIME2     DEFAULT GETDATE()
);

-- Clear existing data
TRUNCATE TABLE security.assignments;

-- Insert mock users for testing
INSERT INTO security.assignments (email, role_name, region_name, store_id, category_filter) VALUES
-- Regional Managers
('maria.santos@scout.com', 'region_manager', 'NCR', NULL, NULL),
('juan.dela.cruz@scout.com', 'region_manager', 'Central Luzon', NULL, NULL),
('ana.reyes@scout.com', 'region_manager', 'Central Visayas', NULL, NULL),
('carlos.garcia@scout.com', 'region_manager', 'Davao Region', NULL, NULL),

-- Store Managers (using mock emails that match our RLS pattern)
('store.manager.1001@scout.com', 'store_manager', NULL, 1001, NULL),
('store.manager.2045@scout.com', 'store_manager', NULL, 2045, NULL),
('store.manager.3022@scout.com', 'store_manager', NULL, 3022, NULL),
('store.manager.1005@scout.com', 'store_manager', NULL, 1005, NULL),
('store.manager.2018@scout.com', 'store_manager', NULL, 2018, NULL),

-- Category Managers
('tobacco.manager@scout.com', 'category_manager', NULL, NULL, 'tobacco'),
('laundry.manager@scout.com', 'category_manager', NULL, NULL, 'laundry'),
('premium.manager@scout.com', 'category_manager', NULL, NULL, 'premium'),

-- Analysts & Leadership
('data.analyst@scout.com', 'data_analyst', NULL, NULL, NULL),
('bi.lead@scout.com', 'bi_lead', NULL, NULL, NULL),
('finance.director@scout.com', 'finance_team', NULL, NULL, NULL),
('ceo@scout.com', 'executive', NULL, NULL, NULL),

-- Dev/Test Users (for "View as" testing)
('alice@mock.local', 'region_manager', 'NCR', NULL, NULL),
('bob@mock.local', 'store_manager', NULL, 1001, NULL),
('carol@mock.local', 'category_manager', NULL, NULL, 'tobacco'),
('dave@mock.local', 'data_analyst', NULL, NULL, NULL);

-- Create indexes for performance
CREATE INDEX IX_security_assignments_email ON security.assignments(email) WHERE is_active = 1;
CREATE INDEX IX_security_assignments_role ON security.assignments(role_name) WHERE is_active = 1;

-- View to check assignments
CREATE OR ALTER VIEW security.v_active_assignments AS
SELECT
    email,
    role_name,
    region_name,
    province_name,
    municipality_name,
    store_id,
    category_filter,
    created_date
FROM security.assignments
WHERE is_active = 1;

-- Sample queries to verify data
SELECT 'Mock Users Created' AS Status, COUNT(*) AS UserCount FROM security.assignments WHERE is_active = 1;
SELECT role_name, COUNT(*) AS UserCount FROM security.assignments WHERE is_active = 1 GROUP BY role_name ORDER BY role_name;

PRINT 'Security table and mock users created successfully!';
PRINT 'Next steps:';
PRINT '1. Add security_assignments table to PBIP model';
PRINT '2. Update RLS roles to use dynamic filtering';
PRINT '3. Test with "View as" functionality in Fabric';