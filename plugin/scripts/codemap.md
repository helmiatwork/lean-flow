# plugin/scripts/

## Responsibility

`plugin/scripts/` provides hook scripts and automation tools that enforce development workflows, maintain codebase documentation, and optimize Claude's memory and output for token efficiency. It includes git hooks (TDD enforcement, secret blocking, protected branch guards), cartography tools for mapping repositories, and background agents for memory consolidation and usage monitoring.

## Design

**Hook-based architecture**: Scripts are invoked by `PreToolUse`, `PostToolUse`, and `SessionStart` events, each returning JSON decisions (block, allow, or ask). Example: `block-protected-push.sh` reads `LEAN_FLOW_PROTECTED_BRANCHES` config and exits with code 2 to block.

**Config inheritance**: Scripts source `load-config.sh` (not shown but referenced) to read dual-gated settings like `LEAN_FLOW_DREAM_SESSIONS` and `LEAN_FLOW_DREAM_HOURS`, enabling tunable policies.

**State files**: `auto-dream.sh` and `auto-observe.sh` manage state in `~/.claude/dream-state/` and `/tmp/claude-sessions/` (session logs), using lock files to prevent concurrent execution.

**Cartographer pattern matching**: `cartographer.py` pre-compiles glob patterns to regex for efficient path selection across large repos; stores file hashes in `.slim/cartography.json` to detect changes.

## Flow

1. **Pre-execution hooks** (`block-*.sh`): Inspect command via jq, reject violations (e.g., `--no-verify`, identity markers, secrets), or ask user.
2. **Tool execution** (`auto-compress-output.sh`): Intercepts high-output commands (git log, pytest, grep), runs them directly, summarizes via Haiku if >25 lines, returns compressed result (exit code 2).
3. **Post-execution** (`auto-update-codemaps.py`): On commit, detects changed directories via `git diff-tree`, reads file contents, calls Claude API to generate codemap sections.
4. **Session lifecycle** (`ensure-cartography.sh`, `ensure-claude-monitor.sh`): On `SessionStart`, check Tier 1 (CODEBASE_MAP.md) and Tier 2 (per-folder codemaps) staleness; install monitor (SwiftBar + launchd) if missing.
5. **Background consolidation** (`auto-dream.sh`): After N sessions OR N hours, triggers memory cleanup (duplicate pruning, pattern decay) via `auto-dream-prompt.md` with timeout guard.
6. **Silent observation** (`auto-observe.sh`): On `SessionStop`, extracts tool usage patterns from session logs, writes to `~/.claude/knowledge/patterns.db` (zero tokens, no API call).

## Integration

- **Hooks input**: JSON from Claude runtime (tool_input, tool_response, command, file_path, session_id).
- **Config source**: `LEAN_FLOW_*` env vars and `~/.claude/config` (via `load-config.sh`).
- **Outputs**: JSON to stdout for decisions; shell exit codes (0=allow, 1=error, 2=block).
- **External calls**: `git` (status, log, diff-tree, commit), `jq` (JSON parsing), `claude` CLI (Haiku summaries), `python3` (cartographer, codemap gen), SwiftBar (macOS monitor).
