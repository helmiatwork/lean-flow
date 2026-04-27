# plugin/scripts/

## Responsibility

Host automation scripts that enforce coding standards, optimize token usage, and maintain repository documentation. Scripts run as git hooks (PreToolUse, PostToolUse) and session lifecycle events (SessionStart, Stop) to intercept commands, compress output, block unsafe operations, and auto-update codemaps.

## Design

**Hook-based execution model**: Scripts are sourced/executed by the Claude CLI hook system (PreToolUse intercepts before tool execution, PostToolUse after). Most are bash wrappers that parse JSON input via `jq`, make decisions, and return structured JSON decisions (`{"decision":"block"}` or system messages).

**Multi-layer blocking**: Separate scripts for each policy (block-protected-push.sh, block-secret-commits.sh, block-no-verify.sh, block-claude-identity.sh) rather than one monolith — each fails fast with clear error messages.

**Token optimization**: auto-compress-output.sh runs high-output commands (git log, test suites) directly, truncates to 25 lines, then summarizes via haiku-4-5 if needed. Cartographer.py hashes directory contents to detect changes; ensure-cartography.sh triggers Tier 1 (CODEBASE_MAP.md) and Tier 2 (per-folder codemap.md) updates.

**Background consolidation**: auto-dream.sh consolidates memory (patterns.db, MEMORY.md) on session stop after dual gates (N sessions + N hours) to avoid thrashing. Runs in timeout-protected background process.

## Flow

1. **PreToolUse hooks** (auto-compress-output, block-*.sh): Inspect incoming command, decide block/allow/summarize before Claude runs tool
2. **PostToolUse hooks** (auto-update-codemaps, enforce-tdd): After tool executes, update docs or remind about test coverage
3. **SessionStart** (ensure-cartography, ensure-claude-monitor): Check repo state, emit system messages if docs stale or tooling missing
4. **SessionStop** (auto-dream): Consolidate session patterns into knowledge DB if gates pass
5. **Cartographer polling**: auto-update-codemaps.py reads git diff-tree, identifies changed dirs, calls Claude API to fill codemap.md sections

## Integration

- **Git hooks**: PostToolUse auto-update-codemaps.sh wraps Python script to update .md files after commits
- **Knowledge DB** (~/.claude/knowledge/patterns.db): auto-observe.sh logs session activity; auto-dream.sh prunes stale patterns
- **Config**: load-config.sh (sourced by auto-dream.sh, block-protected-push.sh) sets LEAN_FLOW_* environment vars
- **Claude monitor** (macOS): ensure-claude-monitor.sh installs SwiftBar plugin and launchd agent from claude-monitor/ subdir
- **System messaging**: All scripts emit JSON system messages to SessionStart to alert user (e.g., "Tier 1: 5 commits since mapping")
