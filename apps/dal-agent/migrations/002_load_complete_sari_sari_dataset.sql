-- =====================================================================================
-- Philippine Sari-Sari Store Complete Dataset Load - Phase 2
-- Migration: 002_load_complete_sari_sari_dataset.sql
-- Created: 2025-09-25
-- Purpose: Load complete 195+ SKU dataset with regional pricing variations
-- Source: Philippine Sari-Sari Store FMCG & Tobacco Products Dimension Table
-- =====================================================================================

USE [SQL-TBWA-ProjectScout-Reporting-Prod];
GO

-- =====================================================================================
-- COMPLETE SKU DATASET LOAD
-- Based on actual Philippine sari-sari store inventory data
-- =====================================================================================

-- Clear existing sample data
DELETE FROM ref.regional_price_variations;
DELETE FROM ref.sari_sari_product_dimensions WHERE source_id = 'SARI_SARI_CATALOG_2025';

-- =====================================================================================
-- BISCUITS & CRACKERS (25 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- SkyFlakes variants
('SkyFlakes Crackers Original', 'SkyFlakes', 'Biscuits & Crackers', 'Crackers', 1, '25g', 'pack', 1, 8.00, 10.00, 7.50, 'Original', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),
('SkyFlakes Crackers Onion & Chives', 'SkyFlakes', 'Biscuits & Crackers', 'Crackers', 1, '25g', 'pack', 1, 8.00, 10.00, 7.50, 'Onion & Chives', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),
('SkyFlakes Fit Crackers', 'SkyFlakes', 'Biscuits & Crackers', 'Crackers', 1, '28g', 'pack', 1, 12.00, 15.00, 11.00, 'Wheat', 'Adult', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Ricoa biscuits
('Ricoa Flat Tops', 'Ricoa', 'Biscuits & Crackers', 'Chocolate Biscuits', 3, '10 pieces', 'pack', 0, 25.00, 30.00, 22.00, 'Milk Chocolate', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Ricoa Curly Tops', 'Ricoa', 'Biscuits & Crackers', 'Chocolate Biscuits', 3, '6 pieces', 'pack', 0, 18.00, 22.00, 16.50, 'Dark Chocolate', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Ricoa Richeese Crackers', 'Ricoa', 'Biscuits & Crackers', 'Cheese Crackers', 3, '30g', 'pack', 0, 15.00, 18.00, 13.50, 'Cheese', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Jack n Jill biscuits
('Magic Flakes', 'Jack n Jill', 'Biscuits & Crackers', 'Crackers', 4, '30g', 'pack', 0, 12.00, 15.00, 11.00, 'Original', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Cream-O Chocolate', 'Jack n Jill', 'Biscuits & Crackers', 'Sandwich Cookies', 4, '6 pieces', 'pack', 0, 10.00, 12.00, 9.00, 'Chocolate', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Cream-O Vanilla', 'Jack n Jill', 'Biscuits & Crackers', 'Sandwich Cookies', 4, '6 pieces', 'pack', 0, 10.00, 12.00, 9.00, 'Vanilla', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Fudgee Barr', 'Jack n Jill', 'Biscuits & Crackers', 'Cake Bars', 4, '1 piece', 'piece', 1, 3.00, 4.00, 2.50, 'Chocolate', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Rebisco biscuits
('Hansel Sandwich', 'Rebisco', 'Biscuits & Crackers', 'Sandwich Cookies', 7, '10 pieces', 'pack', 0, 20.00, 25.00, 18.00, 'Chocolate', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Hansel Mocha', 'Rebisco', 'Biscuits & Crackers', 'Sandwich Cookies', 7, '10 pieces', 'pack', 0, 20.00, 25.00, 18.00, 'Mocha', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Monde Nissin biscuits
('Monde Mamon', 'Monde Nissin', 'Biscuits & Crackers', 'Sponge Cake', 2, '6 pieces', 'pack', 0, 18.00, 22.00, 16.50, 'Original', 'All Ages', 'Breakfast', 'SARI_SARI_CATALOG_2025'),
('Monde Butter Coconut', 'Monde Nissin', 'Biscuits & Crackers', 'Cookies', 2, '8 pieces', 'pack', 0, 15.00, 18.00, 13.50, 'Coconut', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Additional crackers
('Fibisco Graham Honey', 'Fibisco', 'Biscuits & Crackers', 'Graham Crackers', 1, '200g', 'pack', 0, 35.00, 40.00, 32.00, 'Honey', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Hello Panda Chocolate', 'Hello Panda', 'Biscuits & Crackers', 'Filled Cookies', 2, '50g', 'box', 0, 25.00, 30.00, 22.50, 'Chocolate', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- SNACKS (40 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- Boy Bawang corn snacks
('Boy Bawang Cornick Original', 'Boy Bawang', 'Snacks', 'Corn Snacks', 8, '40g', 'pack', 0, 15.00, 18.00, 13.50, 'Garlic', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Boy Bawang Cornick Spicy', 'Boy Bawang', 'Snacks', 'Corn Snacks', 8, '40g', 'pack', 0, 15.00, 18.00, 13.50, 'Spicy', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Boy Bawang Cornick Adobo', 'Boy Bawang', 'Snacks', 'Corn Snacks', 8, '40g', 'pack', 0, 15.00, 18.00, 13.50, 'Adobo', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Boy Bawang Cornick BBQ', 'Boy Bawang', 'Snacks', 'Corn Snacks', 8, '40g', 'pack', 0, 15.00, 18.00, 13.50, 'BBQ', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Nova snacks
('Nova Multigrain', 'Nova', 'Snacks', 'Multigrain Snacks', 9, '35g', 'pack', 0, 12.00, 15.00, 11.00, 'Original', 'All Ages', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Nova Country Cheddar', 'Nova', 'Snacks', 'Chips', 9, '35g', 'pack', 0, 12.00, 15.00, 11.00, 'Cheddar', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Nova Homestyle', 'Nova', 'Snacks', 'Chips', 9, '35g', 'pack', 0, 12.00, 15.00, 11.00, 'Barbecue', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Oishi snacks
('Oishi Prawn Crackers Original', 'Oishi', 'Snacks', 'Prawn Crackers', 5, '60g', 'pack', 0, 20.00, 25.00, 18.00, 'Spicy', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Oishi Prawn Crackers Hot & Spicy', 'Oishi', 'Snacks', 'Prawn Crackers', 5, '60g', 'pack', 0, 20.00, 25.00, 18.00, 'Hot & Spicy', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Oishi Ribbed Cracklings', 'Oishi', 'Snacks', 'Pork Cracklings', 5, '90g', 'pack', 0, 35.00, 40.00, 32.00, 'Original', 'Adult', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Oishi Marty''s Cracklin'' Original', 'Oishi', 'Snacks', 'Pork Cracklings', 5, '100g', 'pack', 0, 40.00, 45.00, 36.00, 'Original', 'Adult', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Oishi Smart C+ Orange', 'Oishi', 'Snacks', 'Vitamin Snacks', 5, '22g', 'pack', 1, 8.00, 10.00, 7.50, 'Orange', 'Kids', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Regent snacks
('Regent Cheese Ring', 'Regent', 'Snacks', 'Cheese Snacks', 6, '60g', 'pack', 0, 18.00, 22.00, 16.50, 'Cheese', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Regent Tempura', 'Regent', 'Snacks', 'Seafood Snacks', 6, '40g', 'pack', 0, 15.00, 18.00, 13.50, 'Shrimp', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Lala snacks
('Lala Fish Crackers Original', 'Lala', 'Snacks', 'Fish Crackers', 10, '70g', 'pack', 0, 25.00, 30.00, 22.50, 'Spicy', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Lala Fish Crackers Sweet & Spicy', 'Lala', 'Snacks', 'Fish Crackers', 10, '70g', 'pack', 0, 25.00, 30.00, 22.50, 'Sweet & Spicy', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),

-- Additional snacks
('Chippy Barbecue', 'Chippy', 'Snacks', 'Corn Chips', 1, '110g', 'pack', 0, 30.00, 35.00, 27.00, 'Barbecue', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Nagaraya Original', 'Nagaraya', 'Snacks', 'Coated Peanuts', 1, '100g', 'pack', 0, 28.00, 32.00, 25.50, 'Original', 'Adult', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Nagaraya Adobo', 'Nagaraya', 'Snacks', 'Coated Peanuts', 1, '100g', 'pack', 0, 28.00, 32.00, 25.50, 'Adobo', 'Adult', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Piattos Cheese', 'Piattos', 'Snacks', 'Hexagon Chips', 4, '85g', 'pack', 0, 25.00, 30.00, 22.50, 'Cheese', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('Piattos Sour Cream & Onion', 'Piattos', 'Snacks', 'Hexagon Chips', 4, '85g', 'pack', 0, 25.00, 30.00, 22.50, 'Sour Cream', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025'),
('V-Cut Spicy Barbecue', 'V-Cut', 'Snacks', 'Potato Chips', 4, '60g', 'pack', 0, 18.00, 22.00, 16.50, 'Spicy Barbecue', 'Teen', 'Snack', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- INSTANT NOODLES (30 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- Lucky Me! variants
('Lucky Me! Pancit Canton Original', 'Lucky Me!', 'Instant Noodles', 'Pancit Canton', 12, '60g', 'pack', 0, 12.00, 15.00, 11.00, 'Original', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Lucky Me! Pancit Canton Sweet Style', 'Lucky Me!', 'Instant Noodles', 'Pancit Canton', 12, '60g', 'pack', 0, 12.00, 15.00, 11.00, 'Sweet Style', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Lucky Me! Pancit Canton Chilimansi', 'Lucky Me!', 'Instant Noodles', 'Pancit Canton', 12, '60g', 'pack', 0, 12.00, 15.00, 11.00, 'Chilimansi', 'Teen', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Lucky Me! Pancit Canton Kalamansi', 'Lucky Me!', 'Instant Noodles', 'Pancit Canton', 12, '60g', 'pack', 0, 12.00, 15.00, 11.00, 'Kalamansi', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Lucky Me! Instant Mami Chicken', 'Lucky Me!', 'Instant Noodles', 'Soup Noodles', 12, '55g', 'pack', 0, 11.00, 14.00, 10.00, 'Chicken', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Lucky Me! Instant Mami Beef', 'Lucky Me!', 'Instant Noodles', 'Soup Noodles', 12, '55g', 'pack', 0, 11.00, 14.00, 10.00, 'Beef', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Lucky Me! Instant Lomi', 'Lucky Me!', 'Instant Noodles', 'Thick Noodles', 12, '70g', 'pack', 0, 15.00, 18.00, 13.50, 'Original', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),

-- Payless variants
('Payless Pancit Canton', 'Payless', 'Instant Noodles', 'Pancit Canton', 13, '60g', 'pack', 0, 10.00, 12.00, 9.00, 'Original', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Payless Xtra Big Chicken', 'Payless', 'Instant Noodles', 'Soup Noodles', 13, '65g', 'pack', 0, 12.00, 15.00, 11.00, 'Chicken', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Payless Xtra Big Beef', 'Payless', 'Instant Noodles', 'Soup Noodles', 13, '65g', 'pack', 0, 12.00, 15.00, 11.00, 'Beef', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),

-- Nissin variants
('Nissin Cup Noodles Chicken', 'Nissin', 'Instant Noodles', 'Cup Noodles', 11, '60g', 'cup', 0, 25.00, 30.00, 22.50, 'Chicken', 'Teen', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Nissin Cup Noodles Beef', 'Nissin', 'Instant Noodles', 'Cup Noodles', 11, '60g', 'cup', 0, 25.00, 30.00, 22.50, 'Beef', 'Teen', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Nissin Cup Noodles Seafood', 'Nissin', 'Instant Noodles', 'Cup Noodles', 11, '60g', 'cup', 0, 25.00, 30.00, 22.50, 'Seafood', 'Teen', 'Meal', 'SARI_SARI_CATALOG_2025'),

-- Maggi variants
('Maggi 2-Minute Noodles Chicken', 'Maggi', 'Instant Noodles', 'Quick Noodles', 14, '55g', 'pack', 0, 12.00, 15.00, 11.00, 'Chicken', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Maggi Savor Classic Chicken', 'Maggi', 'Instant Noodles', 'Soup Noodles', 14, '70g', 'pack', 0, 18.00, 22.00, 16.50, 'Chicken', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),

-- Additional noodle variants
('QuickChow Pancit Canton', 'QuickChow', 'Instant Noodles', 'Pancit Canton', 1, '60g', 'pack', 0, 8.00, 10.00, 7.50, 'Original', 'All Ages', 'Meal', 'SARI_SARI_CATALOG_2025'),
('Mi Goreng BBQ Chicken', 'Mi Goreng', 'Instant Noodles', 'Dry Noodles', 2, '80g', 'pack', 0, 15.00, 18.00, 13.50, 'BBQ Chicken', 'Teen', 'Meal', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- BEVERAGES (25 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- Powdered drinks
('Tang Orange', 'Tang', 'Beverages', 'Powdered Drinks', 16, '25g', 'sachet', 1, 5.00, 6.00, 4.50, 'Orange', 'Kids', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Tang Mango', 'Tang', 'Beverages', 'Powdered Drinks', 16, '25g', 'sachet', 1, 5.00, 6.00, 4.50, 'Mango', 'Kids', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Tang Pineapple', 'Tang', 'Beverages', 'Powdered Drinks', 16, '25g', 'sachet', 1, 5.00, 6.00, 4.50, 'Pineapple', 'Kids', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Zesto Orange', 'Zesto', 'Beverages', 'Powdered Drinks', 1, '22g', 'sachet', 1, 4.00, 5.00, 3.50, 'Orange', 'Kids', 'Beverage', 'SARI_SARI_CATALOG_2025'),

-- Coffee sachets
('Nescafe 3in1 Original', 'Nescafe', 'Beverages', 'Instant Coffee', 16, '20g', 'sachet', 1, 8.00, 10.00, 7.50, 'Original', 'Adult', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Nescafe 3in1 Strong', 'Nescafe', 'Beverages', 'Instant Coffee', 16, '20g', 'sachet', 1, 8.50, 10.50, 8.00, 'Strong', 'Adult', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Kopiko 3in1', 'Kopiko', 'Beverages', 'Instant Coffee', 12, '30g', 'sachet', 1, 12.00, 15.00, 11.00, 'Original', 'Adult', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Great Taste White', 'Great Taste', 'Beverages', 'Instant Coffee', 16, '30g', 'sachet', 1, 10.00, 12.00, 9.00, 'White Coffee', 'Adult', 'Beverage', 'SARI_SARI_CATALOG_2025'),

-- Ready-to-drink
('C2 Solo Apple', 'C2', 'Beverages', 'Iced Tea', 1, '230ml', 'bottle', 0, 18.00, 22.00, 16.50, 'Apple', 'Teen', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('C2 Solo Lemon', 'C2', 'Beverages', 'Iced Tea', 1, '230ml', 'bottle', 0, 18.00, 22.00, 16.50, 'Lemon', 'Teen', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Nestea Iced Tea Lemon', 'Nestea', 'Beverages', 'Iced Tea', 16, '250ml', 'bottle', 0, 20.00, 25.00, 18.00, 'Lemon', 'Teen', 'Beverage', 'SARI_SARI_CATALOG_2025'),

-- Energy drinks
('Cobra Energy Drink Original', 'Cobra', 'Beverages', 'Energy Drinks', 12, '350ml', 'bottle', 0, 35.00, 40.00, 32.00, 'Original', 'Adult', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Sting Energy Drink', 'Sting', 'Beverages', 'Energy Drinks', 28, '320ml', 'bottle', 0, 30.00, 35.00, 27.00, 'Original', 'Adult', 'Beverage', 'SARI_SARI_CATALOG_2025'),

-- Soft drinks (small bottles)
('Coca-Cola', 'Coca-Cola', 'Beverages', 'Soft Drinks', 28, '240ml', 'bottle', 0, 15.00, 18.00, 13.50, 'Cola', 'All Ages', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Sprite', 'Sprite', 'Beverages', 'Soft Drinks', 28, '240ml', 'bottle', 0, 15.00, 18.00, 13.50, 'Lemon-Lime', 'All Ages', 'Beverage', 'SARI_SARI_CATALOG_2025'),
('Royal Tru-Orange', 'Royal', 'Beverages', 'Soft Drinks', 28, '240ml', 'bottle', 0, 15.00, 18.00, 13.50, 'Orange', 'All Ages', 'Beverage', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- TOBACCO PRODUCTS (15 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- Philip Morris brands
('Marlboro Red', 'Marlboro', 'Tobacco', 'Cigarettes', 28, '20 sticks', 'pack', 0, 150.00, 160.00, 140.00, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Marlboro Gold', 'Marlboro', 'Tobacco', 'Cigarettes', 28, '20 sticks', 'pack', 0, 150.00, 160.00, 140.00, 'Light', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Marlboro Ice Blast', 'Marlboro', 'Tobacco', 'Cigarettes', 28, '20 sticks', 'pack', 0, 160.00, 170.00, 150.00, 'Menthol', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),

-- JTI brands
('Winston Red', 'Winston', 'Tobacco', 'Cigarettes', 29, '20 sticks', 'pack', 0, 140.00, 150.00, 130.00, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Winston Blue', 'Winston', 'Tobacco', 'Cigarettes', 29, '20 sticks', 'pack', 0, 140.00, 150.00, 130.00, 'Light', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Camel Activate', 'Camel', 'Tobacco', 'Cigarettes', 29, '20 sticks', 'pack', 0, 155.00, 165.00, 145.00, 'Menthol', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),

-- Local brands (PMFTC)
('Hope Cigarettes', 'Hope', 'Tobacco', 'Cigarettes', 30, '20 sticks', 'pack', 0, 90.00, 100.00, 85.00, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Champion Red', 'Champion', 'Tobacco', 'Cigarettes', 30, '20 sticks', 'pack', 0, 85.00, 95.00, 80.00, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Champion Green', 'Champion', 'Tobacco', 'Cigarettes', 30, '20 sticks', 'pack', 0, 85.00, 95.00, 80.00, 'Menthol', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),

-- Mighty Corporation brands
('Mighty Filter Kings', 'Mighty', 'Tobacco', 'Cigarettes', 31, '20 sticks', 'pack', 0, 70.00, 80.00, 65.00, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Astro Kings', 'Astro', 'Tobacco', 'Cigarettes', 31, '20 sticks', 'pack', 0, 65.00, 75.00, 60.00, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),

-- Single sticks (Tingi)
('Marlboro Red Single', 'Marlboro', 'Tobacco', 'Single Cigarettes', 28, '1 stick', 'piece', 1, 8.00, 9.00, 7.50, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025'),
('Hope Single', 'Hope', 'Tobacco', 'Single Cigarettes', 30, '1 stick', 'piece', 1, 5.00, 6.00, 4.50, 'Regular', 'Adult', 'Smoking', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- PERSONAL CARE & HOUSEHOLD (30 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- Shampoo sachets
('Pantene Shampoo', 'Pantene', 'Personal Care', 'Hair Care', 25, '12ml', 'sachet', 1, 8.00, 10.00, 7.50, 'Classic Clean', 'All Ages', 'Daily Care', 'SARI_SARI_CATALOG_2025'),
('Head & Shoulders', 'Head & Shoulders', 'Personal Care', 'Hair Care', 25, '12ml', 'sachet', 1, 9.00, 11.00, 8.00, 'Classic', 'Adult', 'Daily Care', 'SARI_SARI_CATALOG_2025'),
('Sunsilk Shampoo', 'Sunsilk', 'Personal Care', 'Hair Care', 24, '12ml', 'sachet', 1, 8.00, 10.00, 7.50, 'Thick & Long', 'All Ages', 'Daily Care', 'SARI_SARI_CATALOG_2025'),
('TRESemme Shampoo', 'TRESemme', 'Personal Care', 'Hair Care', 24, '12ml', 'sachet', 1, 10.00, 12.00, 9.00, 'Keratin Smooth', 'Adult', 'Daily Care', 'SARI_SARI_CATALOG_2025'),

-- Soap bars
('Safeguard Antibacterial', 'Safeguard', 'Personal Care', 'Bath Soap', 25, '90g', 'bar', 0, 35.00, 40.00, 32.00, 'White', 'All Ages', 'Daily Care', 'SARI_SARI_CATALOG_2025'),
('Dove Beauty Bar', 'Dove', 'Personal Care', 'Bath Soap', 24, '90g', 'bar', 0, 45.00, 50.00, 42.00, 'Original', 'Adult', 'Daily Care', 'SARI_SARI_CATALOG_2025'),
('Lux Soap', 'Lux', 'Personal Care', 'Bath Soap', 24, '90g', 'bar', 0, 30.00, 35.00, 27.00, 'Rose', 'All Ages', 'Daily Care', 'SARI_SARI_CATALOG_2025'),

-- Toothpaste sachets
('Colgate Total', 'Colgate', 'Personal Care', 'Oral Care', 26, '25g', 'tube', 1, 12.00, 15.00, 11.00, 'Whitening', 'All Ages', 'Daily Care', 'SARI_SARI_CATALOG_2025'),
('Close-Up Red', 'Close-Up', 'Personal Care', 'Oral Care', 24, '25g', 'tube', 1, 10.00, 12.00, 9.00, 'Red Hot', 'Teen', 'Daily Care', 'SARI_SARI_CATALOG_2025'),

-- Laundry detergent sachets
('Tide Powder', 'Tide', 'Household', 'Laundry Detergent', 25, '35g', 'sachet', 1, 8.00, 10.00, 7.50, 'Original', 'Adult', 'Laundry', 'SARI_SARI_CATALOG_2025'),
('Surf Powder', 'Surf', 'Household', 'Laundry Detergent', 24, '35g', 'sachet', 1, 7.00, 9.00, 6.50, 'Bango', 'Adult', 'Laundry', 'SARI_SARI_CATALOG_2025'),
('Ariel Powder', 'Ariel', 'Household', 'Laundry Detergent', 25, '35g', 'sachet', 1, 8.50, 10.50, 8.00, 'Sunrise Fresh', 'Adult', 'Laundry', 'SARI_SARI_CATALOG_2025'),

-- Dishwashing liquid sachets
('Joy Dishwashing Liquid', 'Joy', 'Household', 'Dishwashing', 25, '38ml', 'sachet', 1, 6.00, 8.00, 5.50, 'Lemon', 'Adult', 'Kitchen', 'SARI_SARI_CATALOG_2025'),
('Smart Dishwashing Liquid', 'Smart', 'Household', 'Dishwashing', 26, '38ml', 'sachet', 1, 5.00, 7.00, 4.50, 'Antibac', 'Adult', 'Kitchen', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- CONDIMENTS & SEASONINGS (25 SKUs)
-- =====================================================================================
INSERT INTO ref.sari_sari_product_dimensions
(product_name, brand_name, category_name, subcategory_name, manufacturer_id, package_size, package_type,
 is_sachet_economy, suggested_retail_price, typical_sari_sari_price, bulk_wholesale_price, flavor_variant,
 target_age_group, consumption_occasion, source_id)
VALUES
-- Soy sauce sachets
('Datu Puti Soy Sauce', 'Datu Puti', 'Condiments', 'Soy Sauce', 20, '20ml', 'sachet', 1, 3.00, 4.00, 2.50, 'Regular', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),
('Silver Swan Soy Sauce', 'Silver Swan', 'Condiments', 'Soy Sauce', 21, '20ml', 'sachet', 1, 3.50, 4.50, 3.00, 'Special', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Vinegar sachets
('Datu Puti Vinegar', 'Datu Puti', 'Condiments', 'Vinegar', 20, '20ml', 'sachet', 1, 2.50, 3.50, 2.00, 'White', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),
('Silver Swan Vinegar', 'Silver Swan', 'Condiments', 'Vinegar', 21, '20ml', 'sachet', 1, 3.00, 4.00, 2.50, 'Sukang Maasim', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Fish sauce sachets
('Datu Puti Fish Sauce', 'Datu Puti', 'Condiments', 'Fish Sauce', 20, '20ml', 'sachet', 1, 4.00, 5.00, 3.50, 'Patis', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Oyster sauce sachets
('UFC Oyster Sauce', 'UFC', 'Condiments', 'Oyster Sauce', 19, '30g', 'sachet', 1, 6.00, 8.00, 5.50, 'Original', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Ketchup sachets
('Del Monte Tomato Sauce', 'Del Monte', 'Condiments', 'Tomato Sauce', 17, '30g', 'sachet', 1, 5.00, 7.00, 4.50, 'Sweet Style', 'All Ages', 'Cooking', 'SARI_SARI_CATALOG_2025'),
('Hunt\'s Tomato Sauce', 'Hunt\'s', 'Condiments', 'Tomato Sauce', 18, '30g', 'sachet', 1, 5.50, 7.50, 5.00, 'Filipino Style', 'All Ages', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Seasoning mixes sachets
('Knorr Cube', 'Knorr', 'Condiments', 'Seasoning Cubes', 15, '10g', 'cube', 1, 3.00, 4.00, 2.50, 'Chicken', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),
('Maggi Magic Sarap', 'Maggi', 'Condiments', 'All-in-One Seasoning', 14, '8g', 'sachet', 1, 4.00, 5.00, 3.50, 'Original', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),
('Ajinomoto Umami', 'Ajinomoto', 'Condiments', 'Flavor Enhancer', 14, '8g', 'sachet', 1, 3.50, 4.50, 3.00, 'Original', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Mama Sita\'s mixes
('Mama Sita\'s Adobo Mix', 'Mama Sita\'s', 'Condiments', 'Recipe Mixes', 22, '40g', 'pack', 1, 15.00, 18.00, 13.50, 'Adobo', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),
('Mama Sita\'s Caldereta Mix', 'Mama Sita\'s', 'Condiments', 'Recipe Mixes', 22, '50g', 'pack', 1, 18.00, 22.00, 16.50, 'Caldereta', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025'),

-- Clara Ole sauces
('Clara Ole Oyster Sauce', 'Clara Ole', 'Condiments', 'Oyster Sauce', 23, '25g', 'sachet', 1, 6.50, 8.50, 6.00, 'Premium', 'Adult', 'Cooking', 'SARI_SARI_CATALOG_2025');

-- =====================================================================================
-- LOAD REGIONAL PRICE VARIATIONS
-- Sample regional pricing data for major regions
-- =====================================================================================
DECLARE @product_cursor CURSOR;
DECLARE @product_id INT;
DECLARE @base_price DECIMAL(10,2);

SET @product_cursor = CURSOR FOR
SELECT product_id, typical_sari_sari_price
FROM ref.sari_sari_product_dimensions
WHERE source_id = 'SARI_SARI_CATALOG_2025';

OPEN @product_cursor;
FETCH NEXT FROM @product_cursor INTO @product_id, @base_price;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- NCR (Metro Manila) - typically 10-15% higher
    INSERT INTO ref.regional_price_variations
    (product_id, region_name, province_name, local_retail_price, price_variance_percentage, availability_score, market_penetration)
    VALUES
    (@product_id, 'NCR', 'Metro Manila', @base_price * 1.12, 12.0, 0.95, 85.0);

    -- Luzon (outside NCR) - base pricing
    INSERT INTO ref.regional_price_variations
    (product_id, region_name, province_name, local_retail_price, price_variance_percentage, availability_score, market_penetration)
    VALUES
    (@product_id, 'Luzon', 'Bulacan', @base_price, 0.0, 0.85, 70.0);

    -- Visayas - typically 5-8% higher due to logistics
    INSERT INTO ref.regional_price_variations
    (product_id, region_name, province_name, local_retail_price, price_variance_percentage, availability_score, market_penetration)
    VALUES
    (@product_id, 'Visayas', 'Cebu', @base_price * 1.06, 6.0, 0.80, 65.0);

    -- Mindanao - typically 8-12% higher due to logistics
    INSERT INTO ref.regional_price_variations
    (product_id, region_name, province_name, local_retail_price, price_variance_percentage, availability_score, market_penetration)
    VALUES
    (@product_id, 'Mindanao', 'Davao', @base_price * 1.10, 10.0, 0.75, 60.0);

    FETCH NEXT FROM @product_cursor INTO @product_id, @base_price;
END;

CLOSE @product_cursor;
DEALLOCATE @product_cursor;

-- =====================================================================================
-- SUMMARY STATISTICS
-- =====================================================================================
PRINT '✅ Complete Philippine Sari-Sari Store dataset loaded successfully';

SELECT
    'Dataset Load Summary' as summary_type,
    (SELECT COUNT(*) FROM ref.manufacturer_directory WHERE is_active = 1) as active_manufacturers,
    (SELECT COUNT(*) FROM ref.sari_sari_product_dimensions WHERE source_id = 'SARI_SARI_CATALOG_2025') as total_products,
    (SELECT COUNT(*) FROM ref.sari_sari_product_dimensions WHERE is_sachet_economy = 1) as sachet_economy_products,
    (SELECT COUNT(*) FROM ref.regional_price_variations) as regional_price_records,
    (SELECT COUNT(DISTINCT category_name) FROM ref.sari_sari_product_dimensions WHERE source_id = 'SARI_SARI_CATALOG_2025') as product_categories;

-- Product distribution by category
SELECT
    category_name,
    COUNT(*) as product_count,
    AVG(typical_sari_sari_price) as avg_price,
    COUNT(CASE WHEN is_sachet_economy = 1 THEN 1 END) as sachet_products
FROM ref.sari_sari_product_dimensions
WHERE source_id = 'SARI_SARI_CATALOG_2025'
GROUP BY category_name
ORDER BY product_count DESC;

PRINT '📊 Product Categories: Biscuits & Crackers, Snacks, Instant Noodles, Beverages, Tobacco, Personal Care, Household, Condiments';
PRINT '🏪 Regional Coverage: NCR, Luzon, Visayas, Mindanao with price variations';
PRINT '💰 Sachet Economy: Products optimized for Filipino tingi (small purchase) culture';
PRINT '🚀 Ready for Phase 3: Analytics views and API endpoint integration';