# plugin/scripts/

## Responsibility
`plugin/scripts/` implements lean-flow's session hooks and automation:
- **Hook enforcement**: PreToolUse/PostToolUse blocking (secrets, protected branches, identity markers, wrong directories)
- **Memory consolidation**: auto-dream triggers memory cleanup on idle sessions
- **Repository cartography**: codemap generation and change detection
- **Session monitoring**: activity capture and usage tracking (SwiftBar + launchd on macOS)
- **Output compression**: large command output summarization via Claude Haiku
- **TDD enforcement**: test-first workflow reminders on implementation writes

## Design
- **Declarative gate patterns**: `block-*.sh` check single conditions (git flags, paths, secrets) independently — composable, testable
- **Dual gates**: auto-dream uses session count + time elapsed (prevents thrashing, respects user pace)
- **Resource budgets**: token limits (5000 max memory), timeouts (5min dream consolidation, 600s lock grace period), file truncation (100 lines max per file, 15 files per dir)
- **Fallback chains**: auto-compress-output uses Claude Haiku, falls back to truncation if unavailable; OAuth token tries macOS keychain, falls back to ANTHROPIC_API_KEY env
- **Idempotent sessions**: ensure-cartography, ensure-claude-monitor check existing state before installing (safe for repeated SessionStart)
- **Zero-token hooks**: auto-observe silently logs to patterns.db, no API call; file blocking exits immediately

## Flow
1. **PreToolUse hooks** (block-*.sh, auto-compress-output.sh): intercept Bash/Write/Edit commands → check conditions → allow/block/summarize → return early
2. **PostToolUse hooks** (auto-update-codemaps.sh, enforce-tdd.sh): detect commit/file write → parse changed dirs/files → trigger async updates or emit reminders
3. **Session start** (ensure-cartography.sh, ensure-claude-monitor.sh): check repo state → report stale codemaps or missing monitors → suggest manual runs
4. **Session stop** (auto-dream.sh): increment counter → check time + count gates → if passed, spawn background Claude process with auto-dream-prompt.md, clean up state
5. **Background consolidation** (cartographer.py): init hashes + empty codemaps, or detect changed dirs → read file contents → call Claude API for codemap text → write to codemap.md per folder

## Integration
- **Config**: all scripts source `load-config.sh` for LEAN_FLOW_* variables (dream sessions/hours, protected branches, monitor toggle)
- **State**: dream state in `~/.claude/dream-state/` (session count, last timestamp, lock file); cartography state in `.slim/cartography.json`
- **API**: auto-compress-output, auto-update-codemaps, auto-dream call Claude via `claude` CLI (Haiku for compression, Opus for codemap generation, Haiku for consolidation)
- **Git**: cartographer, ensure-cartography read git log/diff-tree; block-*.sh parse git commands from jq stdin
- **macOS only**: ensure-claude-monitor installs SwiftBar plugin + launchd agent for usage monitoring (claude-monitor/ subdirectory)
- **Async spawning**: auto-dream and auto-update-codemaps background processes to avoid blocking tool responses
