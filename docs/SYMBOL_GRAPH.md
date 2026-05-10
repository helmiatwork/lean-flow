# Symbol Graph

Tool: **GitNexus** (MCP server, auto-installed via lean-flow's `ensure-gitnexus.sh` SessionStart hook).

## Refresh

```bash
npx gitnexus analyze
```

Index location: `.gitnexus/` (gitignored).

## Query patterns

Use the `mcp__gitnexus__*` tools:
- `mcp__gitnexus__query` — Cypher-like query over the indexed graph.
- `mcp__gitnexus__impact` — what breaks if X changes.
- `mcp__gitnexus__route_map` — HTTP route → handler mapping.

## When to refresh

- After significant refactors (function renames, file moves).
- Before impact-analysis questions ("is it safe to change X?").
- Stale-index warnings appear in PostToolUse hook output.
