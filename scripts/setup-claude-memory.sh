#!/bin/bash
# Claude Desktop Memory Setup Script
# This script sets up the complete Claude Desktop persistent memory system

set -e

echo "🧠 Setting up Claude Desktop Memory System..."

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p ~/.claude/memory
mkdir -p ~/agents
mkdir -p ~/scripts

# Check if we're in the right directory
if [[ ! -f "scripts/claude_memory_bridge.ts" ]]; then
    echo "❌ Error: Run this script from the project root directory"
    exit 1
fi

# Initialize SQLite database
echo "🗄️  Initializing SQLite database..."
sqlite3 ~/.claude/memory/context.db < scripts/create_memory_schema.sql

# Make CLI executable
echo "🔧 Making CLI executable..."
chmod +x scripts/memory-cli.ts

# Install dependencies if package.json exists
if [[ -f "package.json" ]]; then
    echo "📦 Installing dependencies..."
    if command -v bun &> /dev/null; then
        bun install
    elif command -v npm &> /dev/null; then
        npm install
    else
        echo "⚠️  No package manager found. Please install bun or npm."
    fi
fi

# Create symlinks for easy access
echo "🔗 Creating symlinks..."
ln -sf "$(pwd)/scripts/memory-cli.ts" ~/.local/bin/memory-cli 2>/dev/null || true
ln -sf "$(pwd)/agents/memory-agent.yaml" ~/.pulser/agents/memory-agent.yaml 2>/dev/null || true

# Test the setup
echo "🧪 Testing setup..."
if command -v bun &> /dev/null; then
    echo "Testing memory CLI..."
    bun scripts/memory-cli.ts store "setup-test" "Memory system initialized successfully"
    echo "✅ Test passed!"
    
    echo "Memory stats:"
    bun scripts/memory-cli.ts stats
else
    echo "⚠️  Bun not found. Please install bun to use the memory CLI."
fi

echo "
✅ Claude Desktop Memory System setup complete!

📋 What was created:
  - ~/.claude/memory/context.db (SQLite database)
  - scripts/claude_memory_bridge.ts (MCP bridge)
  - agents/memory-agent.yaml (Pulser agent)
  - scripts/memory-cli.ts (CLI tool)
  - scripts/create_memory_schema.sql (SQL schema)

🚀 Usage Examples:
  
  # Store memory
  bun scripts/memory-cli.ts store \"scout-project\" \"MCP bridge configured\"
  
  # Recall memories
  bun scripts/memory-cli.ts recall \"scout-project\" 3
  
  # Store project context
  bun scripts/memory-cli.ts project-store \"scout\" \"v4.0.0 deployment ready\"
  
  # Run via Pulser
  pulser run memory-agent.yaml --fn recallMemory --args '{\"tag\":\"scout-project\",\"limit\":3}'

📖 Integration:
  - Add to Claude Desktop startup script
  - Use with MCP server configuration
  - Integrate with Pulser agent workflows

🔗 Next Steps:
  1. Configure Claude Desktop to use the memory bridge
  2. Set up MCP server integration
  3. Test cross-session memory persistence
"