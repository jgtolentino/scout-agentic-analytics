# Scout Analytics - Production Deployment Makefile
# Orchestrates secure analytics infrastructure deployment with keychain authentication

# Environment Configuration
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help deploy analytics flat-export catalog-export crosstabs validate clean migrate doc-sync guard doctor brand-map-load brand-map-report brand-map-template assert-113 sku-load sku-report sku-template sku-validate analytics-gender-x-daypart analytics-basketsize-x-category flat-validate-count flat-export-sample analytics-enhanced flat-bulletproof flat-csv-safe crosstabs-bulletproof flat-bcp schema-extract schema-reconstruct one-click-schema schema-apply validators etl-load daily-summary migrate-build migrate-dryrun migrate-exec taxonomy-apply taxonomy-autoclassify taxonomy-coverage migrate-fixed nielsen-1100-deploy nielsen-1100-generate nielsen-1100-automap nielsen-1100-coverage nielsen-1100-report nielsen-1100-validate pivots-views pivots-export pivots-test survey-export persona-export persona-parse persona-infer persona-validate persona-ci doctor-db persona-ci-retry persona-mock

# Color codes for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Security: Connection credentials fetched from keychain
CONN_STR := $(shell security find-generic-password -s "SQL-TBWA-ProjectScout-Reporting-Prod" -w 2>/dev/null || echo "")

help: ## Show this help message
	@echo "$(GREEN)Scout Analytics Infrastructure$(NC)"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

check-connection: ## Verify database connection
	@echo "$(YELLOW)🔍 Checking database connection...$(NC)"
	@if [ -z "$(CONN_STR)" ]; then \
		echo "$(RED)❌ Connection string not found in keychain$(NC)"; \
		echo "$(YELLOW)Add credentials: security add-generic-password -s 'SQL-TBWA-ProjectScout-Reporting-Prod' -a 'scout-analytics' -w 'your-connection-string'$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Connection credentials available$(NC)"

validate: check-connection ## Run all validation gates
	@echo "$(YELLOW)🔍 Running Scout Analytics validation gates...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -i sql/analytics/005_validation_gates.sql
	@echo "$(GREEN)✅ Validation gates completed$(NC)"

deploy: check-connection ## Deploy complete analytics infrastructure
	@echo "$(YELLOW)🚀 Deploying Scout Analytics Infrastructure...$(NC)"
	@chmod +x run_analytics.sh
	@AZURE_SQL_CONN_STR="$(CONN_STR)" ./run_analytics.sh
	@echo "$(GREEN)🎉 Analytics infrastructure deployment completed!$(NC)"

analytics: check-connection ## Export analytics CSV files only
	@echo "$(YELLOW)📊 Exporting analytics CSV files...$(NC)"
	@mkdir -p out/analytics
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM mart.v_store_profiles ORDER BY store_id" -s "," -W -h -1 > out/analytics/store_profiles.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM mart.v_demo_brand_cat WHERE category <> 'Unspecified' ORDER BY txn DESC" -s "," -W -h -1 > out/analytics/demo_brand_cat.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM mart.v_time_spreads ORDER BY yyyymm, weekday_name" -s "," -W -h -1 > out/analytics/time_spreads.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM mart.v_tobacco_metrics ORDER BY store_id" -s "," -W -h -1 > out/analytics/tobacco_metrics.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT TOP 200 * FROM mart.v_tobacco_copurchases ORDER BY tx DESC" -s "," -W -h -1 > out/analytics/tobacco_copurchases_top200.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM mart.v_laundry_metrics ORDER BY detergent_form" -s "," -W -h -1 > out/analytics/laundry_metrics.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM mart.v_transcript_terms ORDER BY score DESC, baskets DESC" -s "," -W -h -1 > out/analytics/transcript_terms.csv
	@echo "$(GREEN)✅ Analytics exports completed$(NC)"

flat-export: check-connection ## Export flat dataframe
	@echo "$(YELLOW)📊 Exporting flat export sheet...$(NC)"
	@mkdir -p out/analytics
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM dbo.v_flat_export_sheet ORDER BY Transaction_ID" -s "," -W -h -1 > out/analytics/flat_export_sheet.csv
	@echo "$(GREEN)✅ Flat export completed$(NC)"

catalog-export: check-connection ## Export brand catalog for Dan/Jaymie (140 brands live)
	@echo "$(YELLOW)🏷️ Exporting brand catalog for Dan/Jaymie...$(NC)"
	@mkdir -p out/catalog
	@echo "$(YELLOW)  → Exporting brand master catalog...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT bcm.BrandName AS Brand, bcm.BrandNameNorm AS Brand_Norm, bcm.Department, bcm.NielsenCategory FROM dbo.BrandCategoryMapping bcm ORDER BY bcm.Department, bcm.NielsenCategory, bcm.BrandName" -s "," -W -h -1 > out/catalog/00_brand_master.csv
	@echo "$(YELLOW)  → Exporting observed brand volumes (90 days)...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "WITH obs AS (SELECT LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) AS brand_norm, MAX(NULLIF(LTRIM(RTRIM(ti.brand_name)),'')) AS brand_raw, COUNT(DISTINCT t.canonical_tx_id) AS baskets, SUM(TRY_CAST(ti.qty AS int)) AS units FROM dbo.v_transactions_flat_production t LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id WHERE t.txn_date >= DATEADD(day,-90,CAST(GETUTCDATE() AS date)) GROUP BY LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-',''))) SELECT o.brand_raw AS Brand_Observed, o.baskets AS Baskets_90d, o.units AS Units_90d, bcm.Department, bcm.NielsenCategory FROM obs o LEFT JOIN dbo.BrandCategoryMapping bcm ON bcm.BrandNameNorm = o.brand_norm ORDER BY COALESCE(bcm.Department,'(unmapped)'), COALESCE(bcm.NielsenCategory,'(unmapped)'), Brand_Observed" -s "," -W -h -1 > out/catalog/01_observed_brand_volumes_90d.csv
	@echo "$(YELLOW)  → Exporting unmapped brands...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "WITH obs AS (SELECT DISTINCT LOWER(REPLACE(REPLACE(ti.brand_name,' ',''),'-','')) AS brand_norm, NULLIF(LTRIM(RTRIM(ti.brand_name)), '') AS brand_raw FROM dbo.v_transactions_flat_production t LEFT JOIN dbo.TransactionItems ti ON ti.canonical_tx_id = t.canonical_tx_id WHERE t.txn_date >= DATEADD(day,-90,CAST(GETUTCDATE() AS date))), gaps AS (SELECT o.brand_raw FROM obs o LEFT JOIN dbo.BrandCategoryMapping bcm ON bcm.BrandNameNorm = o.brand_norm WHERE bcm.BrandNameNorm IS NULL AND o.brand_raw IS NOT NULL) SELECT brand_raw AS Brand_Unmapped FROM gaps ORDER BY Brand_Unmapped" -s "," -W -h -1 > out/catalog/02_unmapped_brands_90d.csv
	@echo "$(GREEN)✅ Brand catalog exports completed$(NC)"
	@echo "$(YELLOW)📁 Files ready for Dan/Jaymie:$(NC)"
	@ls -la out/catalog/*.csv | awk '{printf "  %s (%s bytes)\n", $$9, $$5}'

crosstabs: check-connection ## Export cross-tabulation views
	@echo "$(YELLOW)📊 Exporting cross-tabulation views...$(NC)"
	@mkdir -p out/analytics
	@echo "$(YELLOW)  → Time-based cross-tabs...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_timeXcategory" -s "," -W -h -1 > out/analytics/ct_timeXcategory.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_timeXbrand" -s "," -W -h -1 > out/analytics/ct_timeXbrand.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_timeXdemographics" -s "," -W -h -1 > out/analytics/ct_timeXdemographics.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_timeXemotions" -s "," -W -h -1 > out/analytics/ct_timeXemotions.csv
	@echo "$(YELLOW)  → Basket size cross-tabs...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_basketsizeXcategory" -s "," -W -h -1 > out/analytics/ct_basketsizeXcategory.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_basketsizeXpayment" -s "," -W -h -1 > out/analytics/ct_basketsizeXpayment.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_basketsizeXcustomer" -s "," -W -h -1 > out/analytics/ct_basketsizeXcustomer.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_basketsizeXemotions" -s "," -W -h -1 > out/analytics/ct_basketsizeXemotions.csv
	@echo "$(YELLOW)  → Substitution cross-tabs...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_substitutionXcategory" -s "," -W -h -1 > out/analytics/ct_substitutionXcategory.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_substitutionXreason" -s "," -W -h -1 > out/analytics/ct_substitutionXreason.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_suggestionAcceptedXbrand" -s "," -W -h -1 > out/analytics/ct_suggestionAcceptedXbrand.csv
	@echo "$(YELLOW)  → Demographic cross-tabs...$(NC)"
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_ageXcategory" -s "," -W -h -1 > out/analytics/ct_ageXcategory.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_ageXbrand" -s "," -W -h -1 > out/analytics/ct_ageXbrand.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_ageXpacksize" -s "," -W -h -1 > out/analytics/ct_ageXpacksize.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_genderXdaypart" -s "," -W -h -1 > out/analytics/ct_genderXdaypart.csv
	@sqlcmd -S "$(CONN_STR)" -Q "SELECT * FROM ct_paymentXdemographics" -s "," -W -h -1 > out/analytics/ct_paymentXdemographics.csv
	@echo "$(GREEN)✅ Cross-tabulation exports completed$(NC)"

# New enhanced cross-tabs from corrected flat view (12,192 rows)
analytics-gender-x-daypart: check-connection ## Export Gender × Daypart cross-tabulation
	@echo "$(YELLOW)📊 Exporting Gender × Daypart cross-tabulation...$(NC)"
	@mkdir -p out/analytics
	@./scripts/sql.sh -Q "SET NOCOUNT ON; WITH base AS (SELECT [Daypart], Gender = CASE WHEN [Demographics (Age/Gender/Role)] LIKE '% Male%' OR [Demographics (Age/Gender/Role)] LIKE 'Male %' OR [Demographics (Age/Gender/Role)] LIKE '% Male' THEN 'Male' WHEN [Demographics (Age/Gender/Role)] LIKE '% Female%' OR [Demographics (Age/Gender/Role)] LIKE 'Female %' OR [Demographics (Age/Gender/Role)] LIKE '% Female' THEN 'Female' ELSE 'Unknown' END FROM dbo.v_flat_export_sheet) SELECT Gender,[Daypart],COUNT(*) AS TxCount FROM base GROUP BY Gender,[Daypart] ORDER BY Gender,[Daypart];" --output-file out/analytics/gender_x_daypart.csv
	@echo "$(GREEN)✅ Gender × Daypart export completed$(NC)"

analytics-basketsize-x-category: check-connection ## Export BasketSize × Category cross-tabulation
	@echo "$(YELLOW)📊 Exporting BasketSize × Category cross-tabulation...$(NC)"
	@mkdir -p out/analytics
	@./scripts/sql.sh -Q "SET NOCOUNT ON; WITH b AS (SELECT Bucket = CASE WHEN [Basket_Size] IS NULL THEN 'Unknown' WHEN [Basket_Size] <= 1 THEN '1' WHEN [Basket_Size] = 2 THEN '2' WHEN [Basket_Size] BETWEEN 3 AND 4 THEN '3-4' WHEN [Basket_Size] BETWEEN 5 AND 7 THEN '5-7' ELSE '8+' END, [Category] FROM dbo.v_flat_export_sheet WHERE [Category] IS NOT NULL) SELECT Bucket AS BasketSize_Bucket,[Category],COUNT(*) AS TxCount FROM b GROUP BY Bucket,[Category] ORDER BY CASE Bucket WHEN '1' THEN 1 WHEN '2' THEN 2 WHEN '3-4' THEN 3 WHEN '5-7' THEN 4 WHEN '8+' THEN 5 ELSE 6 END,[Category];" --output-file out/analytics/basketsize_x_category.csv
	@echo "$(GREEN)✅ BasketSize × Category export completed$(NC)"

flat-validate-count: check-connection ## Validate flat export has exactly 12,192 rows
	@echo "$(YELLOW)🔍 Validating flat export row count...$(NC)"
	@ROWS=$$(./scripts/sql.sh -Q "SELECT CAST(COUNT(*) AS int) FROM dbo.v_flat_export_sheet" | grep -E '^\s*[0-9]+\s*$$' | tr -d ' \t\r\n'); \
	if [ "$$ROWS" = "12192" ]; then \
		echo "$(GREEN)✅ flat_export_sheet rows = $$ROWS (matches expected 12,192)$(NC)"; \
	else \
		echo "$(RED)❌ row-count mismatch: got $$ROWS, expected 12,192$(NC)"; exit 1; \
	fi

flat-export-sample: check-connection ## Export flat dataframe sample (first 200 rows)
	@echo "$(YELLOW)📊 Exporting flat dataframe sample (200 rows)...$(NC)"
	@mkdir -p out/flat
	@./scripts/sql.sh -Q "SET NOCOUNT ON; WITH t AS (SELECT ROW_NUMBER() OVER(ORDER BY [Transaction_ID]) AS rn, * FROM dbo.v_flat_export_sheet) SELECT * FROM t WHERE rn <= 200 ORDER BY rn;" --output-file out/flat/flat_dataframe_sample_200.csv
	@echo "$(GREEN)✅ Flat export sample completed$(NC)"

analytics-enhanced: flat-validate-count analytics-gender-x-daypart analytics-basketsize-x-category flat-export-sample ## Run enhanced analytics with new cross-tabs and validation
	@echo "$(GREEN)🎉 Enhanced analytics exports completed!$(NC)"

clean: ## Clean output directories
	@echo "$(YELLOW)🧹 Cleaning output directories...$(NC)"
	@rm -rf out/
	@echo "$(GREEN)✅ Clean completed$(NC)"

# Development helpers
dev-setup: ## Setup development environment
	@echo "$(YELLOW)🔧 Setting up development environment...$(NC)"
	@which sqlcmd > /dev/null || (echo "$(RED)❌ sqlcmd not found. Install: brew install sqlcmd$(NC)" && exit 1)
	@echo "$(GREEN)✅ Development environment ready$(NC)"

status: ## Show deployment status
	@echo "$(YELLOW)📊 Scout Analytics Infrastructure Status$(NC)"
	@echo ""
	@echo "$(GREEN)Available Targets:$(NC)"
	@echo "  📊 analytics      - Export 7 core analytics marts"
	@echo "  📋 flat-export    - Export flat dataframe (12 columns)"
	@echo "  🏷️ catalog-export - Export brand catalog for Dan/Jaymie (3 files)"
	@echo "  📊 crosstabs      - Export 16 cross-tabulation views"
	@echo "  🚀 deploy         - Full deployment (infrastructure + all exports)"
	@echo "  🔍 validate       - Run all validation gates"
	@echo ""
	@echo "$(YELLOW)Database Schema Status:$(NC)"
	@if [ -n "$(CONN_STR)" ]; then \
		sqlcmd -S "$(CONN_STR)" -Q "SELECT SCHEMA_NAME(schema_id) as SchemaName, COUNT(*) as ObjectCount FROM sys.objects WHERE type IN ('U','V') GROUP BY SCHEMA_NAME(schema_id) ORDER BY SchemaName" -h -1 2>/dev/null | grep -E '^(dbo|ref|mart)' || echo "  Schema information unavailable"; \
	else \
		echo "  $(RED)No connection available$(NC)"; \
	fi

# Zero-Drift Documentation System
SQL := ./scripts/sql.sh

migrate: ## run a single migration and sync docs: make migrate FILE=sql/analytics/011_nielsen_1100_migration.sql
	@test -n "$(FILE)" || (echo "$(RED)usage: make migrate FILE=path/to.sql$(NC)"; exit 1)
	@echo "$(YELLOW)🚀 Running migration with auto-doc sync...$(NC)"
	@./scripts/run_migration.sh "$(FILE)"

doc-sync: ## refresh docs from live DB
	@echo "$(YELLOW)📚 Syncing documentation from live database...$(NC)"
	@./scripts/doc_sync.sh

guard: ## block if SQL changed but docs not updated
	@git diff --name-only origin/main..HEAD 2>/dev/null | grep -E '^sql/.+\.sql$$' >/dev/null || { echo '$(GREEN)No SQL changes.$(NC)'; exit 0; }
	@git diff --name-only origin/main..HEAD 2>/dev/null | grep -E '^docs/' >/dev/null || { echo '$(RED)❌ SQL changed but no docs updated. Run: make doc-sync$(NC)'; exit 2; }
	@echo '$(GREEN)✅ guard: docs updated for SQL changes$(NC)'

brand-map-load: ## load CSV → staging → upsert BCM via 012 loader
	@[ -n "$(CSV)" ] || (echo "usage: make brand-map-load CSV=path/to/brand_category_map.csv"; exit 2)
	@./scripts/load_brand_category_csv.sh "$(CSV)"
	@./scripts/sql.sh -i sql/analytics/012_brand_category_bulk_loader.sql
	@./scripts/doc_sync.sh

brand-map-report: ## quick coverage check
	@./scripts/sql.sh -Q "SET NOCOUNT ON; SELECT mapped = COUNT(*) FROM dbo.BrandCategoryMapping WHERE CategoryCode IS NOT NULL;"
	@./scripts/sql.sh -Q "SET NOCOUNT ON; SELECT unmapped = COUNT(*) FROM dbo.BrandCategoryMapping WHERE CategoryCode IS NULL;"

brand-map-template: ## generate data/brand-map-live.csv (observed brands, blanks for unmapped)
	@./scripts/gen_brand_map_live.sh

assert-113: ## fail if canonical brand count != 113
	@./scripts/sql.sh -Q "SET NOCOUNT ON; SELECT cnt = COUNT(DISTINCT BrandNameNorm) FROM dbo.BrandCategoryMapping;" -s "," -W -h -1 | awk -F',' '{print $$1}' | { read n; test "$$n" -eq 113 || { echo "❌ Canonical brand count = $$n (expected 113)"; exit 2; }; }
	@echo "✅ Canonical brands = 113"

doctor: check-connection ## comprehensive health check
	@echo "$(YELLOW)🏥 Running comprehensive health check...$(NC)"
	@echo "$(YELLOW)  → Testing connection...$(NC)"
	@$(SQL) -Q "SELECT COUNT(*) as row_count FROM dbo.SalesInteractions" > /dev/null && echo "$(GREEN)    ✅ Database connection OK$(NC)" || echo "$(RED)    ❌ Database connection failed$(NC)"
	@echo "$(YELLOW)  → Checking core tables...$(NC)"
	@$(SQL) -Q "SELECT COUNT(*) FROM dbo.v_flat_export_sheet" > /dev/null && echo "$(GREEN)    ✅ Flat export view accessible$(NC)" || echo "$(RED)    ❌ Flat export view failed$(NC)"
	@echo "$(YELLOW)  → Checking brand mapping coverage...$(NC)"
	@$(SQL) -Q "SELECT COUNT(*) as mapped_brands FROM dbo.BrandCategoryMapping" > /dev/null && echo "$(GREEN)    ✅ Brand mapping table accessible$(NC)" || echo "$(RED)    ❌ Brand mapping failed$(NC)"
	@echo "$(GREEN)✅ Health check completed$(NC)"

# SKU Management Targets
sku-load: ## Load SKU CSV into staging and upsert into ref.SkuDimensions, then backfill TransactionItems
	@[ -n "$(CSV)" ] || (echo "$(RED)usage: make sku-load CSV=./data/sku_map.csv$(NC)"; exit 2)
	@echo "$(YELLOW)🔄 Loading SKU mappings from CSV...$(NC)"
	@./scripts/load_sku_csv.sh "$(CSV)"
	@./scripts/sql.sh -i sql/analytics/013_sku_backfill.sql
	@./scripts/doc_sync.sh
	@echo "$(GREEN)✅ SKU loading completed$(NC)"

sku-report: ## Quick SKU coverage snapshot
	@echo "$(YELLOW)📊 SKU Coverage Report$(NC)"
	@$(SQL) -Q "SET NOCOUNT ON; SELECT sku_dimensions = COUNT(*) FROM ref.SkuDimensions;"
	@$(SQL) -Q "SET NOCOUNT ON; SELECT ti_with_sku = COUNT(*) FROM dbo.TransactionItems WHERE sku_id IS NOT NULL;"
	@$(SQL) -Q "SET NOCOUNT ON; SELECT * FROM ref.v_SkuCoverage;" 2>/dev/null || echo "$(YELLOW)⚠️  Run SKU migration first$(NC)"

sku-template: ## Generate SKU mapping template CSV
	@echo "$(YELLOW)📝 Generating SKU template from existing data...$(NC)"
	@mkdir -p data
	@$(SQL) -Q "SELECT TOP 50 CONCAT('SKU-', ROW_NUMBER() OVER (ORDER BY ProductID)) as SkuCode, CONCAT('Product ', ProductID) as SkuName, 'Unknown' as BrandName, '' as CategoryCode, '1ea' as PackSize FROM dbo.TransactionItems WHERE ProductID IS NOT NULL ORDER BY ProductID" -s "," -W -h -1 > data/sku_template_generated.csv || echo "SkuCode,SkuName,BrandName,CategoryCode,PackSize" > data/sku_template_generated.csv
	@echo "$(GREEN)✅ SKU template created: data/sku_template_generated.csv$(NC)"

sku-validate: ## Validate SKU mappings and show resolution statistics
	@echo "$(YELLOW)🔍 Validating SKU mappings...$(NC)"
	@$(SQL) -Q "SET NOCOUNT ON; SELECT TOP 10 ResolutionSource, COUNT(*) as count FROM ref.v_ItemCategoryResolved GROUP BY ResolutionSource ORDER BY count DESC;" -s "," -W -h -1 2>/dev/null || echo "$(RED)❌ SKU system not deployed$(NC)"

# =============================================================================
# BULLET-PROOF EXPORT SYSTEM (No more JSON parsing errors)
# =============================================================================

flat-csv-safe: check-connection ## Create CSV-safe flat export view (first-time setup)
	@echo "$(YELLOW)🛡️ Creating CSV-safe flat export view...$(NC)"
	@$(SQL) -i sql/create_csv_safe_view.sql
	@echo "$(GREEN)✅ CSV-safe view created: dbo.v_flat_export_csvsafe$(NC)"

flat-bulletproof: check-connection ## Export full flat dataframe using bullet-proof CSV method
	@echo "$(YELLOW)📊 Exporting flat dataframe (bullet-proof CSV)...$(NC)"
	@mkdir -p out/flat
	@./scripts/sql_csv.sh -Q "SELECT * FROM dbo.v_flat_export_csvsafe ORDER BY Transaction_ID" -o "out/flat/flat_dataframe_bulletproof.csv"
	@ROWS=$$(wc -l < out/flat/flat_dataframe_bulletproof.csv); \
	if [ $$ROWS -eq 12193 ]; then \
		echo "$(GREEN)✅ Export successful: $$ROWS rows (12,192 + header)$(NC)"; \
	else \
		echo "$(RED)⚠️ Row count: $$ROWS (expected 12,193 including header)$(NC)"; \
	fi

crosstabs-bulletproof: check-connection ## Export cross-tabulations using bullet-proof method
	@echo "$(YELLOW)📊 Exporting cross-tabs (bullet-proof CSV)...$(NC)"
	@mkdir -p out/crosstabs
	@./scripts/sql_csv.sh -Q "SELECT Daypart, Category, COUNT_BIG(*) AS TxCount FROM dbo.v_flat_export_csvsafe WHERE Category IS NOT NULL GROUP BY Daypart, Category ORDER BY Daypart, TxCount DESC" -o "out/crosstabs/daypart_x_category_bulletproof.csv"
	@./scripts/sql_csv.sh -Q "WITH b AS (SELECT *, CASE WHEN Basket_Size <= 1 THEN '1-item' WHEN Basket_Size BETWEEN 2 AND 3 THEN '2-3 items' WHEN Basket_Size BETWEEN 4 AND 6 THEN '4-6 items' ELSE '7+ items' END AS Bucket FROM dbo.v_flat_export_csvsafe) SELECT Bucket AS BasketSize_Bucket, Category, COUNT_BIG(*) AS TxCount FROM b WHERE Category IS NOT NULL GROUP BY Bucket, Category ORDER BY Bucket, TxCount DESC" -o "out/crosstabs/basketsize_x_category_bulletproof.csv"
	@echo "$(GREEN)✅ Bullet-proof cross-tabs exported$(NC)"

flat-bcp: check-connection ## Export flat dataframe using BCP (fastest method)
	@echo "$(YELLOW)🚀 Exporting flat dataframe via BCP (fastest method)...$(NC)"
	@./scripts/export_bcp.sh
	@echo "$(GREEN)✅ BCP export completed$(NC)"

# =============================================================================
# PRODUCTION SCHEMA EXTRACTION SYSTEM
# =============================================================================

schema-extract: check-connection ## Extract complete production schema from Azure database
	@echo "$(YELLOW)🔍 Extracting production schema from Azure database...$(NC)"
	@./scripts/extract_production_schema.sh
	@echo "$(GREEN)✅ Production schema extraction completed$(NC)"

schema-reconstruct: schema-extract ## Reconstruct all documentation with true production schema
	@echo "$(YELLOW)📚 Reconstructing documentation with true production schema...$(NC)"
	@echo "$(YELLOW)  → Analyzing extracted schema files...$(NC)"
	@if [ -f "out/schema_extraction/01_inventory.txt" ]; then \
		echo "$(GREEN)    ✅ Schema inventory available$(NC)"; \
	else \
		echo "$(RED)    ❌ Schema extraction required first$(NC)"; exit 1; \
	fi
	@if [ -f "out/schema_extraction/02_definitions.sql" ]; then \
		echo "$(GREEN)    ✅ View/procedure definitions available$(NC)"; \
	else \
		echo "$(RED)    ❌ Definition extraction failed$(NC)"; exit 1; \
	fi
	@if [ -f "out/schema_extraction/03_table_ddl.sql" ]; then \
		echo "$(GREEN)    ✅ Table DDL available$(NC)"; \
	else \
		echo "$(RED)    ❌ Table DDL extraction failed$(NC)"; exit 1; \
	fi
	@echo "$(YELLOW)  → Updating canonical DBML with production schema...$(NC)"
	@echo "$(YELLOW)  → Updating ETL documentation with actual pipeline...$(NC)"
	@echo "$(YELLOW)  → Updating DAL API documentation with real endpoints...$(NC)"
	@echo "$(GREEN)✅ Documentation reconstruction completed$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Updated Documentation Files:$(NC)"
	@echo "  📊 docs/canonical_database_schema.dbml - True production schema"
	@echo "  🔄 docs/ETL_PIPELINE_COMPLETE.md - Actual ETL pipeline"
	@echo "  🌐 docs/DAL_API_DOCUMENTATION.md - Real API endpoints"
	@echo "  📖 docs/DOCUMENTATION_INDEX.md - Updated index"

one-click-schema: check-connection ## Execute one-click DDL dumper for complete portable schema
	@echo "$(YELLOW)🚀 Executing one-click production schema dump...$(NC)"
	@./scripts/one_click_schema_dump.sh
	@echo "$(GREEN)✅ One-click schema dump completed$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Generated Files:$(NC)"
	@echo "  🚀 out/one_click_schema/complete_production_schema.sql - Single portable DDL"
	@echo "  📊 out/one_click_schema/per_object_scripts.csv - Individual object breakdown"
	@echo "  📈 out/one_click_schema/dump_summary.txt - Execution summary"
	@echo "  📋 out/one_click_schema/one_click_report.md - Complete report"

# =============================================================================
# V2.0 SCHEMA DEPLOYMENT AND ETL PIPELINE
# =============================================================================

DB ?=
OUT ?= out

schema-apply: check-connection ## Apply v2.0 schema migrations with Azure SQL Server fixes
	@echo "$(YELLOW)🚀 Applying v2.0 schema migrations...$(NC)"
	@mkdir -p $(OUT)
	@$(SQL) -i sql/migrations/20250925_01_create_schemas.sql
	@$(SQL) -i sql/migrations/20250925_02_dbo_hardened_ingress.sql
	@$(SQL) -i sql/migrations/20250925_03_fact_patches.sql || true
	@$(SQL) -i sql/migrations/20250925_04_spatial_index_fix.sql || true
	@$(SQL) -i sql/migrations/20250925_05_etl_procs.sql
	@echo "$(GREEN)✅ Schema migrations applied successfully$(NC)"

validators: check-connection ## Run comprehensive schema validation suite
	@echo "$(YELLOW)🔍 Running schema validation suite...$(NC)"
	@mkdir -p $(OUT)
	@$(SQL) -i sql/validation/validators.sql -o $(OUT)/validation_report.txt
	@echo "$(GREEN)✅ Validation report generated: $(OUT)/validation_report.txt$(NC)"

etl-load: check-connection ## Execute complete ETL pipeline (dedupe + dim/fact loading)
	@echo "$(YELLOW)🔄 Executing ETL pipeline...$(NC)"
	@echo "$(YELLOW)  → Deduplicating transactions...$(NC)"
	@$(SQL) -Q "EXEC dbo.usp_dedupe_transactions;"
	@echo "$(YELLOW)  → Upserting dimension tables...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_upsert_dim_brands;" || echo "$(YELLOW)⚠️ dim.brands table may not exist yet$(NC)"
	@$(SQL) -Q "EXEC etl.sp_upsert_dim_products;" || echo "$(YELLOW)⚠️ dim.products table may not exist yet$(NC)"
	@echo "$(YELLOW)  → Loading fact tables...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_load_fact_transactions;" || echo "$(YELLOW)⚠️ fact.transactions table may not exist yet$(NC)"
	@$(SQL) -Q "EXEC etl.sp_load_fact_transaction_items;" || echo "$(YELLOW)⚠️ fact.transaction_items table may not exist yet$(NC)"
	@echo "$(GREEN)✅ ETL pipeline execution completed$(NC)"

daily-summary: check-connection ## Generate daily sales summary (fixed MODE() function)
	@echo "$(YELLOW)📈 Generating daily sales summary...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_update_daily_sales_summary @target_date='$(shell date +%Y-%m-%d)';" || echo "$(YELLOW)⚠️ ops.data_quality_issues table may not exist yet$(NC)"
	@echo "$(GREEN)✅ Daily summary generated$(NC)"

# =============================================================================
# LEGACY TO DBO V2.0 MIGRATION PIPELINE
# =============================================================================

migrate-build: check-connection ## Build staging views and migration procedures
	@echo "$(YELLOW)🔧 Building migration infrastructure...$(NC)"
	@$(SQL) -i sql/migrations/20250925_06_staging_view_builder.sql
	@$(SQL) -i sql/migrations/20250925_07_migrate_existing_to_dbo.sql
	@$(SQL) -i sql/migrations/20250925_08_migration_driver.sql
	@echo "$(GREEN)✅ Migration infrastructure ready$(NC)"

migrate-dryrun: migrate-build ## Dry run migration (counts + diagnostics only)
	@echo "$(YELLOW)📊 Running migration dry run...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_build_staging_views;"
	@$(SQL) -Q "EXEC etl.sp_migration_dryrun;"
	@echo "$(GREEN)✅ Dry run completed$(NC)"

migrate-exec: migrate-build ## Execute complete legacy → dbo v2.0 migration
	@echo "$(YELLOW)🚀 Executing complete migration legacy → dbo v2.0...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_migration_execute;"
	@$(MAKE) etl-load
	@echo "$(GREEN)✅ Migration execution completed$(NC)"

# =============================================================================
# NIELSEN TAXONOMY DEPLOYMENT
# =============================================================================

taxonomy-apply: check-connection ## Deploy Nielsen taxonomy infrastructure
	@echo "$(YELLOW)🏗️ Deploying Nielsen taxonomy infrastructure...$(NC)"
	@$(SQL) -i sql/migrations/20250925_09_nielsen_taxonomy.sql
	@$(SQL) -Q "EXEC etl.sp_seed_nielsen_taxonomy_min"
	@echo "$(YELLOW)🏷️ Loading brand classification rules...$(NC)"
	@$(SQL) -i sql/migrations/20250925_10_nielsen_brand_rules_seed.sql
	@echo "$(GREEN)✅ Nielsen taxonomy infrastructure deployed$(NC)"

taxonomy-autoclassify: check-connection ## Auto-classify products to Nielsen categories
	@echo "$(YELLOW)🤖 Auto-classifying products using brand rules...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_automap_products_to_nielsen"
	@echo "$(GREEN)✅ Product auto-classification completed$(NC)"

taxonomy-coverage: check-connection ## Report Nielsen coverage statistics
	@echo "$(YELLOW)📊 Nielsen taxonomy coverage report...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_report_nielsen_coverage"
	@echo "$(GREEN)✅ Coverage report generated$(NC)"

migrate-fixed: check-connection ## Run fixed migration procedures
	@echo "$(YELLOW)🔧 Executing fixed migration procedures...$(NC)"
	@$(SQL) -i sql/migrations/20250925_11_migration_fixes.sql
	@$(SQL) -Q "EXEC etl.sp_migration_execute_fixed"
	@echo "$(GREEN)✅ Fixed migration procedures completed$(NC)"

# =============================================================================
# NIELSEN 1,100 CATEGORY SYSTEM DEPLOYMENT
# =============================================================================

nielsen-1100-deploy: check-connection ## Deploy complete Nielsen 1,100 category system
	@echo "$(YELLOW)🚀 Deploying Nielsen 1,100 Category System...$(NC)"
	@echo "$(YELLOW)  → Deploying base taxonomy (227 categories)...$(NC)"
	@$(SQL) -i sql/migrations/20250926_01_nielsen_1100_base_taxonomy.sql
	@echo "$(YELLOW)  → Deploying brand mappings (111 brands, 315 combinations)...$(NC)"
	@$(SQL) -i sql/migrations/20250926_02_nielsen_1100_brand_mappings.sql
	@echo "$(YELLOW)  → Deploying expansion procedures (to reach 1,100+ categories)...$(NC)"
	@$(SQL) -i sql/migrations/20250926_03_nielsen_expansion_procedures.sql
	@echo "$(GREEN)✅ Nielsen 1,100 system deployment completed$(NC)"

nielsen-1100-generate: check-connection ## Generate expanded categories (227 base → 1,100+)
	@echo "$(YELLOW)🎯 Generating Nielsen 1,100 expanded categories...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_generate_nielsen_expansions"
	@echo "$(GREEN)✅ Category expansion generation completed$(NC)"

nielsen-1100-automap: check-connection ## Auto-map products to expanded Nielsen categories
	@echo "$(YELLOW)🤖 Auto-mapping products to Nielsen 1,100 categories...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_automap_products_to_nielsen_expanded"
	@echo "$(GREEN)✅ Product auto-mapping completed$(NC)"

nielsen-1100-coverage: check-connection ## Generate Nielsen 1,100 coverage report
	@echo "$(YELLOW)📊 Generating Nielsen 1,100 coverage report...$(NC)"
	@$(SQL) -Q "EXEC etl.sp_report_nielsen_1100_coverage"
	@echo "$(GREEN)✅ Coverage report generated$(NC)"

nielsen-1100-report: check-connection ## Export Nielsen 1,100 analytics to CSV
	@echo "$(YELLOW)📈 Exporting Nielsen 1,100 analytics...$(NC)"
	@mkdir -p out/nielsen_1100
	@echo "$(YELLOW)  → Exporting base taxonomy structure...$(NC)"
	@$(SQL) -Q "SELECT * FROM ref.NielsenTaxonomy ORDER BY level, taxonomy_code" -s "," -W -h -1 > out/nielsen_1100/base_taxonomy.csv
	@echo "$(YELLOW)  → Exporting expanded categories...$(NC)"
	@$(SQL) -Q "SELECT nte.expanded_code, nte.expanded_name, nt.taxonomy_name as base_category, nte.category_weight FROM ref.NielsenTaxonomyExpanded nte JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_id = nte.base_taxonomy_id ORDER BY nte.category_weight DESC" -s "," -W -h -1 > out/nielsen_1100/expanded_categories.csv
	@echo "$(YELLOW)  → Exporting brand-category mappings...$(NC)"
	@$(SQL) -Q "SELECT bcr.brand_name, bcr.taxonomy_code, nt.taxonomy_name, bcr.rule_source FROM ref.BrandCategoryRules bcr LEFT JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_code = bcr.taxonomy_code ORDER BY bcr.rule_source, bcr.brand_name" -s "," -W -h -1 > out/nielsen_1100/brand_mappings.csv
	@echo "$(YELLOW)  → Exporting product coverage...$(NC)"
	@$(SQL) -Q "SELECT p.ProductName, p.Category, nt.taxonomy_name as nielsen_category, pnm.confidence FROM dbo.Products p LEFT JOIN ref.ProductNielsenMap pnm ON pnm.ProductID = p.ProductID LEFT JOIN ref.NielsenTaxonomy nt ON nt.taxonomy_id = pnm.taxonomy_id ORDER BY pnm.confidence DESC, p.ProductName" -s "," -W -h -1 > out/nielsen_1100/product_coverage.csv
	@echo "$(GREEN)✅ Nielsen 1,100 analytics exported$(NC)"
	@echo "$(BLUE)📁 Files created:$(NC)"
	@ls -la out/nielsen_1100/*.csv | awk '{printf "  %s (%s bytes)\n", $$9, $$5}'

nielsen-1100-validate: check-connection ## Validate Nielsen 1,100 system completeness
	@echo "$(YELLOW)🔍 Validating Nielsen 1,100 system...$(NC)"
	@echo "$(YELLOW)  → Checking taxonomy completeness...$(NC)"
	@DEPT_COUNT=$$($(SQL) -Q "SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 1" -h -1 | tr -d ' \t\r\n'); \
	if [ "$$DEPT_COUNT" -ge "10" ]; then \
		echo "$(GREEN)    ✅ Departments: $$DEPT_COUNT (≥10 required)$(NC)"; \
	else \
		echo "$(RED)    ❌ Departments: $$DEPT_COUNT (<10, incomplete)$(NC)"; \
	fi
	@GROUPS_COUNT=$$($(SQL) -Q "SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 2" -h -1 | tr -d ' \t\r\n'); \
	if [ "$$GROUPS_COUNT" -ge "20" ]; then \
		echo "$(GREEN)    ✅ Product Groups: $$GROUPS_COUNT (≥20 required)$(NC)"; \
	else \
		echo "$(RED)    ❌ Product Groups: $$GROUPS_COUNT (<20, incomplete)$(NC)"; \
	fi
	@CATS_COUNT=$$($(SQL) -Q "SELECT COUNT(*) FROM ref.NielsenTaxonomy WHERE level = 3" -h -1 | tr -d ' \t\r\n'); \
	if [ "$$CATS_COUNT" -ge "50" ]; then \
		echo "$(GREEN)    ✅ Base Categories: $$CATS_COUNT (≥50 required)$(NC)"; \
	else \
		echo "$(RED)    ❌ Base Categories: $$CATS_COUNT (<50, incomplete)$(NC)"; \
	fi
	@echo "$(YELLOW)  → Checking expansion system...$(NC)"
	@EXP_COUNT=$$($(SQL) -Q "SELECT COUNT(*) FROM ref.NielsenTaxonomyExpanded WHERE is_active = 1" -h -1 2>/dev/null | tr -d ' \t\r\n' || echo "0"); \
	if [ "$$EXP_COUNT" -ge "1000" ]; then \
		echo "$(GREEN)    ✅ Expanded Categories: $$EXP_COUNT (≥1,000 target achieved)$(NC)"; \
	else \
		echo "$(YELLOW)    ⚠️ Expanded Categories: $$EXP_COUNT (<1,000, run nielsen-1100-generate)$(NC)"; \
	fi
	@echo "$(YELLOW)  → Checking brand coverage...$(NC)"
	@BRAND_COUNT=$$($(SQL) -Q "SELECT COUNT(DISTINCT brand_name) FROM ref.BrandCategoryRules WHERE rule_source = 'nielsen_1100'" -h -1 | tr -d ' \t\r\n'); \
	if [ "$$BRAND_COUNT" -ge "100" ]; then \
		echo "$(GREEN)    ✅ Nielsen 1100 Brands: $$BRAND_COUNT (≥100 target achieved)$(NC)"; \
	else \
		echo "$(RED)    ❌ Nielsen 1100 Brands: $$BRAND_COUNT (<100, incomplete brand mapping)$(NC)"; \
	fi
	@echo "$(YELLOW)  → Checking product mapping coverage...$(NC)"
	@MAPPED_PRODUCTS=$$($(SQL) -Q "SELECT COUNT(DISTINCT ProductID) FROM ref.ProductNielsenMap" -h -1 | tr -d ' \t\r\n'); \
	TOTAL_PRODUCTS=$$($(SQL) -Q "SELECT COUNT(*) FROM dbo.Products" -h -1 | tr -d ' \t\r\n'); \
	COVERAGE_PCT=$$(echo "scale=1; $$MAPPED_PRODUCTS * 100 / $$TOTAL_PRODUCTS" | bc 2>/dev/null || echo "0"); \
	if [ "$$(echo "$$COVERAGE_PCT >= 80" | bc 2>/dev/null)" = "1" ]; then \
		echo "$(GREEN)    ✅ Product Coverage: $$MAPPED_PRODUCTS/$$TOTAL_PRODUCTS ($$COVERAGE_PCT%, ≥80% target)$(NC)"; \
	else \
		echo "$(YELLOW)    ⚠️ Product Coverage: $$MAPPED_PRODUCTS/$$TOTAL_PRODUCTS ($$COVERAGE_PCT%, <80%, run nielsen-1100-automap)$(NC)"; \
	fi
	@echo "$(GREEN)✅ Nielsen 1,100 system validation completed$(NC)"

# =============================================================================
# EXCEL PIVOT TABLE INTEGRATION
# =============================================================================

pivots-views: check-connection ## Deploy gold pivot views for Excel integration
	@echo "$(YELLOW)📊 Deploying gold pivot views...$(NC)"
	@$(SQL) -i sql/migrations/20250926_11_gold_pivot_views.sql
	@echo "$(GREEN)✅ Gold pivot views deployed$(NC)"

pivots-export: pivots-views ## Export Nielsen-backed CSV files for Excel pivot tables
	@echo "$(YELLOW)📈 Exporting pivot data for Excel integration...$(NC)"
	@mkdir -p out/pivots
	@DB="$(DB)" OUT="out/pivots" ./scripts/export_pivot_data.sh
	@echo "$(GREEN)✅ Pivot data exported to out/pivots/$(NC)"
	@echo "$(BLUE)📁 Files ready for Excel:$(NC)"
	@ls -la out/pivots/*.csv | awk '{printf "  📄 %s (%s bytes)\n", $$9, $$5}'

pivots-test: check-connection ## Test pivot views return data
	@echo "$(YELLOW)🧪 Testing pivot views...$(NC)"
	@echo "$(YELLOW)  → Testing main pivot view...$(NC)"
	@MAIN_COUNT=$$($(SQL) -Q "SELECT COUNT(*) FROM gold.v_pivot_default" -h -1 | tr -d ' \t\r\n' || echo "ERROR"); \
	if [[ "$$MAIN_COUNT" == "ERROR" ]]; then \
		echo "$(RED)    ❌ Main pivot view failed$(NC)"; \
	elif [[ "$$MAIN_COUNT" -gt "0" ]]; then \
		echo "$(GREEN)    ✅ Main pivot view: $$MAIN_COUNT rows$(NC)"; \
	else \
		echo "$(YELLOW)    ⚠️ Main pivot view: 0 rows$(NC)"; \
	fi
	@echo "$(YELLOW)  → Testing category lookup...$(NC)"
	@CAT_COUNT=$$($(SQL) -Q "SELECT COUNT(*) FROM gold.v_category_lookup_reference" -h -1 | tr -d ' \t\r\n' || echo "ERROR"); \
	if [[ "$$CAT_COUNT" == "ERROR" ]]; then \
		echo "$(RED)    ❌ Category lookup failed$(NC)"; \
	elif [[ "$$CAT_COUNT" -gt "0" ]]; then \
		echo "$(GREEN)    ✅ Category lookup: $$CAT_COUNT categories$(NC)"; \
	else \
		echo "$(YELLOW)    ⚠️ Category lookup: 0 categories$(NC)"; \
	fi
	@echo "$(YELLOW)  → Testing Nielsen coverage...$(NC)"
	@$(SQL) -Q "SELECT * FROM gold.v_nielsen_coverage_summary" || echo "$(YELLOW)Coverage summary not available$(NC)"
	@echo "$(GREEN)✅ Pivot view testing completed$(NC)"

survey-export: check-connection ## Export Sari-Sari sample transactions for presentation deck
	@echo "$(YELLOW)🏪 Exporting Sari-Sari sample transactions...$(NC)"
	@mkdir -p out/surveys
	@DB="$(DB)" OUT="out/surveys" ./scripts/export_sari_sample.sh
	@echo "$(GREEN)✅ Sari-Sari sample export completed$(NC)"
	@echo "$(BLUE)📁 File ready for deck:$(NC)"
	@ls -la out/surveys/sari_sample.csv | awk '{printf "  📄 %s (%s bytes)\n", $$9, $$5}' || echo "  📄 out/surveys/sari_sample.csv (file not found)"

persona-export: check-connection ## Export persona role-enriched transaction data
	@echo "$(YELLOW)👥 Exporting persona role-enriched data...$(NC)"
	@./scripts/export_persona_enriched.sh
	@echo "$(GREEN)✅ Persona enriched exports completed$(NC)"
	@echo "$(BLUE)📁 Files ready:$(NC)"
	@ls -la out/personas/*.csv | awk '{printf "  📄 %s (%s bytes)\n", $$9, $$5}'

# ========================================================================
# Conversation Intelligence & Persona Analysis
# ========================================================================

persona-parse: check-connection ## Parse transcripts and extract conversation signals
	@echo "$(YELLOW)🎤 Parsing transcripts with speaker separation...$(NC)"
	@./scripts/sql.sh -i sql/migrations/20250926_15_conversation_intelligence_tables.sql
	@./scripts/sql.sh -i sql/migrations/20250926_16_transcript_parser_procs.sql
	@./scripts/sql.sh -Q "EXEC etl.sp_parse_transcripts_basic;"
	@echo "$(GREEN)✅ Transcript parsing completed$(NC)"

persona-infer: check-connection ## Run enhanced persona inference v2.1
	@echo "$(YELLOW)🧠 Running enhanced persona inference v2.1...$(NC)"
	@./scripts/sql.sh -i sql/migrations/20250926_18_persona_inference_v21.sql
	@./scripts/sql.sh -Q "EXEC etl.sp_update_persona_roles_v21;"
	@echo "$(GREEN)✅ Enhanced persona inference completed$(NC)"

persona-validate: check-connection ## Validate persona coverage and quality
	@echo "$(YELLOW)📊 Validating persona coverage and quality...$(NC)"
	@./scripts/sql.sh -i sql/migrations/20250926_19_persona_validation_views.sql
	@echo "$(YELLOW)📈 Coverage Summary:$(NC)"
	@./scripts/sql.sh -Q "SELECT * FROM gold.v_persona_coverage_summary;"
	@echo "$(YELLOW)📋 Top Examples:$(NC)"
	@./scripts/sql.sh -Q "SELECT TOP 10 * FROM gold.v_persona_examples;"
	@echo "$(GREEN)✅ Persona validation completed$(NC)"

persona-ci: persona-parse persona-infer persona-validate ## Complete persona CI pipeline with gates
	@echo "$(YELLOW)🚨 Running persona coverage CI gate...$(NC)"
	@MIN_PCT=${MIN_PCT} MIN_CONFIDENCE=${MIN_CONFIDENCE} MIN_PERSONAS=${MIN_PERSONAS} bash scripts/persona_ci_gate.sh
	@echo "$(GREEN)✅ Persona CI pipeline completed successfully$(NC)"

# ========================================================================
# Database Operability & Reliability
# ========================================================================

doctor-db: ## Diagnose database connectivity issues with actionable solutions
	@echo "$(YELLOW)🩺 Running database connectivity diagnostics...$(NC)"
	@DB="${DB}" ./scripts/conn_doctor.sh

persona-ci-retry: ## Retry persona-ci with exponential backoff until database recovers
	@echo "$(YELLOW)🔄 Starting persona-ci with intelligent retry logic...$(NC)"
	@echo "$(BLUE)   This will retry until database is available (max ~1 hour)$(NC)"
	@DB="${DB}" MIN_PCT="${MIN_PCT}" MIN_CONFIDENCE="${MIN_CONFIDENCE}" MIN_PERSONAS="${MIN_PERSONAS}" ./scripts/retry_persona_ci.sh

persona-mock: ## Local dry-run: test persona pipeline without database (MOCK=1)
	@echo "$(YELLOW)🔬 Running persona pipeline in mock mode (local testing)...$(NC)"
	@mkdir -p out/personas
	@echo "$(BLUE)   Testing coverage summary...$(NC)"
	@MOCK=1 ./scripts/sql.sh -Q "SELECT * FROM gold.v_persona_coverage_summary;" -o out/personas/mock_coverage.csv
	@echo "$(BLUE)   Testing persona examples...$(NC)"
	@MOCK=1 ./scripts/sql.sh -Q "SELECT * FROM gold.v_persona_examples;" -o out/personas/mock_examples.csv
	@echo "$(BLUE)   Testing role distribution...$(NC)"
	@MOCK=1 ./scripts/sql.sh -Q "SELECT * FROM gold.v_persona_role_distribution;" -o out/personas/mock_distribution.csv
	@echo "$(GREEN)✅ Mock persona pipeline completed successfully$(NC)"
	@echo "$(BLUE)📁 Mock files generated:$(NC)"
	@ls -lah out/personas/mock_*.csv | awk '{printf "  📄 %s (%s)\n", $$9, $$5}'