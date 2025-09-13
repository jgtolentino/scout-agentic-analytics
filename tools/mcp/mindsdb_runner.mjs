import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

function spawnMcp(cmd, args, env) {
  const child = spawn(cmd, args, { env: { ...process.env, ...env }, stdio: ['pipe','pipe','inherit'] });
  const transport = new StdioClientTransport(child.stdin, child.stdout);
  return { child, transport };
}

async function withClient(env, fn) {
  const cmd = 'node';
  const args = ['mcp-servers/mindsdb/server.py'];
  const { child, transport } = spawnMcp(cmd, args, env);
  const client = new Client({ name: 'mcp-runner', version: '0.1.0' }, { capabilities: {} });
  await client.connect(transport);
  try { return await fn(client); }
  finally { try { await client.close(); } catch {} child.kill(); }
}

function readSqlFiles(inputs) {
  const files = [];
  const add = f => { if (fs.existsSync(f) && fs.statSync(f).isFile() && f.endsWith('.sql')) files.push(path.resolve(f)); };
  for (const i of inputs) {
    const p = path.resolve(i);
    if (!fs.existsSync(p)) continue;
    const st = fs.statSync(p);
    if (st.isFile()) add(p);
    else if (st.isDirectory()) {
      for (const f of fs.readdirSync(p)) if (f.endsWith('.sql')) add(path.join(p,f));
      // also scan nested models/jobs dirs if present
      ['models','jobs'].forEach(sub => {
        const d = path.join(p, sub);
        if (fs.existsSync(d) && fs.statSync(d).isDirectory()) {
          for (const f of fs.readdirSync(d)) if (f.endsWith('.sql')) add(path.join(d,f));
        }
      });
    }
  }
  // deterministic order: register_datasource first, then models, then jobs, then others
  files.sort((a,b) => {
    const key = (x) => x.includes('register_datasource') ? '0' :
                       x.includes('/models/') ? '1' :
                       x.includes('/jobs/') ? '2' : '3';
    return (key(a)+a).localeCompare(key(b)+b);
  });
  return files;
}

async function execSql(client, sql) {
  const res = await client.callTool({
    name: 'execute_sql',
    arguments: { query: sql }
  });
  return res;
}

async function listModels(client) {
  const res = await client.callTool({ 
    name: 'execute_sql', 
    arguments: { query: 'SHOW MODELS;' } 
  });
  return res;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error('Usage: node tools/mcp/mindsdb_runner.mjs <file_or_dir> [...more]');
    process.exit(2);
  }
  const env = {
    MINDSDB_HOST: process.env.MINDSDB_HOST,
    MINDSDB_PORT: process.env.MINDSDB_PORT || '47335',
    MINDSDB_USER: process.env.MINDSDB_USER,
    MINDSDB_PASSWORD: process.env.MINDSDB_PASSWORD,
  };
  for (const [k,v] of Object.entries({MINDSDB_HOST:0,MINDSDB_USER:0,MINDSDB_PASSWORD:0})) {
    if (!env[k]) { console.error(`Missing required env: ${k}`); process.exit(1); }
  }
  const files = readSqlFiles(args);
  if (files.length === 0) { console.error('No .sql files found'); process.exit(1); }

  await withClient(env, async (client) => {
    // Execute queue
    for (const f of files) {
      const sql = fs.readFileSync(f, 'utf8');
      process.stdout.write(`\n▶ Executing: ${f}\n`);
      try {
        await execSql(client, sql);
        process.stdout.write(`✔ Done: ${f}\n`);
      } catch (e) {
        process.stderr.write(`✖ Failed: ${f}\n${e?.message || e}\n`);
        process.exit(1);
      }
    }

    // Quick sanity: list models
    const models = await listModels(client);
    process.stdout.write(`\nModels visible via MCP:\n${JSON.stringify(models?.content?.[0]?.text ?? {}, null, 2)}\n`);
  });
}

main().catch(e => { console.error(e); process.exit(1); });
