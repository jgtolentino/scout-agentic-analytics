# Planning — Scout v7

## Milestones
- **M0 — Infra/Docs (today)**: schemas, Edge, CI, Auditor, PRD/CLAUDE/TASKS complete.
- **M1 — ETL+Diagnostics (Week 1)**: Drive/Azure ingest live, gaps & DQ views healthy.
- **M2 — Forecasts (Week 2)**: MindsDB model trained, 14-day predictions wired.
- **M3 — Recos+Tasks (Week 3)**: prescriptive recos, executable queue & runner.
- **M4 — Hardening (Week 4)**: thresholds, alerting, dashboard polish, SLO review.

## Deliverables by milestone
- M1: `ops.source_inventory`, `public.v_pipeline_gaps`, unknown brands < 10%.
- M2: `platinum_predictions_revenue_14d` non-zero daily; MAPE baseline computed.
- M3: runner loops; `task_id` on 100% recos/tasks; Workbench actions ok.
- M4: Auditor PASS nightly; incident runbooks; docs finalized.

## Risks & Mitigations
- Drive schema drift → robust normalizer + triage queue.
- Fuzzy merge false positives → alias whitelist & audit log.
- Container health → health checks + restart policy.

## Open Questions
- Do we keep forecasts public view or move behind RLS?
- Which brands/categories are SLA-critical for MAPE gating?
