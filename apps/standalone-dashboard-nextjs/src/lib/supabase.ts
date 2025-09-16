import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});

// Edge Function caller
export async function callEdgeFunction(
  functionName: string, 
  body: any = {},
  options: RequestInit = {}
) {
  const functionBase = process.env.NEXT_PUBLIC_FUNCTION_BASE ?? "/functions/v1";
  const url = `${supabaseUrl}${functionBase}/${functionName}`;
  
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${supabaseAnonKey}`,
      ...options.headers,
    },
    body: JSON.stringify(body),
    cache: "no-store",
    ...options,
  });

  if (!response.ok) {
    throw new Error(`Edge function ${functionName} failed: ${response.status} ${response.statusText}`);
  }

  return response.json();
}