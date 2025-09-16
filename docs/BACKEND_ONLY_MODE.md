# Backend-Only Mode for Claude Code 🚧

**Status**: ✅ **ACTIVE** - Backend-only enforcement enabled for Scout v7 repository

## Overview

This repository is configured in **Backend-Only Mode** to constrain Claude Code sessions to backend-only operations, preventing any frontend/UI work and ensuring secure credential management through Bruno.

## System Architecture

### Policy Enforcement Stack
1. **Policy Definition**: `ops/claude_backend_policy.yaml` - Declarative path and command constraints
2. **Guard Script**: `scripts/guard_backend_changes.sh` - Pre-commit validation
3. **Git Hook**: `.git/hooks/pre-push` - Local enforcement on push
4. **CI Gate**: `.github/workflows/backend_policy_and_smoke.yml` - Repository-level validation
5. **CODEOWNERS**: Repository ownership and approval requirements

### Allowed Operations
- **Paths**: `supabase/`, `dbt-scout/`, `data-pipeline/`, `great_expectations/`, `workflows/`, `scripts/`, `kg/`, `docs/`, `ops/`, `.github/`
- **Commands**: `psql`, `supabase`, `dbt`, `python`, `great_expectations`, `bash`, `jq`, `curl`, `temporal`
- **File Operations**: Read, Write, Edit on backend paths only

### Blocked Operations
- **Paths**: `apps/`, `app/`, `ui/`, `packages/`, `frontend/`, `*.config.{js,ts}`
- **Commands**: `npm`, `pnpm`, `yarn`, `next`, `vite`, `playwright`
- **Network/DB**: Direct credential access (must use Bruno)

## Usage

### Claude Code System Prompt
```
You are operating in **Backend-Only Mode**. You may read/write files **only** under: 
`supabase/**`, `dbt-scout/**`, `data-pipeline/**`, `great_expectations/**`, `workflows/**`, 
`scripts/**`, `kg/**`, `docs/**`. You must not touch frontend/UI paths (`apps/**`, `app/**`, 
`ui/**`, `packages/**`, `frontend/**`, any Next/Vite config).

All network/DB/infrastructure commands must be output as **`:bruno`** blocks (Claude has no creds). 
File edits and git ops are allowed as **`:clodrep`** only.

Before committing, run `scripts/guard_backend_changes.sh`. If any change falls outside 
allowed paths, **revert** it.

Primary tasks: migrations, dbt models/tests, Great Expectations suites, Temporal workflows, 
Supabase functions, SRP/KG artifact generation, and backend docs.
```

### Local Validation
```bash
# Test current staged changes
./scripts/guard_backend_changes.sh

# Run backend smoke test (structure only)
./scripts/backend_smoke_via_bruno.sh
```

### Bruno Integration Pattern
```bash
# All DB/network operations via Bruno
:bruno run "
cd /Users/tbwa/scout-v7
source ./scripts/env.from.vault.sh
supabase db push --db-url \"\$DB_URL\"
cd dbt-scout && dbt run --select silver+ gold+ && dbt test
great_expectations checkpoint run bronze_quarantine_suite
"
```

## Enforcement Mechanisms

### 🔴 Critical Violations (Auto-Block)
- Touching any `apps/`, `ui/`, `frontend/` paths
- Using frontend commands (`npm`, `vite`, `next`)
- Direct credential usage in prompts

### 🟡 Soft Violations (Warning + Review)
- Changes outside defined backend paths
- Network operations without Bruno routing
- Command usage outside allowed list

### ✅ Compliant Operations
- Supabase migrations and functions
- dbt model development and testing
- Great Expectations suite creation
- Backend documentation
- CI/CD pipeline configuration
- Script and workflow automation

## File Structure

```
scout-v7/
├── ops/
│   └── claude_backend_policy.yaml    # Policy definition
├── scripts/
│   ├── guard_backend_changes.sh      # Path validation guard  
│   └── backend_smoke_via_bruno.sh    # Backend smoke test
├── .github/
│   └── workflows/
│       └── backend_policy_and_smoke.yml  # CI enforcement
├── .git/hooks/
│   └── pre-push                      # Local git hook
├── CODEOWNERS                        # Repository ownership
└── docs/
    └── BACKEND_ONLY_MODE.md         # This document
```

## Integration with Project Standards

### Medallion Architecture Support
- **Bronze Layer**: Raw data ingestion and quarantine validation
- **Silver Layer**: Cleaned and standardized data transformations  
- **Gold Layer**: Business logic and analytics views
- **Platinum Layer**: ML features and advanced aggregations

### Security & Compliance
- **Zero-Secret Policy**: All credentials via Bruno vault injection
- **Audit Trail**: All changes logged and validated through CI
- **Separation of Concerns**: Backend logic isolated from frontend presentation

### Quality Gates
- **Pre-commit**: Local validation via git hook
- **CI Pipeline**: Automated policy and smoke testing  
- **Code Review**: CODEOWNERS enforcement for sensitive changes
- **Documentation**: Inline policy documentation and examples

## Troubleshooting

### Guard Script Failures
```bash
# Check which files are causing issues
git diff --cached --name-only

# Debug the guard script with verbose output
bash -x ./scripts/guard_backend_changes.sh

# Reset staged files if needed
git reset HEAD <problematic-file>
```

### Missing yq Dependency
```bash
# Install yq for policy file parsing
brew install yq
# or on Ubuntu: sudo apt install yq
```

### Git Hook Not Running
```bash
# Ensure hook is executable
chmod +x /Users/tbwa/.git/modules/scout-v7/hooks/pre-push

# Test hook manually
./scripts/guard_backend_changes.sh
```

## Benefits

### 🎯 Focused Development
- Claude Code constrained to backend expertise domain
- No accidental frontend modifications
- Clear separation of responsibilities

### 🔒 Security Compliance  
- Zero credentials in prompts or repository
- All network operations audited through Bruno
- Comprehensive access controls and logging

### ⚡ Operational Efficiency
- Automated validation prevents policy violations
- CI gates catch compliance issues early
- Streamlined backend development workflow

### 📊 Audit & Governance
- Complete traceability of backend changes
- Policy compliance reporting via CI
- Evidence-based security posture

---

**Enforcement Level**: 🔴 **STRICT** - Policy violations block commits and PRs  
**Integration**: ✅ **BRUNO-NATIVE** - All network/DB ops via secure credential injection  
**Scope**: 🏗️ **BACKEND-ONLY** - Supabase, dbt, GE, workflows, scripts, docs