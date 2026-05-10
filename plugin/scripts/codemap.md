# plugin/scripts/

## Responsibility

`plugin/scripts/` contains **automation hooks and utilities** that intercept Claude's tool calls, session lifecycle events, and git operations to enforce workflow rules, optimize token usage, consolidate memory, and maintain repository metadata. Scripts run as PreToolUse/PostToolUse/SessionStart/SessionStop hooks and are gated by configuration flags (`LEAN_FLOW_*` env vars).

## Design

- **Hook-based interception**: Bash/Python scripts read JSON stdin from Claude Code's hook system, inspect tool commands or session events, make decisions (block/allow/augment), emit JSON hook responses
- **Zero-cost passthrough**: Small-output operations and non-matching conditions exit immediately (exit 0) without API calls; only expensive operations (haiku compression, memory consolidation) run conditionally
- **Dual-gated triggers**: `auto-dream.sh` requires both N sessions AND M hours elapsed; memory consolidation only runs when both thresholds crossed
- **Stateful caching**: Dream state (`.claude/dream-state/`), cartography hashes (`.slim/cartography.json`), dependency check hashes avoid redundant work across sessions
- **Pattern database**: `auto-observe.sh` logs session activity to `~/.claude/knowledge/patterns.db` (SQLite) for machine-readable pattern extraction and reuse

## Flow

1. **PreToolUse hooks** (`block-*.sh`, `enforce-branch-naming.sh`): intercept Bash/git commands before execution, reject disallowed patterns (protected branch pushes, secrets, identity markers), enforce naming conventions
2. **Tool execution** (`auto-compress-output.sh`): runs high-output commands (git log, test suites) directly, compresses via haiku if >25 lines, returns summary to Claude
3. **PostToolUse hooks** (`delegate-task-retry.sh`): detect Task delegation errors, emit inline retry hints for next turn
4. **SessionStop triggers** (`auto-dream.sh`, `auto-observe.sh`): consolidate memory (Phase 1: dedupe/prune `MEMORY.md`, Phase 2: prune patterns.db), extract session patterns to knowledge DB
5. **Auto-update codemaps** (`auto-update-codemaps.{sh,py}`): on git commit (PostToolUse), detect changed directories via `git diff-tree`, call Claude API to generate/update `codemap.md` sections
6. **Cartography**: `cartographer.py` maintains directory hashes (`.slim/cartography.json`) and detects structural changes for change-detection and codemaps trigger

## Integration

- **Configuration**: reads `LEAN_FLOW_*` vars from `load-config.sh` (protected branches, dream gates, etc.)
- **OAuth tokens**: `auto-update-codemaps.py` fetches API key from macOS keychain or `ANTHROPIC_API_KEY` env var
- **Knowledge MCP**: `auto-observe.sh` writes session observations to `~/.claude/knowledge/patterns.db` (SQLite backend for pattern_search/pattern_store)
- **Git hooks**: scripts inspect git state (repo root, branch, diff-tree) to detect commits, changed files, protected branch targets
- **Session logs**: `auto-observe.sh` reads `/tmp/claude-sessions/${SESSION_ID}.log` to extract tool counts, key commands, durations
- **Subdirectories**: `claude-monitor/` and `project-doctor
