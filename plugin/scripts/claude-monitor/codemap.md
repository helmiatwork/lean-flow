# plugin/scripts/claude-monitor/

# claude-monitor/ Codemap

## Responsibility
Provides real-time monitoring of Claude Code sessions and API usage quotas for SwiftBar menu bar display. Tracks session state (thinking/running/idle/stopped), tool execution history, and consumption of rate-limited API tokens across multiple time windows (session/5h/7d).

## Design
- **Session tracking**: Hook-based event system (`UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`) writes JSON state + JSONL history logs to `/tmp/claude-sessions/` per session ID
- **Usage fetching**: `claude-usage-fetch.sh` makes minimal API request to extract rate-limit headers (`anthropic-ratelimit-unified-*`); caches percentages + reset times in `/tmp/claude-usage-cache.json`
- **Local token stats**: `local-tokens.py` scans `~/.claude/projects/*.jsonl` to build per-model usage breakdowns (no API calls)
- **Display layer**: SwiftBar plugin reads cache and renders color-coded menu bar (🟢/🟡/🔴) with blink-on-update UX via flag file
- **Installation**: Single `install.command` script orchestrates symlinks, launchd agent setup, and dependency checks

## Flow
1. Claude Code CLI emits session events → piped to `claude-session-track.sh` → writes state JSON + appends to log
2. `claude-usage-fetch.sh` runs on launchd interval (~3min) → hits API with OAuth token → parses headers → writes cache JSON + blink flag
3. `local-tokens.py` (invoked from fetcher) reads session JSONL files → aggregates tokens by model → merged into cache
4. `claude-usage.30s.sh` (SwiftBar) reads cache → detects blink flag age → renders menu bar title + dropdown menu
5. User clicks menu bar → calls `claude-session-view.sh` → displays live session activity log with colors and tool names

## Integration
- **Input**: Claude Code CLI hooks (via stdin JSON), macOS keychain (OAuth token), session files in `~/.claude/projects/`
- **Output**: SwiftBar menu bar widget, cached JSON at `/tmp/claude-usage-cache.json`, session logs at `/tmp/claude-sessions/`
- **Dependencies**: `jq`, `curl`, `python3`, SwiftBar, launchd
- **Config**: `~/.config/claude-usage/config` (refresh interval), `~/Library/LaunchAgents/com.claude.usage-fetch.plist` (daemon)
