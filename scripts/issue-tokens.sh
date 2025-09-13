#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source ./scripts/secrets.sh
input="${1:-collaborators.csv}"
[[ -f "$input" ]] || { echo "ERROR: $input not found"; exit 1; }
./scripts/generate-tokens-cli.sh "$input"
echo "✅ Tokens ready at dist/"