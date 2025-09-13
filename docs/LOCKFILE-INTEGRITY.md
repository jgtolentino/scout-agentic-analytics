# Lockfile Integrity & Provenance

## Overview

This document describes the lockfile integrity and provenance measures implemented to ensure supply chain security.

## Features Implemented

### 1. Lockfile Integrity Verification

**Script**: `scripts/verify-lockfile.js`
- Verifies package-lock.json hasn't been tampered with
- Checks for known malicious packages
- Validates package integrity hashes
- Detects typosquatting attempts
- Generates lockfile checksums

**Usage**:
```bash
npm run verify:lockfile
```

### 2. NPM Configuration (.npmrc)

Security-focused npm configuration:
- `lockfile-version=3` - Use latest lockfile format
- `save-exact=true` - Pin exact versions
- `package-lock=true` - Always use lockfile
- `provenance=true` - Enable package provenance
- `audit-level=moderate` - Security audit threshold
- `engine-strict=true` - Enforce Node.js version

### 3. GitHub Actions Workflows

#### Lockfile Integrity Check (.github/workflows/lockfile-integrity.yml)

Runs on:
- Pull requests that modify package files
- Pushes to main/develop branches

Checks:
- Lockfile exists and matches package.json
- No package.json changes without lockfile updates
- Security audit for vulnerabilities
- Package signature verification (npm 9.5+)
- Duplicate package detection
- License compliance

#### Supply Chain Security (.github/workflows/supply-chain-security.yml)

Comprehensive security scanning:
- **OpenSSF Scorecard** - Security best practices score
- **SBOM Generation** - Software Bill of Materials (SPDX & CycloneDX)
- **Vulnerability Scanning** - Trivy, Grype, OWASP Dependency Check
- **License Compliance** - Detect restrictive licenses
- **Build Provenance** - Cryptographic attestations

### 4. Package Provenance

**Requirements**: npm 9.5+

**Setup Script**: `scripts/npm-provenance.sh`
- Configures npm for provenance
- Creates publish workflow with attestations
- Provides verification tools

**Publishing with Provenance**:
```bash
npm run publish:provenance
```

**Verifying Provenance**:
```bash
npm run verify:provenance
```

### 5. Security Commands

```bash
# Full security check
npm run security:check

# Verify lockfile integrity
npm run verify:lockfile

# Check package provenance
npm run verify:provenance

# Audit dependencies
npm audit --production
```

## Best Practices

### 1. Development Workflow

1. **Always use npm ci** for clean installs
2. **Never manually edit** package-lock.json
3. **Commit lockfile changes** with package.json changes
4. **Review dependabot PRs** carefully
5. **Run security checks** before merging

### 2. CI/CD Integration

All PRs are automatically checked for:
- Lockfile integrity
- Security vulnerabilities
- License compliance
- Package signatures

### 3. Supply Chain Security

1. **SBOM Generation** - Track all dependencies
2. **Vulnerability Scanning** - Multiple scanners for coverage
3. **License Compliance** - Avoid GPL/AGPL issues
4. **Provenance Attestations** - Verify build origin

## Troubleshooting

### "Lockfile doesn't match package.json"

```bash
# Regenerate lockfile
rm -rf node_modules package-lock.json
npm install
```

### "Package missing integrity hash"

This warning appears for:
- Git dependencies
- Local file dependencies
- Old packages without hashes

### "Known malicious package detected"

1. Check the package name for typos
2. Remove the package immediately
3. Run `npm audit fix`
4. Report to npm security team

### "npm doesn't support provenance"

```bash
# Upgrade npm
npm install -g npm@latest

# Verify version (need 9.5+)
npm --version
```

## Security Alerts

The following automated alerts are configured:

1. **Critical vulnerabilities** - Blocks PR merge
2. **License violations** - Warning in PR
3. **Lockfile tampering** - Blocks PR merge
4. **Signature verification failure** - Warning in PR

## Monitoring

Regular security monitoring includes:

1. **Daily** - Dependabot security updates
2. **Weekly** - Full dependency updates
3. **Monthly** - License audit
4. **Per-PR** - Lockfile integrity check

## Incident Response

If a security issue is detected:

1. **Immediate Actions**:
   - Run `npm audit fix`
   - Check for available patches
   - Review recent commits

2. **Investigation**:
   - Check SBOM for affected packages
   - Review vulnerability details
   - Assess impact on production

3. **Remediation**:
   - Apply security patches
   - Update affected packages
   - Regenerate lockfile
   - Deploy fixes immediately

4. **Post-Incident**:
   - Document the incident
   - Update security procedures
   - Review supply chain controls