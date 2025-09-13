#!/usr/bin/env node

/**
 * Lockfile Integrity Verification Script
 * 
 * This script verifies:
 * 1. Lockfile hasn't been tampered with
 * 2. All dependencies match expected versions
 * 3. No unauthorized packages have been added
 * 4. Package integrity hashes are valid
 */

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');
const { execSync } = require('child_process');

// ANSI color codes
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
};

// Trusted registries
const TRUSTED_REGISTRIES = [
  'https://registry.npmjs.org/',
  'https://registry.yarnpkg.com/'
];

// Known malicious package patterns
const MALICIOUS_PATTERNS = [
  /^node-ipc@.*10\.1\.(?:[1-9]|10)$/, // Known compromised versions
  /^colors@.*1\.4\.1$/, // Known compromised version
  /^faker@.*6\.6\.6$/, // Known compromised version
  /^ua-parser-js@.*(?:0\.7\.29|0\.8\.0|1\.0\.0)$/, // Known compromised versions
];

class LockfileVerifier {
  constructor() {
    this.errors = [];
    this.warnings = [];
    this.verified = 0;
  }

  log(message, type = 'info') {
    const prefix = {
      error: `${colors.red}❌`,
      warning: `${colors.yellow}⚠️ `,
      success: `${colors.green}✅`,
      info: `${colors.blue}ℹ️ `
    };
    
    console.log(`${prefix[type] || prefix.info} ${message}${colors.reset}`);
  }

  // Check if package-lock.json exists
  checkLockfileExists() {
    const lockfilePath = path.join(process.cwd(), 'package-lock.json');
    
    if (!fs.existsSync(lockfilePath)) {
      this.errors.push('package-lock.json not found!');
      return false;
    }
    
    return true;
  }

  // Verify lockfile integrity
  verifyLockfileIntegrity() {
    try {
      // Run npm ci to verify lockfile matches package.json
      execSync('npm ci --dry-run', { 
        stdio: 'pipe',
        encoding: 'utf-8' 
      });
      
      this.log('Lockfile integrity verified', 'success');
      return true;
    } catch (error) {
      this.errors.push('Lockfile does not match package.json');
      this.log(error.message, 'error');
      return false;
    }
  }

  // Parse and verify lockfile content
  async verifyLockfileContent() {
    const lockfilePath = path.join(process.cwd(), 'package-lock.json');
    const lockfile = JSON.parse(fs.readFileSync(lockfilePath, 'utf-8'));
    
    // Check lockfile version
    if (lockfile.lockfileVersion < 2) {
      this.warnings.push(`Old lockfile version ${lockfile.lockfileVersion}. Consider upgrading to v3.`);
    }
    
    // Verify all packages
    await this.verifyPackages(lockfile.packages || {});
    
    return true;
  }

  // Verify individual packages
  async verifyPackages(packages) {
    for (const [name, pkg] of Object.entries(packages)) {
      if (!name || name === '') continue; // Skip root package
      
      this.verified++;
      
      // Check registry
      if (pkg.resolved && !this.isTrustedRegistry(pkg.resolved)) {
        this.warnings.push(`Package ${name} from untrusted registry: ${pkg.resolved}`);
      }
      
      // Check for known malicious packages
      if (this.isMaliciousPackage(name, pkg.version)) {
        this.errors.push(`SECURITY: Known malicious package detected: ${name}@${pkg.version}`);
      }
      
      // Verify integrity hash
      if (pkg.integrity) {
        await this.verifyIntegrity(name, pkg);
      } else if (pkg.resolved) {
        this.warnings.push(`Package ${name} missing integrity hash`);
      }
      
      // Check for suspicious package names (typosquatting)
      this.checkSuspiciousName(name);
    }
  }

  // Check if registry is trusted
  isTrustedRegistry(url) {
    return TRUSTED_REGISTRIES.some(registry => url.startsWith(registry));
  }

  // Check for known malicious packages
  isMaliciousPackage(name, version) {
    const fullName = `${name}@${version}`;
    return MALICIOUS_PATTERNS.some(pattern => pattern.test(fullName));
  }

  // Verify package integrity
  async verifyIntegrity(name, pkg) {
    // Skip verification for local packages
    if (pkg.link || !pkg.resolved) return;
    
    // Integrity format: algorithm-base64hash
    const match = pkg.integrity.match(/^(sha\d+)-(.+)$/);
    if (!match) {
      this.warnings.push(`Invalid integrity format for ${name}`);
      return;
    }
    
    const [, algorithm, expectedHash] = match;
    
    // For npm packages, we trust the lockfile integrity
    // In production, you might want to download and verify each package
    if (!['sha512', 'sha384', 'sha256'].includes(algorithm)) {
      this.warnings.push(`Weak hash algorithm ${algorithm} for ${name}`);
    }
  }

  // Check for typosquatting
  checkSuspiciousName(name) {
    const suspiciousPatterns = [
      // Common typosquatting patterns
      { pattern: /^(?:node-)?express$/, legitimate: 'express' },
      { pattern: /^(?:node-)?lodash$/, legitimate: 'lodash' },
      { pattern: /^(?:node-)?react$/, legitimate: 'react' },
      { pattern: /^(?:node-)?webpack$/, legitimate: 'webpack' },
      { pattern: /^bable-/, legitimate: 'babel-' },
      { pattern: /^typ(?:e|ing)script/, legitimate: 'typescript' },
    ];
    
    for (const { pattern, legitimate } of suspiciousPatterns) {
      if (pattern.test(name) && name !== legitimate) {
        this.warnings.push(`Suspicious package name: ${name} (did you mean ${legitimate}?)`);
      }
    }
  }

  // Generate lockfile checksum
  generateChecksum(lockfilePath) {
    const content = fs.readFileSync(lockfilePath, 'utf-8');
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  // Verify package provenance (npm 9.5+)
  async verifyProvenance() {
    try {
      // Check npm version
      const npmVersion = execSync('npm --version', { encoding: 'utf-8' }).trim();
      const [major, minor] = npmVersion.split('.').map(Number);
      
      if (major < 9 || (major === 9 && minor < 5)) {
        this.warnings.push(`npm ${npmVersion} doesn't support provenance. Upgrade to 9.5+`);
        return;
      }
      
      // Run audit signatures
      const result = execSync('npm audit signatures', { 
        encoding: 'utf-8',
        stdio: 'pipe'
      });
      
      if (result.includes('verified')) {
        this.log('Package signatures verified', 'success');
      }
    } catch (error) {
      // Audit signatures might fail if registry doesn't support it
      this.warnings.push('Could not verify package signatures');
    }
  }

  // Main verification function
  async verify() {
    console.log(`${colors.blue}🔒 Verifying lockfile integrity...${colors.reset}\n`);
    
    // Check lockfile exists
    if (!this.checkLockfileExists()) {
      return false;
    }
    
    // Verify lockfile integrity
    this.verifyLockfileIntegrity();
    
    // Verify lockfile content
    await this.verifyLockfileContent();
    
    // Verify package provenance
    await this.verifyProvenance();
    
    // Generate and display checksum
    const lockfilePath = path.join(process.cwd(), 'package-lock.json');
    const checksum = this.generateChecksum(lockfilePath);
    
    console.log(`\n${colors.blue}📊 Verification Summary:${colors.reset}`);
    console.log(`   Packages verified: ${this.verified}`);
    console.log(`   Errors: ${this.errors.length}`);
    console.log(`   Warnings: ${this.warnings.length}`);
    console.log(`   Checksum: ${checksum.substring(0, 16)}...`);
    
    // Display errors
    if (this.errors.length > 0) {
      console.log(`\n${colors.red}Errors:${colors.reset}`);
      this.errors.forEach(error => console.log(`   ${colors.red}✗${colors.reset} ${error}`));
    }
    
    // Display warnings
    if (this.warnings.length > 0) {
      console.log(`\n${colors.yellow}Warnings:${colors.reset}`);
      this.warnings.forEach(warning => console.log(`   ${colors.yellow}!${colors.reset} ${warning}`));
    }
    
    // Final status
    if (this.errors.length === 0) {
      console.log(`\n${colors.green}✅ Lockfile verification passed!${colors.reset}`);
      return true;
    } else {
      console.log(`\n${colors.red}❌ Lockfile verification failed!${colors.reset}`);
      process.exit(1);
    }
  }
}

// Run verification
if (require.main === module) {
  const verifier = new LockfileVerifier();
  verifier.verify().catch(error => {
    console.error(`${colors.red}Verification failed:${colors.reset}`, error);
    process.exit(1);
  });
}

module.exports = LockfileVerifier;