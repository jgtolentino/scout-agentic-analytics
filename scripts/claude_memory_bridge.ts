import Database from 'better-sqlite3';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';

const memoryDir = join(process.env.HOME!, '.claude', 'memory');
if (!existsSync(memoryDir)) {
  mkdirSync(memoryDir, { recursive: true });
}

const db = new Database(join(memoryDir, 'context.db'));

// Ensure table exists
db.exec(`
CREATE TABLE IF NOT EXISTS memory (
  id INTEGER PRIMARY KEY,
  session_id TEXT,
  tag TEXT,
  content TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
`);

export function storeMemory(sessionId: string, tag: string, content: string) {
  const stmt = db.prepare("INSERT INTO memory (session_id, tag, content) VALUES (?, ?, ?)");
  stmt.run(sessionId, tag, content);
}

export function recallMemory(tag: string, limit = 5): string[] {
  const stmt = db.prepare("SELECT content FROM memory WHERE tag = ? ORDER BY created_at DESC LIMIT ?");
  return stmt.all(tag, limit).map((row: any) => row.content);
}

export function getMemoryTags(): string[] {
  const stmt = db.prepare("SELECT DISTINCT tag FROM memory ORDER BY tag");
  return stmt.all().map((row: any) => row.tag);
}

export function clearMemory(tag?: string) {
  if (tag) {
    const stmt = db.prepare("DELETE FROM memory WHERE tag = ?");
    stmt.run(tag);
  } else {
    db.exec("DELETE FROM memory");
  }
}

export function getMemoryStats() {
  const totalStmt = db.prepare("SELECT COUNT(*) as count FROM memory");
  const tagsStmt = db.prepare("SELECT tag, COUNT(*) as count FROM memory GROUP BY tag");
  
  return {
    total: totalStmt.get().count,
    byTag: tagsStmt.all()
  };
}

// Auto-store current project context
export function storeProjectContext(projectName: string, context: any) {
  const contextStr = typeof context === 'string' ? context : JSON.stringify(context);
  const sessionId = new Date().toISOString().split('T')[0];
  storeMemory(sessionId, `project-${projectName}`, contextStr);
}

// Auto-recall project context
export function recallProjectContext(projectName: string, limit = 3): string[] {
  return recallMemory(`project-${projectName}`, limit);
}