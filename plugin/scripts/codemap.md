# plugin/scripts/

## Responsibility

`plugin/scripts/` contains the lean-flow hook ecosystem — PreToolUse/PostToolUse interceptors, session lifecycle handlers, and repository cartography tools. These scripts enforce project constraints (no direct pushes to protected branches, no secret commits, TDD reminders), optimize Claude's interaction cost (compress large command output via haiku), and maintain codebase documentation (auto-update codemaps after commits, track repository changes).

## Design

- **Hook pattern**: Shell scripts read JSON from stdin, emit structured JSON or exit codes (0=pass, 2=block/transform) to control tool execution
- **Dual-gating**: `auto-dream.sh` uses session count + elapsed time gates to trigger expensive memory consolidation only when justified
- **Compression strategy**: `auto-compress-output.sh` executes high-output commands directly (git log, pytest, grep -r), truncates to 25 lines before calling Claude haiku for summarization
- **State machines**: `cartographer.py` tracks directory hashes in `.slim/cartography.json`, enables efficient diff detection; `ensure-cartography.sh` runs per-session to detect unmapped changes across two tiers (CODEBASE_MAP.md, per-folder codemaps)
- **Keychain + env fallback**: `auto-update-codemaps.py` retrieves ANTHROPIC_API_KEY from macOS security store, falls back to environment variable

## Flow

1. **Tool execution gates**: PreToolUse hooks (`block-*.sh`) intercept git/gh commands, validate refs, block secrets/identity markers, exit 2 to deny
2. **Output optimization**: `auto-compress-output.sh` (PreToolUse) runs high-output commands directly, summarizes via haiku if >25 lines, returns compressed summary
3. **Post-commit automation**: After git commit, `auto-update-codemaps.sh` → `auto-update-codemaps.py` gets changed dirs, reads file contents, calls Claude API to populate/refresh codemap.md sections per directory
4. **Session boundary tasks**: `SessionStart` runs `ensure-cartography.sh` + `ensure-claude-monitor.sh` (idempotent checks); `SessionStop` runs `auto-dream.sh` (consolidates memory if gates pass) and `auto-observe.sh` (silent pattern.db writes from session logs)
5. **Development nudges**: `enforce-tdd.sh` (PostToolUse Write/Edit) detects implementation files without tests, injects TDD phase reminder; `block-claude-identity.sh` scrubs Co-Authored-By markers from commits

## Integration

- **Entrypoint**: `/claude-monitor/` subdirectory holds SwiftBar plugin + launchd plist for background usage monitoring on macOS
- **Config**: Loads `LEAN_FLOW_*` env vars via `load-config.sh` (protected branches, dream gates, monitor enable flag)
- **APIs**: Calls `claude` CLI (haiku model) for output summarization, `ANTHROPIC_API_KEY` for CodeMap updates, `git` for changed dirs/state, `sqlite3` for patterns.db observation writes
- **State dirs**: `~/.claude/dream-state/` (consolidation lockfile + session count), `~/.claude/knowledge/patterns.db` (observations), `.slim/cartography.json` (per-repo dir hashes)
- **Prompt templates**: `auto-dream
