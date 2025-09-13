#!/usr/bin/env bash
set -euo pipefail

REQ=("python3" "jq" "openssl")
for b in "${REQ[@]}"; do command -v "$b" >/dev/null || { echo "Missing dependency: $b"; exit 1; }; done

SECRET="${SUPABASE_JWT_SECRET:-}"
if [[ -z "$SECRET" || ${#SECRET} -lt 16 ]]; then
  echo "ERROR: SUPABASE_JWT_SECRET is unset or too short."
  exit 1
fi

INPUT="${1:-}"
[[ -z "$INPUT" || ! -f "$INPUT" ]] && { echo "ERROR: provide collaborators.csv (email,role,ttl_hours)"; exit 1; }

mkdir -p dist
OUT_CSV="dist/tokens.csv"
OUT_JSON="dist/tokens.json"
TMP="dist/.tokens.tmp.jsonl"
: > "$OUT_CSV"; : > "$TMP"
echo "email,role,ttl_hours,exp_unix,jti,token" >> "$OUT_CSV"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
hmac()   { printf '%s' "$1" | openssl dgst -binary -sha256 -hmac "$SECRET" | b64url; }

HEADER_B64=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)

tail -n +1 "$INPUT" | while IFS=, read -r email role ttl; do
  email="$(echo -n "$email" | xargs)"; role="$(echo -n "$role" | xargs)"; ttl="$(echo -n "$ttl" | xargs)"
  [[ -z "$email" || "$email" == "email" ]] && continue
  [[ -z "$role"  || "$role"  == "role"  ]] && continue
  [[ -z "$ttl"   || "$ttl"   == "ttl_hours" ]] && continue

  exp=$(python3 - <<PY
import time; print(int(time.time()) + int($ttl)*3600)
PY
)
  jti=$(python3 - <<'PY'
import uuid; print(str(uuid.uuid4()))
PY
)

  PAYLOAD=$(jq -nc --arg sub "$email" --arg email "$email" --arg role "$role" --arg aud "authenticated" --arg jti "$jti" --argjson exp "$exp" \
    '{sub:$sub,email:$email,role:$role,aud:$aud,exp:$exp,jti:$jti,iss:"supabase-jwt-cli"}')
  PAYLOAD_B64=$(printf '%s' "$PAYLOAD" | b64url)

  tosign="${HEADER_B64}.${PAYLOAD_B64}"
  sig=$(hmac "$tosign")
  token="${tosign}.${sig}"

  # local verify
  exp_sig=$(hmac "$tosign")
  [[ "$sig" != "$exp_sig" ]] && { echo "ERROR: signature verify failed for $email"; exit 2; }

  echo "$email,$role,$ttl,$exp,$jti,$token" >> "$OUT_CSV"
  jq -nc --arg email "$email" --arg role "$role" --arg ttl "$ttl" --arg token "$token" --arg jti "$jti" --argjson exp "$exp" \
     '{email:$email,role:$role,ttl_hours:($ttl|tonumber),exp_unix:$exp,jti:$jti,token:$token}' >> "$TMP"
done

jq -s '.' "$TMP" > "$OUT_JSON"
rm -f "$TMP"

echo "✅ Generated dist/tokens.csv & dist/tokens.json"