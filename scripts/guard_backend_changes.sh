#!/usr/bin/env bash
set -euo pipefail
POLICY="ops/claude_backend_policy.yaml"
if [[ ! -f "$POLICY" ]]; then echo "Missing $POLICY"; exit 1; fi

changed=$(git diff --name-only --cached || true)
[[ -z "$changed" ]] && exit 0

allow_globs=$(yq '.allowed_paths[]' "$POLICY")
block_globs=$(yq '.blocked_paths[]' "$POLICY" || true)

# If a file matches any blocked_glob -> fail
for f in $changed; do
  for g in $block_globs; do
    if [[ $f == $g ]]; then
      echo "❌ Blocked path touched: $f (policy: $g)"; exit 2
    fi
  done
done

# If a file does not match any allowed_glob -> fail
for f in $changed; do
  ok="no"
  for g in $allow_globs; do
    if [[ $f == $g ]]; then ok="yes"; break; fi
  done
  if [[ "$ok" == "no" ]]; then
    echo "❌ File not in allowed_paths: $f"; exit 3
  fi
done

echo "✅ Backend-only guard passed"