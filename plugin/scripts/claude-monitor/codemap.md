# plugin/scripts/claude-monitor/

## Responsibility

Provides real-time monitoring of Claude Code sessions and API token usage via SwiftBar menu bar widget. Tracks session state (thinking/running/idle/stopped), tool invocations (Bash, file I/O, web search, subagents), and fetches usage metrics from Anthropic's OAuth endpoint with fallback caching.

## Design

- **Event-driven tracking**: `claude-session-track.sh` intercepts four event types (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`) via stdin, extracts structured data with `jq`, and writes JSON state + append-only logs per session.
- **Tool-specific summaries**: Normalizes heterogeneous tool inputs (e.g., Bash command, file path, search query) into 60–120 char summaries for compact display.
- **Resilient API fetch**: `claude-usage.3m.sh` fetches live from `api.anthropic.com/api/oauth/usage`, persists successful responses to `~/.cache/claude-usage-last-good.json`, and degrades gracefully to stale cache on rate-limit or network error (shows `⚠️` status).
- **SwiftBar integration**: 3-minute polling interval; displays color-coded usage bars (🟢/🟡/🔴 at 50%/80% thresholds) with reset times extracted from ISO timestamps.

## Flow

1. **Session tracking** (asynchronous): Claude Code emits events → `claude-session-track.sh` parses JSON, updates `/tmp/claude-sessions/{session_id}.json` state file and appends to `.log`; automatic cleanup of stopped sessions older than 10 minutes.
2. **Session viewing** (on-demand): User clicks session in menu → `claude-session-view.sh` renders formatted terminal output (status, current tool, last 60 activity log entries with colors and icons).
3. **Usage polling** (periodic): SwiftBar calls `claude-usage.3m.sh` every 3 minutes → fetches `api.anthropic.com` with stored OAuth token (from keychain), caches result, extracts five-hour/seven-day utilization percentages and reset times, renders compact menu bar display.
4. **Token accounting** (local): `local-tokens.py` scans `~/.claude/projects/*.jsonl` conversation logs, aggregates input/output/cache tokens by model for a "today" or "7d" window, outputs JSON with per-model percentages.

## Integration

- **Claude Code CLI**: Relies on `/opt/homebrew/bin` and `PATH` for `jq`; token fetching depends on `security find-generic-password` keychain lookup of 'Claude Code-credentials'.
- **SwiftBar plugin system**: Symlinks `claude-usage.3m.sh` to `~/Library/Application Support/SwiftBar/Plugins/`; refresh interval indicated by filename suffix (`.3m.sh`); outputs menu bar text with pipe delimiters for submenu.
- **LaunchAgent** (`install.command`): Creates `com.ameba.SwiftBar.plist` to ensure SwiftBar auto-starts; hardens against macOS 26.x state-restore crash by disabling `NSQuitAlwaysKeepsWindows` and removing saved state directory.
- **Keychain**: Stores Anthropic OAuth token under generic password service 'Claude Code
