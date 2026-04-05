# mcp-servers/

## Responsibility

Houses MCP (Model Context Protocol) server implementations bundled with lean-flow. Currently contains only the `knowledge/` server; designed to host additional lightweight servers without registering hundreds of tools.

## Design

Each subdirectory is a self-contained Node.js MCP server with its own `package.json`. Servers expose a minimal tool surface (knowledge exposes 3 tools) to keep per-session token overhead low. Uses stdio transport for local execution.

## Flow

Servers are registered in `~/.claude/settings.json` under `mcpServers`. Claude Code spawns each server as a subprocess on session start and communicates over stdio using the MCP protocol.

## Integration

`ensure-knowledge-mcp.sh` (in scripts/) handles registration and dependency installation. Servers write persistent state to `~/.claude/` (e.g., `~/.claude/knowledge/patterns.db`). Consumed by orchestrator via MCP tool calls during planning and after task completion.
