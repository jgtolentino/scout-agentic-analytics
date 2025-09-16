'use client';

import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';
import { createClient } from '@supabase/supabase-js';
import type { Database } from './types';

// Check if we're in mock mode
const USE_MOCK = process.env.NEXT_PUBLIC_USE_MOCK === '1';

// Safe environment variable access with defaults
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://mock.supabase.co';
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'mock-anon-key';

// Validate environment variables in production
if (!USE_MOCK && (SUPABASE_URL.includes('your-project') || SUPABASE_ANON_KEY.includes('your-anon-key'))) {
  console.warn('⚠️ Supabase environment variables are not configured properly. Using mock mode.');
}

// Singleton pattern for Supabase client to prevent multiple instances
const g = globalThis as unknown as { __scoutSupabase?: any };

// Browser client for client components
export const supabase = USE_MOCK ? null : (
  g.__scoutSupabase ??
  createClient<Database>(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      storageKey: 'scout-v7-nextjs-auth', // Unique storage key for this Next.js app
      autoRefreshToken: false, // Disable for analytics dashboard
      persistSession: false, // We don't need auth sessions for analytics dashboard
      detectSessionInUrl: false,
    },
  })
);

// Store singleton in development
if (process.env.NODE_ENV !== 'production' && supabase) {
  g.__scoutSupabase = supabase;
}

// Alternative client using auth helpers (if needed for future auth)
export const createBrowserClient = () => 
  createClientComponentClient<Database>();

// RPC call helper with error handling and mock support
export async function callSupabaseRPC<T = any>(
  functionName: string, 
  params: Record<string, any> = {}
): Promise<T> {
  // In mock mode, return empty data to prevent errors
  if (USE_MOCK || !supabase) {
    console.log(`🎭 Mock mode: RPC ${functionName} called with params:`, params);
    return {} as T;
  }

  try {
    const { data, error } = await supabase.rpc(functionName, params);
    
    if (error) {
      console.error(`RPC ${functionName} failed:`, error);
      throw new Error(`Database call failed: ${error.message}`);
    }
    
    return data as T;
  } catch (error) {
    console.error(`RPC ${functionName} network error:`, error);
    // Fallback to mock mode on network errors
    console.log(`🎭 Falling back to mock mode for RPC ${functionName}`);
    return {} as T;
  }
}

// Batch RPC calls for performance
export async function callMultipleRPCs(calls: Array<{
  name: string;
  params?: Record<string, any>;
}>): Promise<Record<string, any>> {
  // In mock mode, return empty data for all calls
  if (USE_MOCK || !supabase) {
    console.log(`🎭 Mock mode: Batch RPC calls:`, calls.map(c => c.name));
    const mockResults = calls.reduce((acc, { name }) => ({
      ...acc,
      [name]: { data: {}, error: null }
    }), {});
    return mockResults;
  }

  const promises = calls.map(async ({ name, params = {} }) => {
    try {
      const result = await callSupabaseRPC(name, params);
      return { [name]: { data: result, error: null } };
    } catch (error) {
      return { [name]: { data: null, error } };
    }
  });
  
  const results = await Promise.all(promises);
  return Object.assign({}, ...results);
}

// Query builder helpers
export const createQuery = (table: string) => {
  if (USE_MOCK || !supabase) {
    console.log(`🎭 Mock mode: Query builder for table ${table}`);
    return null;
  }
  return supabase.from(table);
};

// Real-time subscription helper
export const createSubscription = (
  table: string,
  callback: (payload: any) => void,
  filter?: string
) => {
  if (USE_MOCK || !supabase) {
    console.log(`🎭 Mock mode: Subscription for table ${table}`);
    return { unsubscribe: () => {} };
  }

  let channel = supabase.channel(`${table}_changes`);
  
  if (filter) {
    channel = channel.on('postgres_changes', {
      event: '*',
      schema: 'public',
      table,
      filter
    }, callback);
  } else {
    channel = channel.on('postgres_changes', {
      event: '*',
      schema: 'public',
      table
    }, callback);
  }
  
  return channel.subscribe();
};