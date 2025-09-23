#!/bin/bash
set -euo pipefail

echo "☁️ Running dbt for Azure SQL target..."

# Export credentials from environment
export AZURE_USERNAME="${AZURE_USERNAME}"
export AZURE_PASSWORD="${AZURE_PASSWORD}"

# Run dbt commands
cd scout-dbt

# Install dependencies
dbt deps --target azure

# Run models
dbt run --target azure --select bronze
dbt run --target azure --select silver
dbt run --target azure --select gold

# Run tests
dbt test --target azure

# Generate docs
dbt docs generate --target azure

echo "✅ Azure SQL dbt run complete"
