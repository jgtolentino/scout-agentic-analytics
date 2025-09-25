# Scout Analytics - Production Deployment Makefile
# Orchestrates secure analytics infrastructure deployment with keychain authentication

# Environment Configuration
SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help deploy analytics flat-export catalog-export crosstabs validate clean migrate doc-sync guard doctor brand-map-load brand-map-report

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

doctor: check-connection ## comprehensive health check
	@echo "$(YELLOW)🏥 Running comprehensive health check...$(NC)"
	@echo "$(YELLOW)  → Testing connection...$(NC)"
	@$(SQL) -Q "SELECT COUNT(*) as row_count FROM dbo.SalesInteractions" > /dev/null && echo "$(GREEN)    ✅ Database connection OK$(NC)" || echo "$(RED)    ❌ Database connection failed$(NC)"
	@echo "$(YELLOW)  → Checking core tables...$(NC)"
	@$(SQL) -Q "SELECT COUNT(*) FROM dbo.v_flat_export_sheet" > /dev/null && echo "$(GREEN)    ✅ Flat export view accessible$(NC)" || echo "$(RED)    ❌ Flat export view failed$(NC)"
	@echo "$(YELLOW)  → Checking brand mapping coverage...$(NC)"
	@$(SQL) -Q "SELECT COUNT(*) as mapped_brands FROM dbo.BrandCategoryMapping" > /dev/null && echo "$(GREEN)    ✅ Brand mapping table accessible$(NC)" || echo "$(RED)    ❌ Brand mapping failed$(NC)"
	@echo "$(GREEN)✅ Health check completed$(NC)"