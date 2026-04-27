# plugin/scripts/claude-monitor/

## Responsibility
Session monitoring and token usage tracking for Claude Code in the menu bar. Provides real-time visibility into session state (thinking/running/idle), tool execution history, and API quota consumption via SwiftBar integration.

## Design
- **Event-driven tracking** (`claude-session-track.sh`): Hooks into Claude Code lifecycle events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) and writes JSON state + append-only logs per session to `/tmp/claude-sessions/`
- **Dual data sources**: Live API fetch (`claude-usage.3m.sh`) with fallback to last-good cache for resilience; local token accounting (`local-tokens.py`) from `~/.claude/projects/` JSONL logs
- **SwiftBar plugin pattern**: 3-minute polling interval with instant state reads from local JSON files; no blocking I/O
- **Cleanup strategy**: Auto-purge stopped sessions older than 10 minutes; cache age shown to user on API fallback

## Flow
1. **Session tracking**: Claude Code hooks emit JSON via stdin → `claude-session-track.sh` parses event type and tool details → writes `{session_id}.json` state file + appends to `{session_id}.log` history
2. **Usage display**: `claude-usage.3m.sh` (SwiftBar) fetches `/api/oauth/usage` → on success, caches result + persists to disk; on failure, reads last-good cache and displays ⚠️ indicator
3. **Local accounting**: `local-tokens.py` scans project JSONL files by creation timestamp, aggregates per-model input/output/cache tokens for "today" or "7d" windows
4. **Session viewer**: `claude-session-view.sh` reads state + log files, renders live status with colored emoji + scrollable event history (last 60 events)

## Integration
- **Claude Code hooks**: Consumes structured JSON events from Claude Code stdio (session_id, tool_name, prompt, cwd)
- **SwiftBar**: Plugins read from `~/Library/Application Support/SwiftBar/Plugins/` (symlink), render menu bar text; refresh triggered by click actions
- **Keychain**: `claude-usage.3m.sh` retrieves OAuth token via `security find-generic-password` for API auth
- **LaunchAgent**: `install.command` creates plist to auto-run fetcher every 3 minutes and pin SwiftBar startup
- **File system**: All state in `/tmp/claude-sessions/` (volatile), API cache in `~/.cache/claude-usage-last-good.json`, project logs in `~/.claude/projects/**/*.jsonl`
