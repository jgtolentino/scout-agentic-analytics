// scripts/load-bronze-from-storage.local.ts
// Local version of the Edge Function for development

import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL!;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const supabase = createClient(url, key);

type Obj = { name: string };

async function* listAll(bucket: string, prefix: string) {
  let page = 0;
  const limit = 100;
  while (true) {
    const { data, error } = await supabase.storage.from(bucket).list(prefix, { limit, offset: page * limit });
    if (error) throw error;
    if (!data || data.length === 0) break;
    for (const obj of data as Obj[]) yield obj.name;
    if (data.length < limit) break;
    page++;
  }
}

async function loadBronzeFromStorage(date: string = new Date().toISOString().slice(0, 10)) {
  const bucket = "scout-ingest";
  const prefix = `${date}/`;

  let filesLoaded = 0;

  try {
    for await (const name of listAll(bucket, prefix)) {
      if (!name.endsWith(".jsonl")) continue;
      const { data: file, error: dlErr } = await supabase.storage.from(bucket).download(`${prefix}${name}`);
      if (dlErr) throw dlErr;
      const text = await file.text();
      const lines = text.split(/\r?\n/).filter(Boolean);
      const rows = lines.map((ln) => {
        const payload = JSON.parse(ln);
        return {
          id: payload.id ?? crypto.randomUUID(),
          device_id: payload.device_id ?? "unknown",
          ts: payload.ts ?? new Date().toISOString(),
          payload,
          src_path: `${bucket}/${prefix}${name}`,
        };
      });

      // Batch insert in chunks
      const chunk = 1000;
      for (let i = 0; i < rows.length; i += chunk) {
        const slice = rows.slice(i, i + chunk);
        const { error } = await supabase.from("scout_bronze.transactions_raw").insert(slice);
        if (error) throw error;
      }
      filesLoaded++;
      console.log(`Loaded ${name}`);
    }

    console.log(`Total files loaded: ${filesLoaded}`);
  } catch (e) {
    console.error("Error:", e);
  }
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const date = process.argv[2] || new Date().toISOString().slice(0, 10);
  loadBronzeFromStorage(date);
}