#!/usr/bin/env bash
set -euo pipefail

ROOT="ui/theme"
VENDOR="$ROOT/vendor/amazon"
TOKENS_JSON="$ROOT/tokens.json"

echo "🔄 Syncing Amazon theme..."

if [ -d "$VENDOR/.git" ]; then
  echo "📥 Updating theme submodule..."
  git -C "$VENDOR" fetch --all && git -C "$VENDOR" checkout -q main || true
  git -C "$VENDOR" pull --ff-only || true
fi

if [ -f "$TOKENS_JSON" ]; then
  echo "✅ Using existing tokens.json"
else
  echo "⚠️  Creating default tokens.json..."
  cat > "$TOKENS_JSON" <<'JSON'
{
  "colors": {
    "background": "#0b0f1a",
    "surface": "#121826", 
    "text": "#e5e7eb",
    "primary": "#22c55e",
    "muted": "#64748b",
    "accent": "#60a5fa"
  },
  "radius": { "sm": "6px", "md": "10px", "lg": "14px" },
  "spacing": { "xs": "4px", "sm": "8px", "md": "12px", "lg": "16px", "xl": "24px" }
}
JSON
fi

echo "✅ Theme sync complete."