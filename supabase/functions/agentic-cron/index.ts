import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type Json = Record<string, unknown> | Array<unknown> | string | number | boolean | null;

serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const sb = createClient(supabaseUrl, supabaseServiceRoleKey, { auth: { persistSession: false } });

  const results: Record<string, unknown> = {};
  const nowISO = new Date().toISOString();

  // 1) Run monitors
  const mRun = await sb.rpc("run_monitors");
  if (mRun.error) {
    results.monitors_error = mRun.error.message;
  } else {
    results.monitor_events_created = mRun.data ?? 0;
    // Pull last 10 events to include payload summaries
    const ev = await sb.rpc("rpc_monitor_events_list", { p_limit: 10 });
    await sb.rpc("push_feed", {
      p_severity: "info",
      p_source: "monitor",
      p_title: `Monitor sweep @ ${nowISO}`,
      p_desc: `Created ${results.monitor_events_created} events`,
      p_payload: ev.data ? { events: ev.data } : {},
      p_related: [],
    });
  }

  // 2) Verify gold contracts
  const vRun = await sb.rpc("verify_gold_contracts");
  if (vRun.error) {
    results.contracts_error = vRun.error.message;
  } else {
    results.contract_violations_found = vRun.data ?? 0;
    // Pull latest violations (if table exists)
    const v = await sb.from("contract_violations").select("*").order("detected_at", { ascending: false }).limit(10);
    await sb.rpc("push_feed", {
      p_severity: (vRun.data ?? 0) > 0 ? "warn" : "success",
      p_source: "contract_check",
      p_title: `Contract checks @ ${nowISO}`,
      p_desc: `Violations: ${vRun.data ?? 0}`,
      p_payload: v.data ? { violations: v.data } : {},
      p_related: [],
    });
  }

  // 3) ISKO: fill job queue if low; (policy: maintain at least N queued jobs)
  const MIN_JOBS = Number(Deno.env.get("ISKO_MIN_QUEUED") ?? "5");
  const brandSeed = (Deno.env.get("ISKO_BRANDS") ?? "Oishi,Alaska,Del Monte,JTI,Peerless").split(",").map(s => s.trim());

  const q = await sb.from("sku_jobs").select("id", { count: "exact", head: true }).eq("status", "queued");
  const queued = q.count ?? 0;
  results.isko_queued_before = queued;

  if (queued < MIN_JOBS) {
    const toEnqueue = MIN_JOBS - queued;
    for (let i = 0; i < toEnqueue; i++) {
      const brand = brandSeed[(i) % brandSeed.length];
      const payload = { brand, region: "PH", seed: "auto", requested_by: "agentic-cron" } as Json;
      await sb.rpc("rpc_enqueue_sku_job", { p_payload: payload, p_priority: 50, p_run_after_minutes: 0 });
    }
  }

  // Optionally: claim a job and emit placeholder completion (real scraper runs elsewhere)
  // This function is scheduler/orchestrator; Isko scraper should be a separate worker (Edge/Render/Worker) that:
  //  - atomically picks 'queued' -> 'running', scrapes, writes sku_summary, marks 'success' or 'failed'.
  // Here we only summarize the queue.
  const qAfter = await sb.from("sku_jobs").select("id,status,created_at,priority").order("created_at", { ascending: false }).limit(10);
  await sb.rpc("push_feed", {
    p_severity: "info",
    p_source: "isko",
    p_title: `Isko queue status @ ${nowISO}`,
    p_desc: `Queued before: ${results.isko_queued_before}, min target: ${MIN_JOBS}`,
    p_payload: { queued_before: results.isko_queued_before, latest_jobs: qAfter.data ?? [] },
    p_related: [],
  });

  return new Response(JSON.stringify({ ok: true, results }), { headers: { "content-type": "application/json" } });
});