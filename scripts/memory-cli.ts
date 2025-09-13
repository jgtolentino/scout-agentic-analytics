#!/usr/bin/env bun
import { 
  storeMemory, 
  recallMemory, 
  getMemoryTags, 
  clearMemory, 
  getMemoryStats,
  storeProjectContext,
  recallProjectContext
} from './claude_memory_bridge';

const args = process.argv.slice(2);
const [action, ...rest] = args;

function printUsage() {
  console.log(`
🧠 Claude Memory CLI

Usage:
  bun memory-cli.ts store <tag> <content>       - Store memory with tag
  bun memory-cli.ts recall <tag> [limit]       - Recall memories by tag
  bun memory-cli.ts project-store <name> <ctx> - Store project context
  bun memory-cli.ts project-recall <name>      - Recall project context
  bun memory-cli.ts tags                       - List all memory tags
  bun memory-cli.ts stats                      - Show memory statistics
  bun memory-cli.ts clear [tag]                - Clear memories (all or by tag)

Examples:
  bun memory-cli.ts store "scout-project" "MCP bridge configured"
  bun memory-cli.ts recall "scout-project" 3
  bun memory-cli.ts project-store "scout" "v4.0.0 deployment ready"
  bun memory-cli.ts clear "old-project"
  `);
}

async function main() {
  try {
    switch (action) {
      case 'store': {
        const [tag, ...contentParts] = rest;
        if (!tag || contentParts.length === 0) {
          console.error('❌ Usage: store <tag> <content>');
          process.exit(1);
        }
        const content = contentParts.join(' ');
        const sessionId = new Date().toISOString().split('T')[0];
        storeMemory(sessionId, tag, content);
        console.log(`✅ Stored memory with tag: ${tag}`);
        break;
      }

      case 'recall': {
        const [tag, limitStr] = rest;
        if (!tag) {
          console.error('❌ Usage: recall <tag> [limit]');
          process.exit(1);
        }
        const limit = limitStr ? parseInt(limitStr) : 5;
        const memories = recallMemory(tag, limit);
        console.log(`🧠 Memories for tag "${tag}":`);
        memories.forEach((memory, index) => {
          console.log(`  ${index + 1}. ${memory}`);
        });
        break;
      }

      case 'project-store': {
        const [projectName, ...contextParts] = rest;
        if (!projectName || contextParts.length === 0) {
          console.error('❌ Usage: project-store <name> <context>');
          process.exit(1);
        }
        const context = contextParts.join(' ');
        storeProjectContext(projectName, context);
        console.log(`✅ Stored project context for: ${projectName}`);
        break;
      }

      case 'project-recall': {
        const [projectName, limitStr] = rest;
        if (!projectName) {
          console.error('❌ Usage: project-recall <name> [limit]');
          process.exit(1);
        }
        const limit = limitStr ? parseInt(limitStr) : 3;
        const contexts = recallProjectContext(projectName, limit);
        console.log(`🏗️  Project context for "${projectName}":`);
        contexts.forEach((context, index) => {
          console.log(`  ${index + 1}. ${context}`);
        });
        break;
      }

      case 'tags': {
        const tags = getMemoryTags();
        console.log('🏷️  Available memory tags:');
        tags.forEach(tag => console.log(`  - ${tag}`));
        break;
      }

      case 'stats': {
        const stats = getMemoryStats();
        console.log('📊 Memory Statistics:');
        console.log(`  Total memories: ${stats.total}`);
        console.log('  By tag:');
        stats.byTag.forEach((item: any) => {
          console.log(`    ${item.tag}: ${item.count}`);
        });
        break;
      }

      case 'clear': {
        const [tag] = rest;
        if (tag) {
          clearMemory(tag);
          console.log(`🗑️  Cleared memories for tag: ${tag}`);
        } else {
          console.log('⚠️  This will clear ALL memories. Are you sure? (y/N)');
          const response = await new Promise<string>((resolve) => {
            process.stdin.once('data', (data) => {
              resolve(data.toString().trim().toLowerCase());
            });
          });
          if (response === 'y' || response === 'yes') {
            clearMemory();
            console.log('🗑️  Cleared all memories');
          } else {
            console.log('❌ Operation cancelled');
          }
        }
        break;
      }

      default:
        printUsage();
        break;
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();