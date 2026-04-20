# plugin/scripts/claude-monitor/

## Responsibility

Monitor and display Claude Code token usage in the macOS menu bar via SwiftBar. Track active Claude sessions with real-time tool execution logging. Provide automated periodic usage fetching and local caching without consuming tokens during display/refresh cycles.

## Design

**Three-layer architecture:**
- **Fetcher** (`claude-usage-fetch.sh`): Spawns minimal Claude session, parses `/usage` output via ANSI stripping (perl regex), writes JSON cache + blink flag. Locked to prevent concurrent runs.
- **SwiftBar Plugin** (`claude-usage.3m.sh`): Reads cached JSON, detects blink flag (10s window), renders color-coded menu bar (🟢/🟡/🔴 by usage threshold). Zero token cost—local file I/O only.
- **Session Tracker** (`claude-session-track.sh`): Event hook that maintains per-session state JSON + append-only log. Handles UserPromptSubmit, PreToolUse, PostToolUse, Stop events; auto-cleans stopped sessions after 10 minutes.
- **Session Viewer** (`claude-session-view.sh`): Interactive terminal display of live session state and last 60 events with colored icons and elapsed times.

**Key patterns:**
- State files in `/tmp/claude-sessions/` (per-session JSON + log) and `/tmp/claude-usage-cache.json` (global usage)
- Blink detection via filesystem flag (`/tmp/claude-usage-blink`) with age-based expiry
- ANSI escape code cleanup via ordered perl regex (cursor-forward, CSI, OSC, others)
- Tool-specific summary extraction from JSON inputs (Bash commands, file paths, search queries, subagent descriptions)

## Flow

**Usage monitoring:**
1. launchd triggers fetcher every 180s → `claude-usage-fetch.sh` acquires lock, spawns Claude session with `script` command
2. Automated keypresses: Enter (trust), `/usage` (fetch), Esc (close), `/exit` (quit)
3. Session output piped through ANSI stripper, percentages and reset times parsed via regex
4. Results written to `/tmp/claude-usage-cache.json`, blink flag created
5. SwiftBar plugin polls cache every 30s; if blink flag exists and age < 10s, displays ⚡; else color-coded icon
6. Menu dropdown shows latest session/week/sonnet usage, countdown to next refresh

**Session tracking (parallel):**
1. Claude hooks (UserPromptSubmit, PreToolUse, PostToolUse, Stop) pipe JSON to `claude-session-track.sh <EVENT_TYPE>`
2. Session ID extracted; state file updated with status/tool/summary; log entry appended with timestamp + event
3. `claude-session-view.sh <SESSION_ID>` reads state + log tails, renders formatted terminal UI with last 60 events colored by type
4. Cleanup: stopped sessions deleted if age > 600s

## Integration

- **Upstream:** Claude Code CLI (invoked by fetcher; hooked by session tracker via event JSON)
- **UI:** SwiftBar (reads plugin from `~/Library/Application Support/SwiftBar/Plugins/`, refreshes per interval, executes `refresh_now` / `set_interval` actions)
- **System:** launchd (loads plist from `~/Library/Launch
