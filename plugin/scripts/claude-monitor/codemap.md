# plugin/scripts/claude-monitor/

## Responsibility

Claude Code session tracking and usage monitoring for SwiftBar macOS menu bar. Provides real-time visibility into active Claude sessions (prompts, tool execution, subagents) and periodic token usage metrics with color-coded alerts.

## Design

- **Event-driven tracking** (`claude-session-track.sh`): hooks into Claude Code lifecycle events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) and logs structured JSON per session to `/tmp/claude-sessions/`
- **Live session viewer** (`claude-session-view.sh`): renders terminal UI with event history, status, active tool, and elapsed time
- **Data collection via CLI automation** (`claude-usage-fetch.sh`): spawns a Claude session, automates `/usage` command via `script`, strips ANSI codes with perl, parses percentages and reset times into JSON cache
- **Minimal SwiftBar widget** (`claude-usage.3m.sh`): reads cached JSON, implements local blink-on-update flag (no API calls), renders color-coded icon and dropdown menu
- **One-click installer** (`install.command`): symlinks plugins, installs launchd agent, ensures jq/SwiftBar/Claude CLI present

## Flow

1. **Session tracking**: Claude Code emits events → piped to `claude-session-track.sh` → writes state JSON + appends log line to `/tmp/claude-sessions/{sid}.json` and `.log`
2. **Usage fetching**: launchd triggers `claude-usage-fetch.sh` every 3 min → spawns Claude session, reads `/usage` output, perl strips formatting, extracts percentages/dates → writes `/tmp/claude-usage-cache.json` + touches blink flag
3. **Display**: SwiftBar runs `claude-usage.3m.sh` every 30s → reads cache, checks 10s-old blink flag → renders icon (🟢/🟡/🔴 or ⚡) + percentage/reset times in dropdown

## Integration

- **Claude Code hooks**: expects piped JSON input on session events (invoked externally)
- **SwiftBar**: plugin symlinked to `~/Library/Application Support/SwiftBar/Plugins/` with `3m` refresh interval
- **launchd**: plist at `~/Library/LaunchAgents/com.ichigo.claude-usage-fetch.plist` runs fetcher daemon
- **Files**: uses `/tmp/claude-*` for ephemeral state, `~/.local/bin/` for installed scripts, `~/.config/claude-usage/` for user config (refresh interval)
