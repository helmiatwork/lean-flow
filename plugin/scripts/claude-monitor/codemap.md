# plugin/scripts/claude-monitor/

## Responsibility

This directory provides a SwiftBar menu bar widget for monitoring Claude Code token usage and an interactive session activity tracker. It consists of a background fetcher daemon that periodically queries Claude's `/usage` endpoint, caches results, and a pair of display scripts that render usage stats (with color-coded alerts) and live session events in the menu bar and terminal.

## Design

- **Separation of concerns**: Fetcher (`claude-usage-fetch.sh`) handles API interaction and writes immutable cache; plugins (`claude-usage.3m.sh`) only read local state files and render
- **File-based IPC**: All communication via JSON cache (`/tmp/claude-usage-cache.json`), state files (`/tmp/claude-sessions/`), and flag files (blink detection)
- **Session tracking**: `claude-session-track.sh` hooks into Claude events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) to build per-session JSON state + append-only logs; `claude-session-view.sh` renders live activity with ANSI colors and Python-based log parsing
- **Install automation**: Single `install.command` handles dependency checks (jq, SwiftBar, Claude CLI), directory creation, symlink setup, and launchd agent registration

## Flow

1. **Data collection** (every 3 min): launchd triggers `claude-usage-fetch.sh` → spawns Claude CLI session with `/usage` command → strips ANSI codes via perl regex → extracts percentages & reset times → writes `/tmp/claude-usage-cache.json` + touches `/tmp/claude-usage-blink` flag
2. **Menu bar display** (every 30s): SwiftBar runs `claude-usage.3m.sh` → reads cache JSON → checks blink flag age (shows ⚡ if < 10s old) → renders color-coded icon (🟢/🟡/🔴) with session/week/sonnet percentages
3. **Session tracking** (on-demand): `claude-session-track.sh` reads stdin JSON events, writes state to `/tmp/claude-sessions/${session_id}.json`, appends log lines; `claude-session-view.sh` tails log with formatted timestamps and tool names
4. **Cleanup**: Fetcher auto-deletes stopped sessions older than 10 minutes; blink flag expires naturally after 10s

## Integration

- **SwiftBar**: Plugin entry point is symlink at `~/Library/Application Support/SwiftBar/Plugins/claude-usage.3m.sh`; menu actions (`refresh_now`, `set_interval`) call back to plugin via `swiftbar://refreshplugin` protocol
- **launchd**: Daemon plist at `~/Library/LaunchAgents/com.ichigo.claude-usage-fetch.plist` (StartInterval 180s) runs fetcher script in background; logs to `/tmp/claude-usage-fetch.log`
- **Claude Code CLI**: Invoked with `--no-chrome --disallowedTools` to prevent interactive tool use; interactive input (Enter, `/usage`, Esc, `/exit`) piped via `script` command
- **Session hooks** (implicit): External scripts/agents invoke `claude-session-track.sh <EVENT_TYPE>` with JSON stdin to populate live session views
