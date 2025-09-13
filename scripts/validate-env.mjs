#!/usr/bin/env node
/**
 * Environment Validation Script
 * Fails fast when required environment variables are missing
 */

const required = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  // Pick one GitHub auth path:
  // either 'GITHUB_TOKEN'
  // or all of: 'GITHUB_APP_ID', 'GITHUB_APP_INSTALLATION_ID', 'GITHUB_APP_PRIVATE_KEY'
];

// Check for GitHub auth configuration
const hasGitHubToken = process.env.GITHUB_TOKEN && process.env.GITHUB_TOKEN.trim() !== '';
const hasGitHubApp = process.env.GITHUB_APP_ID && process.env.GITHUB_APP_ID.trim() !== '' &&
                     process.env.GITHUB_APP_INSTALLATION_ID && process.env.GITHUB_APP_INSTALLATION_ID.trim() !== '' &&
                     process.env.GITHUB_APP_PRIVATE_KEY && process.env.GITHUB_APP_PRIVATE_KEY.trim() !== '';

// Validate GitHub auth configuration
if (!hasGitHubToken && !hasGitHubApp) {
  console.error('❌ Missing GitHub authentication:');
  console.error('   Either set GITHUB_TOKEN (PAT)');
  console.error('   OR set GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, and GITHUB_APP_PRIVATE_KEY (GitHub App)');
  process.exit(1);
}

// Check for basic required variables
const missing = required.filter(k => !process.env[k] || process.env[k].trim() === '');

if (missing.length) {
  console.error('❌ Missing required env:', missing.join(', '));
  process.exit(1);
}

// Validate Supabase configuration
if (process.env.SUPABASE_URL && !process.env.SUPABASE_URL.includes('supabase.co')) {
  console.warn('⚠️  SUPABASE_URL does not appear to be a valid Supabase URL');
}

console.log('✅ .env looks good (baseline check).');
console.log('📋 Configuration summary:');
console.log(`   - Supabase: ${process.env.SUPABASE_URL ? 'Configured' : 'Missing'}`);
console.log(`   - GitHub Auth: ${hasGitHubToken ? 'PAT' : hasGitHubApp ? 'GitHub App' : 'None'}`);
console.log(`   - Figma: ${process.env.FIGMA_PAT ? 'Configured' : 'Not configured'}`);
console.log(`   - LLM Providers: ${process.env.ANTHROPIC_API_KEY || process.env.OPENAI_API_KEY ? 'Configured' : 'None'}`);
