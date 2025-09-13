-- Claude Desktop Memory Schema
-- This file creates the SQLite database schema for persistent memory storage

CREATE TABLE IF NOT EXISTS memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  tag TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_memory_tag ON memory(tag);
CREATE INDEX IF NOT EXISTS idx_memory_session ON memory(session_id);
CREATE INDEX IF NOT EXISTS idx_memory_created ON memory(created_at);
CREATE INDEX IF NOT EXISTS idx_memory_tag_created ON memory(tag, created_at);

-- Create a trigger to update the updated_at timestamp
CREATE TRIGGER IF NOT EXISTS update_memory_timestamp 
  AFTER UPDATE ON memory
  FOR EACH ROW
BEGIN
  UPDATE memory SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Create a view for recent memories
CREATE VIEW IF NOT EXISTS recent_memories AS
SELECT 
  id,
  session_id,
  tag,
  content,
  created_at,
  updated_at
FROM memory
ORDER BY created_at DESC
LIMIT 50;

-- Create a view for memory statistics
CREATE VIEW IF NOT EXISTS memory_stats AS
SELECT 
  tag,
  COUNT(*) as count,
  MIN(created_at) as first_entry,
  MAX(created_at) as last_entry,
  AVG(LENGTH(content)) as avg_content_length
FROM memory
GROUP BY tag
ORDER BY count DESC;

-- Insert initial metadata
INSERT OR IGNORE INTO memory (session_id, tag, content) 
VALUES ('init', 'system', 'Claude Desktop Memory System initialized');

-- Useful queries for memory management:
-- 
-- Get all memories for a specific tag:
-- SELECT * FROM memory WHERE tag = 'scout-project' ORDER BY created_at DESC;
--
-- Get memory statistics:
-- SELECT * FROM memory_stats;
--
-- Clean up old memories (older than 30 days):
-- DELETE FROM memory WHERE created_at < datetime('now', '-30 days');
--
-- Get unique tags:
-- SELECT DISTINCT tag FROM memory ORDER BY tag;
--
-- Search memory content:
-- SELECT * FROM memory WHERE content LIKE '%search_term%' ORDER BY created_at DESC;