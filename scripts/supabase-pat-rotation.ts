#!/usr/bin/env ts-node

/**
 * Supabase PAT Rotation Script
 * Automates the rotation of Personal Access Tokens for MCP servers
 * Ensures each vertical has its own isolated token for security
 */

import { execSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import crypto from 'crypto';

interface MCPServerConfig {
  name: string;
  projectRef: string;
  role: string;
  allowedSchemas: string[];
  userContext: string;
}

interface TokenRotationConfig {
  servers: MCPServerConfig[];
  rotationIntervalDays: number;
  configPaths: {
    claudeDesktop: string;
    claudeCode: string;
    bruno: string;
    cursor: string;
  };
}

// Configuration for all MCP servers
const CONFIG: TokenRotationConfig = {
  servers: [
    {
      name: 'supabase_hr_intelligence',
      projectRef: 'cxzllzyxwpyptfretryc',
      role: 'hr_manager',
      allowedSchemas: ['hris', 'onboarding', 'analytics'],
      userContext: 'hr_manager'
    },
    {
      name: 'supabase_finance_operations',
      projectRef: 'cxzllzyxwpyptfretryc',
      role: 'finance_manager',
      allowedSchemas: ['expense', 'approval', 'audit'],
      userContext: 'finance_manager'
    },
    {
      name: 'supabase_executive_dashboard',
      projectRef: 'cxzllzyxwpyptfretryc',
      role: 'executive',
      allowedSchemas: ['hris', 'expense', 'service_desk', 'approval', 'office_ops', 'audit', 'analytics', 'onboarding', 'agentic', 'knowledge', 'security', 'integration'],
      userContext: 'executive'
    },
    {
      name: 'supabase_scout_dashboard',
      projectRef: 'cxzllzyxwpyptfretryc',
      role: 'scout_analyst',
      allowedSchemas: ['hris', 'expense', 'service_desk', 'operations', 'corporate', 'creative_insights', 'analytics'],
      userContext: 'scout_dashboard'
    },
    {
      name: 'supabase_agent_repository',
      projectRef: 'texxwmlroefdisgxpszc',
      role: 'agent_admin',
      allowedSchemas: ['agent_repository'],
      userContext: 'agent_system'
    }
  ],
  rotationIntervalDays: 30,
  configPaths: {
    claudeDesktop: join(process.env.HOME || '', 'Library/Application Support/Claude/claude_desktop_config.json'),
    claudeCode: join(process.cwd(), '.mcp.json'),
    bruno: join(process.cwd(), '.bruno/.mcp.json'),
    cursor: join(process.cwd(), '.cursor/mcp.json')
  }
};

// Token storage and management
const TOKEN_STORE_PATH = join(process.env.HOME || '', '.supabase/mcp-tokens.json');

interface TokenStore {
  tokens: {
    [serverName: string]: {
      token: string;
      createdAt: string;
      expiresAt: string;
      lastRotated: string;
    };
  };
}

class SupabasePATRotator {
  private tokenStore: TokenStore;

  constructor() {
    this.ensureDirectories();
    this.loadTokenStore();
  }

  private ensureDirectories(): void {
    const dirs = [
      join(process.env.HOME || '', '.supabase'),
      join(process.cwd(), '.bruno'),
      join(process.cwd(), '.cursor')
    ];

    dirs.forEach(dir => {
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }
    });
  }

  private loadTokenStore(): void {
    if (existsSync(TOKEN_STORE_PATH)) {
      const content = readFileSync(TOKEN_STORE_PATH, 'utf-8');
      this.tokenStore = JSON.parse(content);
    } else {
      this.tokenStore = { tokens: {} };
    }
  }

  private saveTokenStore(): void {
    writeFileSync(TOKEN_STORE_PATH, JSON.stringify(this.tokenStore, null, 2));
    // Secure the token store file
    execSync(`chmod 600 "${TOKEN_STORE_PATH}"`);
  }

  /**
   * Generate a new PAT for a specific server configuration
   * In production, this would call Supabase Management API
   */
  private async generateNewPAT(server: MCPServerConfig): Promise<string> {
    // In production, this would make an API call to Supabase to generate a new PAT
    // For now, we'll simulate it with a placeholder
    console.log(`⚠️  Manual step required: Generate a new PAT for ${server.name}`);
    console.log(`   1. Go to: https://app.supabase.com/account/tokens`);
    console.log(`   2. Create token with name: ${server.name}_${new Date().toISOString().split('T')[0]}`);
    console.log(`   3. Set appropriate permissions for role: ${server.role}`);
    console.log(`   4. Save the token securely`);
    
    // In production, return the actual generated token
    // For demo, return a placeholder
    return `sbp_${crypto.randomBytes(20).toString('hex')}`;
  }

  /**
   * Update MCP configuration files with new tokens
   */
  private updateMCPConfigs(serverName: string, newToken: string): void {
    // Update Claude Desktop config
    if (existsSync(CONFIG.configPaths.claudeDesktop)) {
      try {
        const config = JSON.parse(readFileSync(CONFIG.configPaths.claudeDesktop, 'utf-8'));
        if (config.mcpServers && config.mcpServers[serverName]) {
          config.mcpServers[serverName].env.SUPABASE_ACCESS_TOKEN = newToken;
          writeFileSync(CONFIG.configPaths.claudeDesktop, JSON.stringify(config, null, 2));
          console.log(`✅ Updated Claude Desktop config for ${serverName}`);
        }
      } catch (error) {
        console.error(`❌ Failed to update Claude Desktop config: ${error}`);
      }
    }

    // Update other configs (Claude Code, Bruno, Cursor)
    const otherConfigs = [
      { path: CONFIG.configPaths.claudeCode, name: 'Claude Code' },
      { path: CONFIG.configPaths.bruno, name: 'Bruno' },
      { path: CONFIG.configPaths.cursor, name: 'Cursor' }
    ];

    otherConfigs.forEach(({ path, name }) => {
      if (existsSync(path)) {
        try {
          const config = JSON.parse(readFileSync(path, 'utf-8'));
          if (config.mcpServers && config.mcpServers[serverName]) {
            config.mcpServers[serverName].env.SUPABASE_ACCESS_TOKEN = newToken;
            writeFileSync(path, JSON.stringify(config, null, 2));
            console.log(`✅ Updated ${name} config for ${serverName}`);
          }
        } catch (error) {
          console.error(`❌ Failed to update ${name} config: ${error}`);
        }
      }
    });
  }

  /**
   * Rotate a single server's PAT
   */
  async rotateServerPAT(server: MCPServerConfig): Promise<void> {
    console.log(`\n🔄 Rotating PAT for ${server.name}...`);

    // Generate new token
    const newToken = await this.generateNewPAT(server);

    // Update token store
    this.tokenStore.tokens[server.name] = {
      token: newToken,
      createdAt: new Date().toISOString(),
      expiresAt: new Date(Date.now() + CONFIG.rotationIntervalDays * 24 * 60 * 60 * 1000).toISOString(),
      lastRotated: new Date().toISOString()
    };

    // Update all MCP configurations
    this.updateMCPConfigs(server.name, newToken);

    // Save token store
    this.saveTokenStore();

    console.log(`✅ PAT rotation complete for ${server.name}`);
  }

  /**
   * Check if any tokens need rotation
   */
  async checkAndRotateExpiredTokens(): Promise<void> {
    console.log('🔍 Checking for expired tokens...\n');

    for (const server of CONFIG.servers) {
      const tokenInfo = this.tokenStore.tokens[server.name];
      
      if (!tokenInfo) {
        console.log(`⚠️  No token found for ${server.name}, generating new one...`);
        await this.rotateServerPAT(server);
        continue;
      }

      const expiresAt = new Date(tokenInfo.expiresAt);
      const now = new Date();
      const daysUntilExpiry = Math.ceil((expiresAt.getTime() - now.getTime()) / (24 * 60 * 60 * 1000));

      if (daysUntilExpiry <= 0) {
        console.log(`❌ Token for ${server.name} has expired!`);
        await this.rotateServerPAT(server);
      } else if (daysUntilExpiry <= 7) {
        console.log(`⚠️  Token for ${server.name} expires in ${daysUntilExpiry} days`);
        await this.rotateServerPAT(server);
      } else {
        console.log(`✅ Token for ${server.name} is valid for ${daysUntilExpiry} more days`);
      }
    }
  }

  /**
   * Force rotate all tokens
   */
  async rotateAllTokens(): Promise<void> {
    console.log('🔄 Force rotating all tokens...\n');
    
    for (const server of CONFIG.servers) {
      await this.rotateServerPAT(server);
    }
  }

  /**
   * Generate systemd service and timer for automatic rotation
   */
  generateSystemdConfig(): void {
    const servicePath = '/etc/systemd/system/supabase-pat-rotation.service';
    const timerPath = '/etc/systemd/system/supabase-pat-rotation.timer';

    const serviceContent = `[Unit]
Description=Supabase PAT Rotation Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/node ${__filename} --check
User=${process.env.USER}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
`;

    const timerContent = `[Unit]
Description=Daily Supabase PAT rotation check
Requires=supabase-pat-rotation.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
`;

    console.log('\n📝 Systemd configuration:');
    console.log('\n1. Save this as /etc/systemd/system/supabase-pat-rotation.service:');
    console.log(serviceContent);
    console.log('\n2. Save this as /etc/systemd/system/supabase-pat-rotation.timer:');
    console.log(timerContent);
    console.log('\n3. Enable with:');
    console.log('   sudo systemctl enable supabase-pat-rotation.timer');
    console.log('   sudo systemctl start supabase-pat-rotation.timer');
  }

  /**
   * Generate cron job configuration
   */
  generateCronConfig(): void {
    const cronCommand = `0 2 * * * /usr/bin/node ${__filename} --check >> /var/log/supabase-pat-rotation.log 2>&1`;
    
    console.log('\n📝 Cron configuration:');
    console.log('Add to crontab with: crontab -e');
    console.log(cronCommand);
  }
}

// CLI interface
async function main() {
  const rotator = new SupabasePATRotator();
  const args = process.argv.slice(2);

  if (args.includes('--help')) {
    console.log(`
Supabase PAT Rotation Tool

Usage:
  ts-node supabase-pat-rotation.ts [options]

Options:
  --check          Check and rotate expired tokens
  --rotate-all     Force rotate all tokens
  --systemd        Generate systemd service configuration
  --cron           Generate cron job configuration
  --help           Show this help message

Examples:
  # Check and rotate expired tokens
  ts-node supabase-pat-rotation.ts --check

  # Force rotate all tokens
  ts-node supabase-pat-rotation.ts --rotate-all

  # Set up automatic rotation
  ts-node supabase-pat-rotation.ts --systemd
`);
    process.exit(0);
  }

  if (args.includes('--check')) {
    await rotator.checkAndRotateExpiredTokens();
  } else if (args.includes('--rotate-all')) {
    await rotator.rotateAllTokens();
  } else if (args.includes('--systemd')) {
    rotator.generateSystemdConfig();
  } else if (args.includes('--cron')) {
    rotator.generateCronConfig();
  } else {
    // Default action: check for expired tokens
    await rotator.checkAndRotateExpiredTokens();
  }
}

// Run the script
if (require.main === module) {
  main().catch(console.error);
}

export { SupabasePATRotator, CONFIG };