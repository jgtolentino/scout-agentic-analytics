#!/usr/bin/env bash
# ========================================================
# Scout v7 Stata Pipeline Execution Script
# Unix/macOS Shell Script for Production Data Validation
# TIMEZONE: Asia/Manila (UTC+8) - All computations in Manila time
# ========================================================

set -euo pipefail

# Error handling with explicit trap
trap 'code=$?; echo "❌ [FAIL] Pipeline failed with exit code $code"; exit $code' ERR

echo ""
echo "========================================"
echo "Scout v7 Stata Pipeline Runner"
echo "========================================"
echo ""

# Check if Stata is available
if ! command -v stata &> /dev/null && ! command -v stata-mp &> /dev/null && ! command -v stata-se &> /dev/null; then
    echo "ERROR: Stata not found in PATH"
    echo "Please install Stata or add it to your PATH"
    echo "Try: stata, stata-mp, or stata-se"
    echo ""
    exit 1
fi

# Determine Stata command
STATA_CMD="stata"
if command -v stata-mp &> /dev/null; then
    STATA_CMD="stata-mp"
elif command -v stata-se &> /dev/null; then
    STATA_CMD="stata-se"
fi

echo "Using Stata command: $STATA_CMD"
echo ""

# Create directories
mkdir -p logs
mkdir -p out/scout_stata_export

echo "Directories created successfully."
echo ""

# Set default parameters (can be overridden)
FROM_DATE=${1:-"2025-06-28"}
TO_DATE=${2:-"2025-09-26"}
NCR_FOCUS=${3:-1}
QA_TOLERANCE=${4:-0.01}

echo "Pipeline Parameters:"
echo "  FROM_DATE: $FROM_DATE"
echo "  TO_DATE: $TO_DATE"
echo "  NCR_FOCUS: $NCR_FOCUS (1=NCR only, 0=all regions)"
echo "  QA_TOLERANCE: $QA_TOLERANCE"
echo ""

# Check for required credentials
echo "IMPORTANT: Ensure Scout database credentials are configured:"
echo "  - SCOUT_USER should be set (currently: scout_analytics)"
echo "  - SCOUT_PWD should be retrieved from keychain/vault"
echo ""

read -p "Continue with pipeline execution? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Pipeline execution cancelled."
    exit 0
fi

echo ""
echo "Starting Scout v7 Stata validation pipeline..."
echo ""

# Execute the Stata do-file
if ! $STATA_CMD -e do "stata/scout_pipeline.do"; then
    echo ""
    echo "ERROR: Stata pipeline execution failed!"
    echo "Check logs directory for details."
    echo ""
    exit 1
fi

echo ""
echo "========================================"
echo "Pipeline Execution Complete!"
echo "========================================"
echo ""

# List output files
echo "Output Files:"
if ls out/scout_stata_export/*.csv 2>/dev/null; then
    ls -la out/scout_stata_export/*.csv | awk '{print "  - " $9}'
fi
if ls out/scout_stata_export/*.dta 2>/dev/null; then
    ls -la out/scout_stata_export/*.dta | awk '{print "  - " $9}'
fi
echo ""

# List log files
echo "Log Files:"
if ls logs/scout_pipeline*.log 2>/dev/null; then
    ls -la logs/scout_pipeline*.log | awk '{print "  - " $9}'
fi
echo ""

# Offer to view quality report
if ls out/scout_stata_export/qa_report_*.csv 2>/dev/null; then
    echo "Quality Report Generated:"
    ls out/scout_stata_export/qa_report_*.csv | awk '{print "  - " $0}'
    echo ""
    read -p "View quality report? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v open &> /dev/null; then
            open out/scout_stata_export/qa_report_*.csv
        elif command -v xdg-open &> /dev/null; then
            xdg-open out/scout_stata_export/qa_report_*.csv
        else
            echo "Please manually open: $(ls out/scout_stata_export/qa_report_*.csv)"
        fi
    fi
fi

echo ""
echo "Pipeline validation complete. Check outputs for analysis."