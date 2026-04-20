#!/usr/bin/env node
/**
 * claude-knowledge — Lean MCP server for project knowledge
 *
 * 3 tools: pattern_search, pattern_store, project_context
 * Backend: SQLite + FTS5 (full-text search)
 * Token budget: ~100/session + ~50/message
 */
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import Database from 'better-sqlite3';
import { z } from 'zod';
import { resolve, join } from 'path';
import { existsSync, mkdirSync } from 'fs';

// --- Database Setup ---
const dataDir = resolve(process.env.HOME, '.claude', 'knowledge');
if (!existsSync(dataDir)) mkdirSync(dataDir, { recursive: true });

const dbPath = join(dataDir, 'patterns.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('busy_timeout = 5000');

db.exec(`
  CREATE TABLE IF NOT EXISTS patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    key TEXT NOT NULL,
    problem TEXT,
    solution TEXT NOT NULL,
    context TEXT,
    tags TEXT,
    score REAL DEFAULT 0.0,
    used_count INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    UNIQUE(project, key)
  );

  CREATE VIRTUAL TABLE IF NOT EXISTS patterns_fts USING fts5(
    key, problem, solution, context, tags,
    content=patterns,
    content_rowid=id
  );

  -- Keep FTS in sync
  CREATE TRIGGER IF NOT EXISTS patterns_ai AFTER INSERT ON patterns BEGIN
    INSERT INTO patterns_fts(rowid, key, problem, solution, context, tags)
    VALUES (new.id, new.key, new.problem, new.solution, new.context, new.tags);
  END;

  CREATE TRIGGER IF NOT EXISTS patterns_ad AFTER DELETE ON patterns BEGIN
    INSERT INTO patterns_fts(patterns_fts, rowid, key, problem, solution, context, tags)
    VALUES ('delete', old.id, old.key, old.problem, old.solution, old.context, old.tags);
  END;

  CREATE TRIGGER IF NOT EXISTS patterns_au AFTER UPDATE ON patterns BEGIN
    INSERT INTO patterns_fts(patterns_fts, rowid, key, problem, solution, context, tags)
    VALUES ('delete', old.id, old.key, old.problem, old.solution, old.context, old.tags);
    INSERT INTO patterns_fts(rowid, key, problem, solution, context, tags)
    VALUES (new.id, new.key, new.problem, new.solution, new.context, new.tags);
  END;

  CREATE TABLE IF NOT EXISTS project_context (
    project TEXT PRIMARY KEY,
    summary TEXT NOT NULL,
    tech_stack TEXT,
    conventions TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
  );
`);

// --- Prepared Statements ---
const searchStmt = db.prepare(`
  SELECT p.id, p.project, p.category, p.key, p.problem, p.solution, p.tags, p.score, p.used_count,
         rank
  FROM patterns_fts f
  JOIN patterns p ON p.id = f.rowid
  WHERE patterns_fts MATCH ?
  AND p.project = ?
  ORDER BY rank
  LIMIT ?
`);

const searchAllStmt = db.prepare(`
  SELECT p.id, p.project, p.category, p.key, p.problem, p.solution, p.tags, p.score, p.used_count,
         rank
  FROM patterns_fts f
  JOIN patterns p ON p.id = f.rowid
  WHERE patterns_fts MATCH ?
  ORDER BY rank
  LIMIT ?
`);

const searchByCategoryStmt = db.prepare(`
  SELECT id, project, category, key, problem, solution, tags, score, used_count
  FROM patterns
  WHERE project = ? AND category = ?
  ORDER BY score DESC, used_count DESC
  LIMIT ?
`);

const storeStmt = db.prepare(`
  INSERT INTO patterns (project, category, key, problem, solution, context, tags, score)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(project, key) DO UPDATE SET
    problem = excluded.problem,
    solution = excluded.solution,
    context = excluded.context,
    tags = excluded.tags,
    score = excluded.score,
    updated_at = datetime('now')
`);

const bumpUsedStmt = db.prepare(`
  UPDATE patterns SET used_count = used_count + 1, updated_at = datetime('now') WHERE id = ?
`);

const getContextStmt = db.prepare(`
  SELECT * FROM project_context WHERE project = ?
`);

const setContextStmt = db.prepare(`
  INSERT INTO project_context (project, summary, tech_stack, conventions)
  VALUES (?, ?, ?, ?)
  ON CONFLICT(project) DO UPDATE SET
    summary = excluded.summary,
    tech_stack = excluded.tech_stack,
    conventions = excluded.conventions,
    updated_at = datetime('now')
`);

const statsStmt = db.prepare(`
  SELECT project, COUNT(*) as count,
         SUM(used_count) as total_uses,
         ROUND(AVG(score), 2) as avg_score
  FROM patterns GROUP BY project
`);

const getPatternByIdStmt = db.prepare(`
  SELECT * FROM patterns WHERE id = ?
`);

const deleteStmt = db.prepare(`
  DELETE FROM patterns WHERE project = ? AND key = ?
`);

// --- MCP Server ---
const server = new McpServer({
  name: 'claude-knowledge',
  version: '1.0.0',
});

// Tool 1: Search patterns
server.tool(
  'pattern_search',
  'Returns compact index. Use pattern_get <id> to fetch full solution.',
  {
    query: z.string().describe('Search query (keywords, problem description)'),
    project: z.string().optional().describe('Project name filter (default: search all)'),
    category: z.string().optional().describe('Category filter (e.g. bugfix, feature, refactor, config)'),
    limit: z.number().optional().default(5).describe('Max results'),
  },
  async ({ query, project, category, limit }) => {
    let rows;

    if (category && project) {
      rows = searchByCategoryStmt.all(project, category, limit);
    } else {
      // FTS5 query — strip special chars that FTS5 interprets as operators
      const ftsQuery = query
        .replace(/['"()*:^+\-]/g, ' ')
        .split(/\s+/)
        .filter((w) => w.length > 1 && !['AND', 'OR', 'NOT', 'NEAR'].includes(w.toUpperCase()))
        .join(' OR ');
      if (!ftsQuery) {
        return { content: [{ type: 'text', text: 'No results (empty query)' }] };
      }
      try {
        rows = project
          ? searchStmt.all(ftsQuery, project, limit)
          : searchAllStmt.all(ftsQuery, limit);
      } catch {
        rows = [];
      }
    }

    // Bump used_count for returned results
    for (const row of rows) {
      bumpUsedStmt.run(row.id);
    }

    if (rows.length === 0) {
      return { content: [{ type: 'text', text: `No patterns found for: ${query}` }] };
    }

    const results = rows.map((r) => {
      const problemPreview = r.problem
        ? (r.problem.length > 80 ? r.problem.substring(0, 80) + '…' : r.problem)
        : null;
      return {
        id: r.id,
        key: r.key,
        category: r.category,
        problem: problemPreview,
        tags: r.tags,
        score: r.score,
      };
    });

    return {
      content: [{ type: 'text', text: JSON.stringify(results, null, 2) }],
    };
  }
);

// Tool 1b: Get full pattern details by ID
server.tool(
  'pattern_get',
  'Get full details of a pattern by ID. Use after pattern_search to fetch the solution.',
  {
    id: z.number().describe('Pattern ID from pattern_search results'),
  },
  async ({ id }) => {
    const row = getPatternByIdStmt.get(id);
    if (!row) {
      return { content: [{ type: 'text', text: `No pattern found with id: ${id}` }] };
    }
    return { content: [{ type: 'text', text: JSON.stringify(row, null, 2) }] };
  }
);

// Tool 2: Store a pattern
server.tool(
  'pattern_store',
  'Save a reusable pattern (problem + solution). Use after solving something that might recur.',
  {
    project: z.string().describe('Project name (e.g. grewme, ichigo-crm)'),
    key: z.string().describe('Short unique key (e.g. "rails-encryption-fixtures")'),
    solution: z.string().describe('The solution or approach that worked'),
    problem: z.string().optional().describe('The problem that was solved'),
    context: z.string().optional().describe('Additional context (file paths, versions)'),
    category: z.string().optional().default('general').describe('Category: bugfix, feature, refactor, config, test, performance'),
    tags: z.string().optional().describe('Comma-separated tags'),
    score: z.number().optional().default(0.8).describe('Confidence score 0-1'),
  },
  async ({ project, key, solution, problem, context, category, tags, score }) => {
    storeStmt.run(project, category, key, problem ?? null, solution, context ?? null, tags ?? null, score);
    return {
      content: [{ type: 'text', text: `Stored pattern "${key}" in project "${project}" [${category}]` }],
    };
  }
);

// Tool 3: Get/set project context
server.tool(
  'project_context',
  'Get or set project summary (tech stack, conventions). Helps AI understand the project quickly.',
  {
    project: z.string().describe('Project name'),
    action: z.enum(['get', 'set']).optional().default('get'),
    summary: z.string().optional().describe('Project summary (for set)'),
    tech_stack: z.string().optional().describe('Tech stack (for set)'),
    conventions: z.string().optional().describe('Key conventions (for set)'),
  },
  async ({ project, action, summary, tech_stack, conventions }) => {
    if (action === 'set') {
      if (!summary) return { content: [{ type: 'text', text: 'summary is required for set' }] };
      setContextStmt.run(project, summary, tech_stack ?? null, conventions ?? null);
      return { content: [{ type: 'text', text: `Project context saved for "${project}"` }] };
    }

    const row = getContextStmt.get(project);
    if (!row) {
      // Return stats instead
      const stats = statsStmt.all();
      return {
        content: [{
          type: 'text',
          text: `No context for "${project}". Known projects:\n${JSON.stringify(stats, null, 2)}`,
        }],
      };
    }

    return { content: [{ type: 'text', text: JSON.stringify(row, null, 2) }] };
  }
);

// Tool 4: Delete a pattern
server.tool(
  'pattern_delete',
  'Delete a pattern by key. Use to remove stale or incorrect patterns.',
  {
    project: z.string().describe('Project name'),
    key: z.string().describe('Pattern key to delete'),
  },
  async ({ project, key }) => {
    const result = deleteStmt.run(project, key);
    if (result.changes === 0) {
      return { content: [{ type: 'text', text: `No pattern found: "${key}" in "${project}"` }] };
    }
    return { content: [{ type: 'text', text: `Deleted pattern "${key}" from "${project}"` }] };
  }
);

// Tool 5: List all patterns for a project
server.tool(
  'pattern_list',
  'List all patterns for a project, ordered by most used.',
  {
    project: z.string().describe('Project name'),
    limit: z.number().optional().default(20).describe('Max results'),
  },
  async ({ project, limit }) => {
    const rows = db.prepare(
      'SELECT key, category, score, used_count, updated_at FROM patterns WHERE project = ? ORDER BY used_count DESC, score DESC LIMIT ?'
    ).all(project, limit);
    if (rows.length === 0) {
      return { content: [{ type: 'text', text: `No patterns for project "${project}"` }] };
    }
    return { content: [{ type: 'text', text: JSON.stringify(rows, null, 2) }] };
  }
);

// Tool 6: Pattern statistics across all projects
server.tool(
  'pattern_stats',
  'Show pattern statistics across all projects.',
  {},
  async () => {
    const stats = statsStmt.all();
    const total = db.prepare('SELECT COUNT(*) as count FROM patterns').get();
    return {
      content: [{ type: 'text', text: JSON.stringify({ totalPatterns: total.count, byProject: stats }, null, 2) }],
    };
  }
);

// --- Start ---
const transport = new StdioServerTransport();
await server.connect(transport);
