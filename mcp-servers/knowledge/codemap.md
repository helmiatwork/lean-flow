# mcp-servers/knowledge/

## Responsibility

MCP server for cross-project pattern memory. Stores solved problem/solution pairs in SQLite with FTS5 full-text search, enabling agents to retrieve previously solved patterns before re-reasoning.

## Design

Three tools: `pattern_search` (FTS query over problem/solution/tags), `pattern_store` (upsert a pattern with project/category/key), `project_context` (get/set a free-form project summary string). Database at `~/.claude/knowledge/patterns.db` uses WAL mode. FTS index is kept in sync via triggers.

## Flow

Orchestrator calls `pattern_search` early in planning. If a match is found, it informs the approach without re-solving. After successful work, orchestrator calls `pattern_store` to persist the solution. `project_context` provides a short project summary injected into session context.

## Integration

Registered as `claude-knowledge` in `~/.claude/settings.json`. Depends on `better-sqlite3` and `@modelcontextprotocol/sdk`. Database is shared across all projects — `project` field scopes patterns. `ensure-knowledge-mcp.sh` handles npm install and settings registration.
