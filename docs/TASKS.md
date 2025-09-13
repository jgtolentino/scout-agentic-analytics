# Tasks — Executable Queue (source of truth in DB)

> Authoritative table: `scout.tasks` (every row has a **task_id**).  
> Create via RPC `scout.tasks_create()` or POST `/api/tasks`.

## How to add a task (CLI)
```bash
curl -s "$SUPABASE_URL/rest/v1/rpc/tasks_create" \
-H "apikey: $SUPABASE_SERVICE_ROLE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
-H "Content-Type: application/json" \
-d '{
  "p_title":"Refresh forecasts",
  "p_description":"Publish 14d predictions to platinum",
  "p_exec_kind":"edge_function",
  "p_exec_payload":{"fn":"forecast-refresh","body":{}},
  "p_source":"todo"
}'
```

## Common Tasks (templates)

* **Redeploy Edge** → `exec_kind=edge_function` per function OR GitHub workflow.
* **Kick ETL JSON** → `exec_kind=gh_workflow`, payload `{ "workflow":"etl-drive-json.yml", "ref":"main" }`.
* **Vacuum recos** → `exec_kind=sql`, payload `{ "sql":"vacuum analyze scout.recommendations;" }`.
* **Retrain model** → `exec_kind=mindsdb_sql`, payload with `CREATE MODEL ...`.

## Export current tasks to this file

Run `scripts/docs/export-tasks.sh` (requires `SUPABASE_DB_URL`) to append a snapshot table below.

---

## Snapshot (read-only; generated)

<!-- BEGIN:SNAPSHOT -->

No snapshot yet. Run `scripts/docs/export-tasks.sh`.

<!-- END:SNAPSHOT -->

