#!/usr/bin/env bash
# CSV-safe SQL query executor with bullet-proof export flags
# Eliminates "JSON text not properly formatted" errors permanently

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
CONN_STR="$("$ROOT/scripts/conn_default.sh")"

# Default CSV export flags (bullet-proof)
CSV_FLAGS="-s , -W -h -1 -y 0"
OUTPUT_FILE=""
QUERY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -Q)
      QUERY="$2"
      shift 2
      ;;
    -o)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --no-header)
      CSV_FLAGS="-s , -W -h -1 -y 0"
      shift
      ;;
    --with-header)
      CSV_FLAGS="-s , -W -y 0"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Ensure NOCOUNT is set to avoid "(X rows affected)" noise
if [[ -n "$QUERY" ]]; then
  QUERY="SET NOCOUNT ON; ${QUERY}"
fi

# Execute with CSV-safe parameters
if [[ "$CONN_STR" == *" -d "* ]]; then
  # Format: server -d database -U user -P password
  if [[ -n "$OUTPUT_FILE" ]]; then
    eval "sqlcmd -S $CONN_STR -Q \"$QUERY\" $CSV_FLAGS -o \"$OUTPUT_FILE\""
  else
    eval "sqlcmd -S $CONN_STR -Q \"$QUERY\" $CSV_FLAGS"
  fi
else
  # Fallback to direct server parameter
  if [[ -n "$OUTPUT_FILE" ]]; then
    sqlcmd -S "$CONN_STR" -Q "$QUERY" $CSV_FLAGS -o "$OUTPUT_FILE"
  else
    sqlcmd -S "$CONN_STR" -Q "$QUERY" $CSV_FLAGS
  fi
fi