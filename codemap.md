# lean-flow/ — Repository Atlas

## Responsibility

Lightweight Claude Code workflow plugin. Provides pattern memory, agent orchestration, session hooks, and development workflow templates at ~1/60th the token cost of heavier frameworks (6 MCP tools vs 300+).

## System Entry Points

- `hooks/hooks.json` — registered with Claude Code settings; fires on SessionStart/Pre/Post hooks
- `mcp-servers/knowledge/index.mjs` — MCP server binary for pattern memory
- `scripts/*.sh` — install-time setup scripts invoked by `install.command`

## Directory Map

| Directory | Purpose | Codemap |
|-----------|---------|---------|
| agents/ | Agent persona definitions (oracle, coder, fixer, etc.) | [codemap.md](agents/codemap.md) |
| hooks/ | Claude Code lifecycle hooks (session start, safety guards) | [codemap.md](hooks/codemap.md) |
| mcp-servers/ | MCP server implementations | [codemap.md](mcp-servers/codemap.md) |
| mcp-servers/knowledge/ | SQLite + FTS5 pattern memory server | [codemap.md](mcp-servers/knowledge/codemap.md) |
| scripts/ | Setup, installation, and utility scripts | [codemap.md](scripts/codemap.md) |
| scripts/claude-monitor/ | SwiftBar plugin for Claude usage monitoring | [codemap.md](scripts/claude-monitor/codemap.md) |
| skills/ | Reusable prompt skill files | [codemap.md](skills/codemap.md) |
| templates/ | PR templates and commit/cartography conventions | [codemap.md](templates/codemap.md) |
| workflows/ | Development workflow documentation (mermaid diagrams) | [codemap.md](workflows/codemap.md) |
