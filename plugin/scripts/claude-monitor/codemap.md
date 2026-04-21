# plugin/scripts/claude-monitor/

## Responsibility

Session and usage tracking for Claude Code via SwiftBar menu bar widget. Monitors active Claude sessions (including subagents), logs tool execution, and periodically fetches token usage metrics from the Claude Code CLI to display usage percentages and reset times.

## Design

- **Event-driven logging**: `claude-session-track.sh` hooks into Claude events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) via stdin JSON, writes atomic state files and append-only logs per session in `/tmp/claude-sessions/`
- **Cached display model**: `claude-usage-fetch.sh` runs a headless Claude CLI session, scrapes `/usage` output via ANSI-aware parsing, and writes to `/tmp/claude-usage-cache.json`; SwiftBar plugin reads only the cache, never calls the API
- **Token accounting**: `local-tokens.py` scans `~/.claude/projects/` JSONL files to tally model usage by window (today/7d) without network calls
- **Blink-on-update**: Flag file (`/tmp/claude-usage-blink`) signals SwiftBar to show ⚡ icon for 10s after fresh fetch, then revert to color-coded icon

## Flow

1. Claude Code events → `claude-session-track.sh` stdin → JSON state + append log per session
2. launchd timer (every 3min) → `claude-usage-fetch.sh` → spawns Claude CLI `/usage` → ANSI stripping → percentage/reset parsing → `/tmp/claude-usage-cache.json` + blink flag
3. SwiftBar plugin (30s refresh) → reads cache + blink flag → renders menu bar icon + dropdown menu
4. Optional: `local-tokens.py` merges local token stats into cache for detailed breakdown

## Integration

- **Input**: Claude Code CLI events (via hooks), launchd scheduler, SwiftBar menu actions (refresh_now, set_interval)
- **Output**: SwiftBar menu bar display, session logs in `/tmp/claude-sessions/`, usage cache JSON
- **Dependencies**: SwiftBar plugin framework, jq (JSON parsing), perl (ANSI cleanup), Claude Code CLI binary, Python 3
- **Installation**: `install.command` symlinks plugin, copies fetcher to `~/.local/bin/`, creates launchd plist for daemon operation
