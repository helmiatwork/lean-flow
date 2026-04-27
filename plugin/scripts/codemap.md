# plugin/scripts/

## Responsibility
Plugin scripts that enforce workflows, optimize token usage, and maintain codebase documentation. These hooks intercept Claude operations at PreToolUse and PostToolUse boundaries to block unsafe actions, compress large outputs, auto-update codemaps, and consolidate memory patterns.

## Design
**Hook-based architecture**: Scripts are invoked as `PreToolUse` and `PostToolUse` hooks, receiving JSON stdin and returning JSON decisions (block/allow/ask) to gate tool execution. Dual-gate patterns (e.g., `auto-dream.sh`: 24h elapsed AND N sessions) prevent runaway automation. Bash scripts handle fast path decisions; Python handles heavy lifting (Claude API calls, git analysis, database updates). Config-driven via `load-config.sh` (LEAN_FLOW_* environment variables).

**Token optimization**: `auto-compress-output.sh` intercepts high-output commands (git log, tests, grep -r), runs them locally, and summarizes via haiku if >25 lines. `auto-observe.sh` silently logs session patterns to `~/.claude/knowledge/patterns.db` without API cost. `auto-dream.sh` periodically consolidates memory via background haiku call.

**Cartography system**: Three-tier approach — `cartographer.py` (glob-based file selector + hash diffing), `ensure-cartography.sh` (SessionStart check), `auto-update-codemaps.py` (PostToolUse after git commit). Uses `.slim/cartography.json` state to track changed directories and auto-populate `codemap.md` sections.

## Flow
1. **PreToolUse hooks** (block-*.sh, auto-compress-output.sh): Receive command JSON, apply decision logic (regex match protected branches, secret files), return `{"decision":"block"}` or compress output and exit code 2.
2. **PostToolUse hooks** (auto-update-codemaps.py, enforce-tdd.sh): Triggered after Write/Edit/Bash, detect changed files/directories, orchestrate Claude API calls for codemap generation or inject TDD reminders.
3. **SessionStart** (ensure-cartography.sh, ensure-claude-monitor.sh): Check cartography state, emit system messages if tiers need refresh; detect and install monitor infrastructure.
4. **SessionStop** (auto-dream.sh): Dual-gate triggers (elapsed time + session count), spawn background haiku consolidation of memory files + pattern database cleanup.
5. **Background**: `auto-observe.sh` parses session logs to `patterns.db`; `cartographer.py` runs as `changes` or `update` commands to maintain file hashes and codemap state.

## Integration
- **Git hooks**: Invoked after commit; reads `git diff-tree` and `git log` to detect changed directories and commit history.
- **Memory system**: Writes to `~/.claude/projects/*/memory/MEMORY.md` and `~/.claude/knowledge/patterns.db` for consolidation and pattern reuse.
- **SwiftBar monitor** (claude-monitor/): Installed and managed by `ensure-claude-monitor.sh`; `auto-observe.sh` feeds session logs to launchd fetcher.
- **Claude API**: `auto-update-codemaps.py` calls Claude with OAuth token from macOS keychain; `auto-dream.sh` uses haiku model for memory consolidation.
- **Cartography state**: `.slim/cartography
