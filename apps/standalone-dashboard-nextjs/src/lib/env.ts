/**
 * Environment helper for Next.js compatibility
 * Centralizes environment variable access with proper fallbacks
 */

export const ENV = {
  // Development settings
  DEV_BYPASS_AUTH: process.env.NEXT_PUBLIC_DEV_BYPASS_AUTH === "1",
  USE_MOCK: process.env.NEXT_PUBLIC_USE_MOCK === "1",
  
  // Scout configuration
  SCOUT_VERSION: process.env.NEXT_PUBLIC_SCOUT_VERSION ?? "7",
  ENABLE_SCOUT_AI: process.env.NEXT_PUBLIC_ENABLE_SCOUT_AI === "1",
  
  // Supabase configuration
  SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "",
  SUPABASE_FUNCTIONS_URL: process.env.NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL ?? "/functions/v1",
  
  // Amazon theme configuration
  AI_ASSISTANT: process.env.NEXT_PUBLIC_AI_ASSISTANT === "1",
  THEME_AMAZON: process.env.NEXT_PUBLIC_THEME_AMAZON === "1",
  
  // Runtime environment
  NODE_ENV: process.env.NODE_ENV ?? "development",
  DEV: process.env.NODE_ENV === "development",
  PROD: process.env.NODE_ENV === "production",
};