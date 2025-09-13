# CLAUDE.md — Orchestrator Rules (Claude Code) for Scout v7

**Principle:** Claude orchestrates. **Bruno executes.** Claude never sees secrets or runs privileged commands.

## Allowed surfaces
- **MCP**: `mindsdb-mcp` (SSE), `supabase_primary`, `postgres_local`, `filesystem`, `github`.
- **No** direct DB creds; **no** cloud keys; **no** shell outside Bruno.

## Execution rules
1) All command blocks must be emitted as `:bruno`/`:clodrep` one-shots.
2) Secrets pulled from environment or GitHub Actions — never echoed.
3) Use Edge functions & RPCs for DB mutations where feasible.

## Common runbooks
- **Publish forecasts now**
```

\:bruno agt one-shot "Publish forecasts"
bash scripts/mindsdb/refresh-predictions.sh

```
- **Redeploy all Edge**
```

\:bruno agt one-shot "Redeploy Edge"
for fn in inventory-report ingest-azure-infer ingest-google-json mindsdb-query forecast-refresh task-enqueue; do supabase functions deploy "\$fn"; done

```
- **Auditor**
```

\:bruno agt one-shot "Auditor"
bash /Users/tbwa/scout-v7-auditor.sh

```

## Guardrails
- No data exfil; only schema/metrics to LLM context.
- If ENOSPC or environment errors, run free-space pack before retries.
