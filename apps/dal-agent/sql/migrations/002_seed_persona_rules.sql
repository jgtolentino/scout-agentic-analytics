-- ========================================================================
-- Scout Analytics - Persona Role Inference System
-- Migration: 002_seed_persona_rules.sql
-- Purpose: Seed the 12 canonical personas for Philippine sari-sari stores
-- ========================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- ========================================================================
-- SEED 12 CANONICAL PERSONAS
-- ========================================================================

-- Clear existing rules (for idempotent reruns)
DELETE FROM ref.persona_rules WHERE rule_id > 0;

-- Reset identity
DBCC CHECKIDENT ('ref.persona_rules', RESEED, 0);

INSERT INTO ref.persona_rules (
    role_name, priority, include_terms, exclude_terms,
    must_have_categories, must_have_brands, daypart_in,
    hour_min, hour_max, min_items, min_age, max_age, gender_in, notes
) VALUES

-- 1. Student - Small baskets, school hours, snacks
('Student', 1, 'school|class|student|eskwela|klase', 'office|work|meeting',
 'Instant Noodles|Snacks|Beverages', NULL, 'Morning|Afternoon',
 6, 17, NULL, 13, 25, NULL, 'School-going individuals, typically buying snacks and drinks'),

-- 2. Office Worker - Weekday daytime, coffee + bread/biscuits
('Office Worker', 2, 'office|work|meeting|opisina|trabaho', 'school|deliver',
 'Beverages|Biscuits|Instant Coffee', 'Nescafe|Great Taste|Kopiko', 'Morning|Afternoon',
 7, 18, NULL, 22, 65, NULL, 'Corporate employees during work hours'),

-- 3. Delivery Rider/Driver - Energy drinks, water, cigarettes, load
('Delivery Rider', 1, 'deliver|rider|drive|grab|foodpanda|motor|sakay', NULL,
 'Energy Drinks|Beverages|Tobacco Products', 'Red Bull|Monster|Cobra|Marlboro', NULL,
 NULL, NULL, NULL, 18, 50, 'Male', 'Delivery personnel and drivers'),

-- 4. Parent/Caregiver - Milk, diapers, condiments, family items
('Parent', 1, 'anak|baby|bata|nanay|tatay|pampers|gatas', NULL,
 'Milk|Personal Care|Condiments', 'Nestle|Enfagrow|Pampers|Bear Brand', NULL,
 NULL, NULL, 3, 25, 65, NULL, 'Parents buying for family needs'),

-- 5. Senior Citizen - 60+ age or senior mentions, soft foods
('Senior Citizen', 1, 'lolo|lola|matanda|senior|discount', NULL,
 'Health Products|Soft Drinks|Instant Noodles', NULL, 'Morning|Afternoon',
 6, 18, NULL, 60, 99, NULL, 'Elderly customers, often with specific dietary needs'),

-- 6. Blue-Collar/Construction - Afternoon/evening, energy drinks + noodles
('Blue-Collar Worker', 2, 'construction|site|trabaho|obrero|gawa|build', 'office|school',
 'Energy Drinks|Instant Noodles|Beverages', 'Red Bull|Lucky Me|Payless', 'Afternoon|Evening',
 14, 22, NULL, 18, 55, 'Male', 'Manual laborers and construction workers'),

-- 7. Reseller/Sari-sari Refill - Multi-qty sachets, mixed FMCG basket
('Reseller', 1, 'paninda|benta|tingi|tinda|negosyo|sari', NULL,
 'Personal Care|Condiments|Instant Noodles|Snacks', NULL, NULL,
 NULL, NULL, 5, 25, 70, NULL, 'Small store owners restocking inventory'),

-- 8. Teen/Gamer - Fizzy drinks, chips, load/e-pins
('Teen Gamer', 2, 'game|gaming|ml|mobile legends|valorant|dota|laro', 'work|office',
 'Soft Drinks|Snacks|Chips', 'Coke|Pepsi|Pringles|Lays', 'Afternoon|Evening|Night',
 15, 23, NULL, 13, 21, NULL, 'Gaming enthusiasts, often buying snacks and drinks'),

-- 9. Night-Shift Worker - Late night, coffee/energy, noodles, cigarettes
('Night-Shift Worker', 1, 'shift|graveyard|night|gabi|madaling araw', NULL,
 'Energy Drinks|Instant Coffee|Instant Noodles|Tobacco Products', 'Red Bull|Nescafe|Lucky Me|Marlboro', 'Night',
 22, 5, NULL, 18, 65, NULL, 'Workers on night shifts (10pm-5am)'),

-- 10. Health/Personal-Care Focus - Dominant hygiene products
('Health-Conscious', 3, 'hygiene|health|personal care|malinis|kalinisan', NULL,
 'Personal Care|Health Products|Soap|Shampoo', 'Safeguard|Head & Shoulders|Colgate', NULL,
 NULL, NULL, NULL, 18, 65, NULL, 'Health and hygiene focused consumers'),

-- 11. Occasion/Party Buyer - Large baskets with soft drinks + snack multipacks
('Party Buyer', 2, 'party|celebration|handaan|birthday|fiesta|salu-salo', NULL,
 'Soft Drinks|Snacks|Chips', 'Coke|Sprite|Lays|Pringles', NULL,
 NULL, NULL, 8, 18, 65, NULL, 'Customers buying for parties and celebrations'),

-- 12. Farmer/Provincial Labor - Early morning, sardines/rice condiments
('Farmer', 2, 'bukid|farmer|ani|palayan|magsasaka|provincial', 'office|school',
 'Canned Goods|Rice|Condiments', 'Ligo|CDO|Datu Puti', 'Morning',
 4, 8, NULL, 25, 70, NULL, 'Agricultural workers and farmers');

-- ========================================================================
-- VERIFICATION
-- ========================================================================

DECLARE @rule_count int;
SELECT @rule_count = COUNT(*) FROM ref.persona_rules WHERE is_active = 1;

IF @rule_count = 12
BEGIN
    PRINT '✅ Successfully seeded 12 persona rules';

    -- Display summary
    SELECT role_name, priority,
           LEFT(COALESCE(include_terms, ''), 30) + '...' as sample_terms,
           notes
    FROM ref.persona_rules
    WHERE is_active = 1
    ORDER BY priority, role_name;
END
ELSE
BEGIN
    PRINT '❌ Expected 12 rules, got ' + CAST(@rule_count as varchar(10));
END

PRINT '✅ Migration 002_seed_persona_rules completed successfully';
GO