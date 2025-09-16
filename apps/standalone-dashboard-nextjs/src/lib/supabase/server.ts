import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { createClient } from '@supabase/supabase-js';
import { cookies } from 'next/headers';
import type { Database } from './types';

// Server client for server components and API routes
export const createServerClient = () => {
  const cookieStore = cookies();
  return createServerComponentClient<Database>({ cookies: () => cookieStore });
};

// Direct server client (for API routes where auth helpers aren't needed)
export const serverSupabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY! || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  {
    auth: {
      persistSession: false,
    },
  }
);

// Server-side RPC call helper
export async function callServerRPC<T = any>(
  functionName: string, 
  params: Record<string, any> = {}
): Promise<T> {
  const { data, error } = await serverSupabase.rpc(functionName, params);
  
  if (error) {
    console.error(`Server RPC ${functionName} failed:`, error);
    throw new Error(`Database call failed: ${error.message}`);
  }
  
  return data as T;
}

// Batch server RPC calls
export async function callMultipleServerRPCs(calls: Array<{
  name: string;
  params?: Record<string, any>;
}>): Promise<Record<string, any>> {
  const promises = calls.map(async ({ name, params = {} }) => {
    try {
      const result = await callServerRPC(name, params);
      return { [name]: { data: result, error: null } };
    } catch (error) {
      return { [name]: { data: null, error } };
    }
  });
  
  const results = await Promise.all(promises);
  return Object.assign({}, ...results);
}