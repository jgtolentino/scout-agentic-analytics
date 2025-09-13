#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Generate release notes from git commits
 */
function generateReleaseNotes(fromTag, toTag = 'HEAD') {
  const commits = execSync(
    `git log ${fromTag}..${toTag} --pretty=format:"%H|%s|%b|%an|%ae|%ai" --no-merges`,
    { encoding: 'utf8' }
  ).trim().split('\n');

  const categorized = {
    breaking: [],
    features: [],
    fixes: [],
    performance: [],
    reverts: [],
    docs: [],
    style: [],
    refactor: [],
    tests: [],
    build: [],
    ci: [],
    chore: []
  };

  commits.forEach(commit => {
    const [hash, subject, body, authorName, authorEmail, date] = commit.split('|');
    const shortHash = hash.substring(0, 7);
    
    // Parse conventional commit
    const match = subject.match(/^(\w+)(?:\(([^)]+)\))?: (.+)$/);
    if (!match) return;

    const [, type, scope, description] = match;
    const isBreaking = subject.includes('!') || body.includes('BREAKING CHANGE');

    const entry = {
      hash: shortHash,
      type,
      scope,
      description,
      body,
      author: authorName,
      email: authorEmail,
      date: new Date(date),
      breaking: isBreaking
    };

    if (isBreaking) {
      categorized.breaking.push(entry);
    }

    switch (type) {
      case 'feat':
        categorized.features.push(entry);
        break;
      case 'fix':
        categorized.fixes.push(entry);
        break;
      case 'perf':
        categorized.performance.push(entry);
        break;
      case 'revert':
        categorized.reverts.push(entry);
        break;
      case 'docs':
        categorized.docs.push(entry);
        break;
      case 'style':
        categorized.style.push(entry);
        break;
      case 'refactor':
        categorized.refactor.push(entry);
        break;
      case 'test':
        categorized.tests.push(entry);
        break;
      case 'build':
        categorized.build.push(entry);
        break;
      case 'ci':
        categorized.ci.push(entry);
        break;
      case 'chore':
        categorized.chore.push(entry);
        break;
    }
  });

  return categorized;
}

/**
 * Format release notes as markdown
 */
function formatReleaseNotes(version, date, categorized) {
  const lines = [];
  
  lines.push(`# ${version} (${date.toISOString().split('T')[0]})`);
  lines.push('');

  if (categorized.breaking.length > 0) {
    lines.push('## ⚠️ BREAKING CHANGES');
    lines.push('');
    categorized.breaking.forEach(commit => {
      lines.push(`* ${commit.scope ? `**${commit.scope}:** ` : ''}${commit.description} (${commit.hash})`);
      if (commit.body) {
        const breakingMessage = commit.body.match(/BREAKING CHANGE: (.+)/);
        if (breakingMessage) {
          lines.push(`  ${breakingMessage[1]}`);
        }
      }
    });
    lines.push('');
  }

  const sections = [
    { title: '## ✨ Features', commits: categorized.features },
    { title: '## 🐛 Bug Fixes', commits: categorized.fixes },
    { title: '## ⚡ Performance Improvements', commits: categorized.performance },
    { title: '## ⏪ Reverts', commits: categorized.reverts },
    { title: '## 📝 Documentation', commits: categorized.docs },
    { title: '## 🎨 Styles', commits: categorized.style },
    { title: '## ♻️ Code Refactoring', commits: categorized.refactor },
    { title: '## ✅ Tests', commits: categorized.tests },
    { title: '## 📦 Build System', commits: categorized.build },
    { title: '## 👷 CI/CD', commits: categorized.ci }
  ];

  sections.forEach(section => {
    if (section.commits.length > 0) {
      lines.push(section.title);
      lines.push('');
      section.commits.forEach(commit => {
        lines.push(`* ${commit.scope ? `**${commit.scope}:** ` : ''}${commit.description} (${commit.hash})`);
      });
      lines.push('');
    }
  });

  // Contributors
  const contributors = new Map();
  Object.values(categorized).flat().forEach(commit => {
    if (!contributors.has(commit.email)) {
      contributors.set(commit.email, commit.author);
    }
  });

  if (contributors.size > 0) {
    lines.push('## 👥 Contributors');
    lines.push('');
    Array.from(contributors.values()).sort().forEach(name => {
      lines.push(`* ${name}`);
    });
    lines.push('');
  }

  return lines.join('\n');
}

/**
 * Update CHANGELOG.md
 */
function updateChangelog(content) {
  const changelogPath = path.join(process.cwd(), 'CHANGELOG.md');
  let existingContent = '';
  
  if (fs.existsSync(changelogPath)) {
    existingContent = fs.readFileSync(changelogPath, 'utf8');
  }

  // Insert new content after the title
  const lines = existingContent.split('\n');
  const titleIndex = lines.findIndex(line => line.startsWith('# Changelog'));
  
  if (titleIndex >= 0) {
    lines.splice(titleIndex + 2, 0, content);
  } else {
    lines.unshift('# Changelog', '', content);
  }

  fs.writeFileSync(changelogPath, lines.join('\n'));
}

// CLI
if (require.main === module) {
  const args = process.argv.slice(2);
  const version = args[0] || require('../package.json').version;
  const fromTag = args[1] || execSync('git describe --tags --abbrev=0', { encoding: 'utf8' }).trim();
  
  console.log(`Generating release notes for ${version} (from ${fromTag})...`);
  
  const categorized = generateReleaseNotes(fromTag);
  const notes = formatReleaseNotes(version, new Date(), categorized);
  
  if (args.includes('--update-changelog')) {
    updateChangelog(notes);
    console.log('CHANGELOG.md updated!');
  } else {
    console.log(notes);
  }
}

module.exports = {
  generateReleaseNotes,
  formatReleaseNotes,
  updateChangelog
};