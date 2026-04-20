# plugin/scripts/

## Responsibility
Script hooks and background tasks for lean-flow automation. Enforces coding standards (TDD, git hygiene, secrets), optimizes API usage via output compression, maintains repository cartography (codemaps), and consolidates session memory via Claude's haiku model.

## Design
**Hook-based architecture**: Each script is a self-contained PreToolUse/PostToolUse/SessionStart hook that reads JSON input, makes a decision, and optionally blocks/compresses/transforms output without requiring user interaction. **Token optimization**: `auto-compress-output.sh` intercepts high-volume commands (git log, test runs) and summarizes them via haiku before Claude sees them. **Dual-gate memory consolidation**: `auto-dream.sh` triggers only after N sessions AND M hours, preventing thrashing. **Cartography tiers**: `ensure-cartography.sh` checks both high-level `docs/CODEBASE_MAP.md` (git log–based) and per-folder `codemap.md` files (cartographer-tracked).

## Flow
1. **Execution**: Hook fires → reads JSON input (tool, command, file path) → applies skip/block/transform logic → outputs decision or modified context
2. **Compression**: High-output commands → run directly → count lines → if >25 lines, call haiku summarizer → return compressed result with exit code 2 (block original)
3. **Memory dream**: Session counter increments; when both gates pass (sessions ≥ N AND hours ≥ M) → background process locks state → runs `auto-dream-prompt.md` with claude-haiku → prunes memory files → resets counters
4. **Cartography**: SessionStart checks `.slim/cartography.json` → runs `cartographer.py changes` → reports affected folders

## Integration
- **Git hooks** (via PreToolUse/PostToolUse): Block pushes to `LEAN_FLOW_PROTECTED_BRANCHES`, secrets, identity markers; auto-update codemaps after commits
- **Config loading**: Scripts source `load-config.sh` (not shown) for `LEAN_FLOW_*` env vars (dream gates, protected branches, monitor flag)
- **OAuth/API**: `auto-update-codemaps.py` pulls token from macOS keychain or `ANTHROPIC_API_KEY`; `ensure-claude-monitor.sh` sets up SwiftBar + launchd for usage tracking
- **Session logging**: `auto-observe.sh` reads `/tmp/claude-sessions/{SESSION_ID}.log` → writes pattern observations to `~/.claude/knowledge/patterns.db`
- **claude-monitor/**: Subdirectory contains SwiftBar plugin + fetcher (fetches usage, stores in cache, displayed in menu bar)
