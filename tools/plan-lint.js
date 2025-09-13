#!/usr/bin/env node
/**
 * Plan Linter - SuperClaude Framework
 * Validates that generated plan files contain all required sections
 */

const fs = require('fs');
const path = require('path');

const REQUIRED_SECTIONS = [
  '## Context',
  '## Detailed Tasks',
  '## File Diffs',
  '## Tests',
  '## Dependencies & Integration Points',
  '## Risks & Simplifications',
  '## Definition of Done',
  '## Verification Steps'
];

const REQUIRED_FRONTMATTER_FIELDS = [
  'title:',
  'id:',
  'owner:',
  'effort:',
  'dependencies:',
  'artifacts:'
];

function lintPlanFile(filePath) {
  const fileName = path.basename(filePath);
  const content = fs.readFileSync(filePath, 'utf8');
  
  const errors = [];
  const warnings = [];

  // Check frontmatter
  if (!content.startsWith('---')) {
    errors.push('Missing frontmatter block');
  } else {
    const frontmatterEnd = content.indexOf('---', 3);
    if (frontmatterEnd === -1) {
      errors.push('Unclosed frontmatter block');
    } else {
      const frontmatter = content.substring(0, frontmatterEnd + 3);
      
      REQUIRED_FRONTMATTER_FIELDS.forEach(field => {
        if (!frontmatter.includes(field)) {
          errors.push(`Missing frontmatter field: ${field}`);
        }
      });

      // Check superclaude section in frontmatter
      if (!frontmatter.includes('superclaude:')) {
        warnings.push('Missing SuperClaude configuration in frontmatter');
      }
    }
  }

  // Check required sections
  REQUIRED_SECTIONS.forEach(section => {
    if (!content.includes(section)) {
      errors.push(`Missing section: ${section}`);
    }
  });

  // Check for empty sections
  REQUIRED_SECTIONS.forEach(section => {
    const sectionIndex = content.indexOf(section);
    if (sectionIndex !== -1) {
      const nextSectionIndex = content.indexOf('##', sectionIndex + section.length);
      const sectionContent = nextSectionIndex !== -1 
        ? content.substring(sectionIndex + section.length, nextSectionIndex)
        : content.substring(sectionIndex + section.length);
      
      if (sectionContent.trim().length < 50) { // Arbitrarily small threshold
        warnings.push(`Section appears empty or too brief: ${section}`);
      }
    }
  });

  // Check for TODOs
  const todoMatches = content.match(/TODO|FIXME|XXX/gi);
  if (todoMatches && todoMatches.length > 0) {
    warnings.push(`Contains ${todoMatches.length} TODO/FIXME markers`);
  }

  // Check effort values
  const effortMatch = content.match(/effort:\s*([SML])/);
  if (effortMatch) {
    const effort = effortMatch[1];
    if (!['S', 'M', 'L'].includes(effort)) {
      errors.push(`Invalid effort value: ${effort} (must be S, M, or L)`);
    }
  }

  // Check file naming convention
  const nameMatch = fileName.match(/^(\d{2})-(.+)\.md$/);
  if (!nameMatch) {
    errors.push('File name must follow pattern: NN-slug.md (e.g., 01-database-schemas.md)');
  }

  return { errors, warnings };
}

function main() {
  const plansDir = path.resolve('/Users/tbwa/plans');
  
  if (!fs.existsSync(plansDir)) {
    console.error('❌ Plans directory does not exist: /Users/tbwa/plans');
    console.error('   Run the Architect agent first to generate plan files.');
    process.exit(1);
  }

  const planFiles = fs.readdirSync(plansDir)
    .filter(f => f.endsWith('.md'))
    .sort();

  if (planFiles.length === 0) {
    console.error('❌ No plan files found in /Users/tbwa/plans/');
    console.error('   Run the Architect agent with bootstrap prompt to generate plans.');
    process.exit(1);
  }

  let totalErrors = 0;
  let totalWarnings = 0;

  console.log(`🔍 Linting ${planFiles.length} plan files...\n`);

  planFiles.forEach(fileName => {
    const filePath = path.join(plansDir, fileName);
    const { errors, warnings } = lintPlanFile(filePath);
    
    if (errors.length === 0 && warnings.length === 0) {
      console.log(`✅ ${fileName}`);
    } else {
      if (errors.length > 0) {
        console.log(`❌ ${fileName}`);
        errors.forEach(error => console.log(`   ERROR: ${error}`));
        totalErrors += errors.length;
      } else {
        console.log(`⚠️  ${fileName}`);
      }
      
      if (warnings.length > 0) {
        warnings.forEach(warning => console.log(`   WARN:  ${warning}`));
        totalWarnings += warnings.length;
      }
    }
  });

  console.log(`\n📊 Summary:`);
  console.log(`   Files checked: ${planFiles.length}`);
  console.log(`   Errors: ${totalErrors}`);
  console.log(`   Warnings: ${totalWarnings}`);

  if (totalErrors > 0) {
    console.log('\n❌ Plan linting FAILED. Fix errors above before implementation.');
    process.exit(1);
  } else if (totalWarnings > 0) {
    console.log('\n⚠️  Plan linting PASSED with warnings. Consider addressing warnings.');
    process.exit(0);
  } else {
    console.log('\n✅ All plans are structurally sound and ready for implementation.');
    process.exit(0);
  }
}

if (require.main === module) {
  main();
}

module.exports = { lintPlanFile };