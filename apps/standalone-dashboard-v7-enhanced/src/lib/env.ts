/**
 * Environment helper for Vite compatibility
 * Centralizes environment variable access with proper fallbacks
 */

export const ENV = {
  // Development settings
  DEV_BYPASS_AUTH: (import.meta.env.VITE_DEV_BYPASS_AUTH ?? "0") === "1",
  USE_MOCK: (import.meta.env.VITE_USE_MOCK ?? "1") === "1",
  
  // Scout configuration
  SCOUT_VERSION: import.meta.env.VITE_SCOUT_VERSION ?? "7",
  ENABLE_SCOUT_AI: (import.meta.env.VITE_ENABLE_SCOUT_AI ?? "1") === "1",
  
  // Supabase configuration
  SUPABASE_URL: import.meta.env.VITE_SUPABASE_URL ?? "",
  SUPABASE_ANON_KEY: import.meta.env.VITE_SUPABASE_ANON_KEY ?? "",
  SUPABASE_FUNCTIONS_URL: import.meta.env.VITE_SUPABASE_FUNCTIONS_URL ?? "",
  
  // Runtime environment
  NODE_ENV: import.meta.env.NODE_ENV ?? "development",
  DEV: import.meta.env.DEV ?? true,
  PROD: import.meta.env.PROD ?? false,
};