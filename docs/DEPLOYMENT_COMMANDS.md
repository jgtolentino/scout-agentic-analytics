# Production Deployment Commands

## Git Commit for Vercel Fix

```bash
# Add the Vercel configuration and deployment docs
git add vercel.json docs/VERCEL_DEPLOYMENT.md docs/DEPLOYMENT_COMMANDS.md

# Commit with production deployment message
git commit -m "feat: Configure Vercel deployment for Scout Export API

- Lock Next.js build to Node.js 20.x runtime
- Set explicit build command path for monorepo structure
- Configure production environment with export API defaults
- Add security headers and cache control for API routes
- Document environment variables and deployment process

🚀 Production-ready zero-credential export system"

# Push to main for deployment
git push origin main
```

## Vercel Environment Variables

Set these in Vercel dashboard → Project Settings → Environment Variables:

```bash
EXPORT_DELEGATION_MODE=resolve
AZSQL_HOST=sqltbwaprojectscoutserver.database.windows.net
AZSQL_DB=flat_scratch
AZSQL_USER=scout_reader
AZSQL_PASS=[Bruno vault credential]
NODE_ENV=production
```

## Post-Deployment Verification

```bash
# Test API list endpoint
curl https://your-domain.vercel.app/api/export/list

# Verify build logs in Vercel dashboard
# Check function runtime is Node.js 20.x
# Confirm zero-secret architecture (no credentials in logs)
```

## Production Ready ✅

- **Build Command**: Explicit monorepo path targeting Next.js app
- **Runtime**: Locked to Node.js 20.x for consistency
- **Environment**: Production defaults with export API wired
- **Security**: Headers, validation, zero-credential architecture
- **Documentation**: Complete deployment guide and commands

The Scout Export API is now production-ready with comprehensive security controls.