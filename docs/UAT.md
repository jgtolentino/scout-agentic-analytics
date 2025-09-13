# UAT — Sari-Sari Expert Bot

## Acceptance Gates
- **A1**: POST returns valid JSON with all top-level keys in <700 ms (without Claude).
- **A2**: ClaudeFallback activates when confidence < 0.75; returns answer with rationale.
- **A3**: Inserts land in `scout.*` tables; RLS blocks cross-account reads.
- **A4**: UI widgets render correct aggregates from gold tables.
- **A5**: Logs (optional) store request/response hashes.

## Test Matrix
1. `₱20 pay, ₱3 change, afternoon, looked at cigarettes` → total_spent=17; persona=Juan; 1–2 cigarette SKUs in `likely_products`.
2. Morning, no behavior, visible `Lucky Me` → persona=Maria or Carlo depending on time; noodles in basket.
3. Elderly persona cues → `Lola Rosa` ≥0.8 confidence.
4. Conf-threshold: craft input to yield <0.75 → ClaudeFallback path taken.
5. RLS: user A cannot read rows with `account_id` of user B.
6. Performance: Parallel 20 requests → 0 errors, P95 <1.2s (Claude excluded).
7. Recommendation acceptance toggle (UI): accepting flips `accepted=true` in `recommendations`.
8. Geo (optional): barangay filter yields differing aggregates.

## How to Run
- Apply migration, deploy function, call endpoint with sample payloads.
- Verify rows in each table; verify UI widgets over the same horizon.
