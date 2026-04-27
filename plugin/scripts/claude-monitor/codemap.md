# plugin/scripts/claude-monitor/

## Responsibility
Provides real-time monitoring of Claude Code token usage and session activity via SwiftBar menu bar integration. Tracks API usage quotas with color-coded status, displays live Claude session state (thinking/running/idle), and logs tool invocations and subagent spawns.

## Design
**Two-layer architecture:**
- **Usage monitor** (`claude-usage.30s.sh`): direct OAuth API polling (no daemon), reads token from macOS keychain, renders SwiftBar dropdown with 5h/7d/model-specific usage percentages and reset times
- **Session tracker** (`claude-session-track.sh`): event-driven hook system capturing `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Stop` events; maintains per-session JSON state file + append-only JSONL history log in `/tmp/claude-sessions/`; auto-cleans stopped sessions after 10 minutes
- **Session viewer** (`claude-session-view.sh`): terminal UI rendering current state + last 60 events with timestamps, color-coded status icons, and tool-specific summaries
- **Local token accounting** (`local-tokens.py`): parses `~/.claude/projects/**/*.jsonl` to compute model usage by window (today/7d) with cache metrics

## Flow
1. **Usage**: `claude-usage.30s.sh` runs every 30s via SwiftBar, fetches `/api/oauth/usage` with Bearer token, formats percentages + reset times, outputs menu bar icon (🟢/🟡/🔴 based on max usage), dropdown with model breakdown
2. **Sessions**: Claude Code CLI invokes `claude-session-track.sh` hooks at event boundaries; each event writes/appends to `$SESSION_DIR/${session_id}.json` (state) + `.log` (history); `claude-session-view.sh` polls the state file and renders live display with 60-event tail from log
3. **Tokens**: `local-tokens.py` scans all project JSONL files, filters by timestamp window, aggregates input/output/cache tokens per model, outputs JSON sorted by output volume with percentages

## Integration
- **Keying on `session_id`** from Claude Code event JSON allows tracking parent + subagent sessions independently
- **State + log separation**: `.json` file is R/W for current status (status/tool/summary/ts); `.log` is append-only for audit trail
- **Tool-specific extraction**: `PreToolUse` parses `tool_name` + `tool_input` (command/path/query/description/pattern) to build readable summaries
- **macOS keychain integration** (`security find-generic-password`) supplies OAuth token without CLI login prompt
- **Installer (`install.command`)** creates symlinks to plugins in SwiftBar directory, hardens against state-restore crashes, manages LaunchAgent lifecycle
