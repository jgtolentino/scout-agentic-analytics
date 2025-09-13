#!/usr/bin/env bash
set -euo pipefail

ns="${PULSER_SECRET_NAMESPACE:-suqi-tab-gen}"

export_if_unset() { local var="$1" val="$2"; [[ -z "${!var:-}" && -n "$val" ]] && export "$var"="$val"; }

platform="$(uname -s)"
case "$platform" in
  Darwin)
    get_secret() { security find-generic-password -a "$USER" -s "$ns:$1" -w 2>/dev/null || true; }
    ;;
  Linux)
    if command -v pass >/dev/null 2>&1; then
      get_secret() { pass show "$ns/$1" 2>/dev/null || true; }
    elif command -v secret-tool >/dev/null 2>&1; then
      get_secret() { secret-tool lookup service "$ns" key "$1" 2>/dev/null || true; }
    else
      get_secret() { echo ""; }
    fi
    ;;
  *) get_secret() { echo ""; } ;;
esac

# Primary secrets
export_if_unset SUPABASE_JWT_SECRET         "$(get_secret SUPABASE_JWT_SECRET)"
export_if_unset SUPABASE_SERVICE_ROLE_KEY   "$(get_secret SUPABASE_SERVICE_ROLE_KEY)"
export_if_unset SUPABASE_URL                "$(get_secret SUPABASE_URL)"
export_if_unset SUPABASE_PROJECT_REF        "$(get_secret SUPABASE_PROJECT_REF)"
export_if_unset ADMIN_API_KEY               "$(get_secret ADMIN_API_KEY)"
export_if_unset SUPABASE_EDGE_URL           "$(get_secret SUPABASE_EDGE_URL)" # e.g. https://<project>.functions.supabase.co

# CI tokens (optional)
export_if_unset SUPABASE_ACCESS_TOKEN       "$(get_secret SUPABASE_ACCESS_TOKEN)"

# Fallback: .env.local (never commit)
if [[ -f .env.local ]]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env.local | xargs -I{} echo {})
fi

# Minimal warnings (values not echoed)
for v in SUPABASE_JWT_SECRET SUPABASE_SERVICE_ROLE_KEY SUPABASE_URL SUPABASE_PROJECT_REF ADMIN_API_KEY; do
  [[ -z "${!v:-}" ]] && echo "WARN: $v not set (ok if not used by current command)" >&2
done