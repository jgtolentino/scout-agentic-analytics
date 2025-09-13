---
id: access-tokens
title: Access Tokens (Supabase HS256)
sidebar_label: Access Tokens
---

Issue, rotate, and revoke Supabase-compatible **HS256** JWTs.

## Issue tokens
```bash
./scripts/issue-tokens.sh collaborators.csv
```

Outputs: `dist/tokens.csv` and `dist/tokens.json`.

**Claims:** `sub,email,role,aud=authenticated,exp,jti,iss=supabase-jwt-cli`.

## Revoke a token

```bash
curl -X POST "$SUPABASE_EDGE_URL/functions/v1/revoke-token" \
  -H "x-admin-api-key: $ADMIN_API_KEY" -H "content-type: application/json" \
  -d '{"jti":"<JTI>","email":"user@company.com","reason":"lost device"}'
```

## Gate requests

```bash
curl -i "$SUPABASE_EDGE_URL/functions/v1/token-guard" \
  -H "authorization: Bearer <TOKEN>"
```

200 = valid; 401/403 = reject.

## Rotation policy

TTL: 72–168h recommended. Short TTL + easy reissue > long-lived tokens. Never paste secrets/tokens in chat.