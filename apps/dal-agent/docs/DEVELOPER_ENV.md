# Developer Environment Setup

## Required Tools Installation

### Bruno CLI
```sh
# Install Bruno CLI
npm i -g @usebruno/cli

# Verify installation
bru --version
```

### Bruno Shim Setup
```sh
# Create shim directory
mkdir -p ~/.local/bin

# Create Bruno shim
cat > ~/.local/bin/bruno <<'SH'
#!/usr/bin/env bash
# Bruno shim: forwards to Bruno CLI 'bru'
exec bru "$@"
SH

# Make executable
chmod +x ~/.local/bin/bruno
```

## Environment Configuration

### Shell Profile Setup
Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```sh
# Bruno global configuration
export BRUNO_HOME="$HOME/.bruno"
export BRUNO_CMD="bruno"
export PATH="$HOME/.local/bin:$PATH"
```

### Bruno Vault Initialization
```sh
# Create vault directory
mkdir -p ~/.bruno/vault

# Set proper permissions
chmod 700 ~/.bruno/vault
```

## Azure Integration

### Azure CLI Setup
```sh
# Install Azure CLI (if not already installed)
brew install azure-cli

# Login to Azure
az login

# Set subscription
az account set --subscription "c03c092c-443c-4f25-9efe-33f092621251"
```

### Azure SQL Keychain Setup
The project uses macOS Keychain for Azure SQL connection strings:

```sh
# The connection is already configured for this project
# Access via: scripts/conn_default.sh
```

## Verification Commands

### Tool Verification
```sh
# Check Bruno
bruno --version || bru --version

# Check Azure CLI
az --version
az account show

# Check vault access
ls -la ~/.bruno/vault
```

### Project-Specific Verification
```sh
# Navigate to project
cd /Users/tbwa/scout-v7/apps/dal-agent

# Run preflight check
./scripts/check_bruno.sh

# Test database connection
bash scripts/conn_default.sh | head -c 50
```

## Troubleshooting

### Bruno Command Not Found
```sh
# Check PATH
echo $PATH | grep -o ~/.local/bin

# Reload shell configuration
source ~/.zshrc  # or ~/.bashrc
```

### Azure Connection Issues
```sh
# Check keychain access
security find-generic-password -s "SQL-TBWA-ProjectScout-Reporting-Prod"

# Verify Azure login
az account show
```

### Vault Permissions
```sh
# Fix vault permissions if needed
chmod 700 ~/.bruno/vault
chmod 600 ~/.bruno/vault/*
```

> **Azure-only profile:** This project uses Azure SQL, Azure Functions, Azure AI Search, Azure Key Vault, and Azure OpenAI. No Supabase components are required.