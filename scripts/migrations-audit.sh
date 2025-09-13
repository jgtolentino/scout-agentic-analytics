#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
cd "$ROOT"

dir="platform/scout/migrations"
[[ -d "$dir" ]] || dir="supabase/migrations"
[[ -d "$dir" ]] || { echo "✖ migrations directory not found"; exit 2; }

echo "== Audit: duplicate numbers & gaps =="
nums=()
mapfile -t files < <(ls -1 "$dir" | grep -E '^[0-9]+' | sort)
for f in "${files[@]}"; do
  n="${f%%_*}"        # prefix before first underscore
  nums+=("$n")
done

# duplicates
echo "— Duplicates:"
printf "%s\n" "${nums[@]}" | sort | uniq -d | awk '{print "  " $0}' || true

# gaps (sequential style)
echo "— Gaps (sequential style):"
if [[ ${#nums[@]} -gt 0 ]]; then
  min=$(printf "%s\n" "${nums[@]}" | sort -n | head -1)
  max=$(printf "%s\n" "${nums[@]}" | sort -n | tail -1)
  seq $min $max | grep -Fxv -f <(printf "%s\n" "${nums[@]}" | sort -n) | awk '{print "  " $0}'
fi

echo "— Files:"
printf "  %s\n" "${files[@]}"
