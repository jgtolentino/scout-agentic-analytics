#!/bin/bash

# ScoutCTL - Shell wrapper for the unified CLI
# Executes the Deno-based CLI with proper permissions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_PATH="$SCRIPT_DIR/scoutctl/index.ts"

# Check if Deno is available
if ! command -v deno &> /dev/null; then
    echo "Error: Deno is required to run ScoutCTL"
    echo "Install Deno: https://deno.land/#installation"
    exit 1
fi

# Execute the CLI with all arguments
exec deno run --allow-all "$CLI_PATH" "$@"