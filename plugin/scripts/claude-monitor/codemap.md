# plugin/scripts/claude-monitor/

## Responsibility

This directory provides SwiftBar menu bar widgets for monitoring Claude Code token usage and session activity. It tracks real-time Claude sessions (including subagents), displays usage percentages with color-coded alerts, and auto-refreshes via launchd. Three distinct monitoring systems: **session tracking** (lifecycle logging), **usage fetching** (periodic data collection from Claude CLI), and **display plugins** (SwiftBar rendering with blink feedback).

## Design

- **Separation of concerns**: Fetcher (`claude-usage-fetch.sh`) collects data; plugins (`claude-usage.*.sh`) display it; tracker (`claude-session-track.sh`) logs events. No direct coupling.
- **File-based state**: All data stored locally (`/tmp/claude-sessions/`, `/tmp/claude-usage-cache.json`). No API calls except initial fetch via Claude CLI.
- **Event-driven tracking**: `claude-session-track.sh` appends JSON lines to per-session logs on four events (UserPromptSubmit, PreToolUse, PostToolUse, Stop). Tool-specific summaries extracted via jq (Bash commands, file paths, web queries, subagent descriptions).
- **Lock + cache pattern**: Fetcher uses lock file to prevent concurrent runs; SwiftBar plugins read immutable cache + blink flag for 10s feedback window.
- **ANSI stripping pipeline**: Fetcher uses perl regex (cursor-forward → CSI sequences → OSC sequences) to extract clean text from Claude CLI output before percentage/reset-time parsing.

## Flow

1. **Fetcher cycle** (every 3 min via launchd): `claude-usage-fetch.sh` spawns Claude CLI with `script` command, pipes `/usage` command, strips ANSI codes, regex-extracts three percentages + three reset times, calculates remaining days/hours, writes to `/tmp/claude-usage-cache.json`, touches blink flag.
2. **Session tracking** (realtime): External hooks pipe JSON events → `claude-session-track.sh` → state file updated (`*.json`) and appended to log (`*.log`). Auto-cleanup stops stopped sessions after 10 min.
3. **Display rendering** (SwiftBar 30s–3m interval): Plugin reads cache → selects color (🟢/🟡/🔴 by max %), checks blink flag age (<10s = cyan ⚡), renders title bar + dropdown menu. User clicks "Refresh" → triggers fetcher in background + blinks immediately.
4. **Session viewer** (on-demand): `claude-session-view.sh` renders live dashboard from session state + log file; Python3 parses last 60 events with ANSI colors; displays project, status, tool/command, elapsed time.

## Integration

- **Input**: Claude Code CLI (`claude` binary) via interactive session; external session tracking hooks inject JSON.
- **Output**: SwiftBar menu bar display (via symlink in `~/Library/Application Support/SwiftBar/Plugins/`); launchd agent (`~/Library/LaunchAgents/com.ichigo.claude-usage-fetch.plist`) runs fetcher on schedule.
- **Storage**: Shared state at `/tmp/` (ephemeral, safe for multiple sessions). Config stored at `~/.config/claude-usage/config` (refresh interval).
- **Installation**: `install.command` (one-click) coordinates Homebrew (jq, SwiftBar), creates
