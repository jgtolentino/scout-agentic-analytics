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
  
  // Data service configuration
  DATA_SOURCE: process.env.NEXT_PUBLIC_DATA_SOURCE ?? "azure",
  AZURE_FUNCTION_BASE: process.env.NEXT_PUBLIC_AZURE_FUNCTION_BASE ?? "https://fn-scout-readonly.azurewebsites.net/api",
  AZURE_FUNCTION_KEY: process.env.NEXT_PUBLIC_AZURE_FUNCTION_KEY ?? "",
  
  // Amazon theme configuration
  AI_ASSISTANT: process.env.NEXT_PUBLIC_AI_ASSISTANT === "1",
  THEME_AMAZON: process.env.NEXT_PUBLIC_THEME_AMAZON === "1",
  
  // Runtime environment
  NODE_ENV: process.env.NODE_ENV ?? "development",
  DEV: process.env.NODE_ENV === "development",
  PROD: process.env.NODE_ENV === "production",
};