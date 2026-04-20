# plugin/scripts/claude-monitor/

## Responsibility
Session tracking and usage monitoring for Claude Code via SwiftBar menu bar widget. Captures session events (prompts, tool use, completion), maintains live session state, fetches token usage from the Claude CLI, and displays real-time status with color-coded thresholds and auto-refresh.

## Design
- **Event-driven tracking**: `claude-session-track.sh` consumes stdin JSON (UserPromptSubmit, PreToolUse, PostToolUse, Stop) and writes state to `/tmp/claude-sessions/{session_id}.json` + appends to `.log` for history
- **Live viewer**: `claude-session-view.sh` renders formatted terminal UI from state/log files with color codes and elapsed time
- **Usage fetcher**: `claude-usage-fetch.sh` spawns a minimal Claude session, pipes `/usage` command through `script`, strips ANSI codes with `perl`, regex-extracts percentages and reset times, caches JSON to `/tmp/claude-usage-cache.json`
- **SwiftBar integration**: `claude-usage.3m.sh` reads cache, computes color (🟢/🟡/🔴), detects blink flag for 10-second visual feedback on refresh, renders dropdown menu
- **Daemon automation**: `install.command` creates launchd plist to run fetcher every 3 minutes; plugin symlinked to SwiftBar plugins directory

## Flow
1. Session events → piped to `claude-session-track.sh` → updates `/tmp/claude-sessions/{id}.json` state + appends `.log` entry
2. Every 3 min: launchd triggers `claude-usage-fetch.sh` → spawns Claude CLI session → parses `/usage` output → writes `/tmp/claude-usage-cache.json` + sets blink flag
3. SwiftBar calls `claude-usage.3m.sh` every 30s → reads cache JSON → checks blink flag age → renders menu bar icon + dropdown with percentages/reset times
4. User clicks "Refresh Now" → touches blink flag → runs fetcher in background → SwiftBar re-renders with ⚡ for 10s, then reverts to color icon

## Integration
- **Input**: stdin JSON from Claude Code hook system (session event stream); Claude CLI `/usage` command output
- **Output**: SwiftBar menu bar widget; cached JSON at `/tmp/claude-usage-cache.json`; session files at `/tmp/claude-sessions/`
- **Dependencies**: SwiftBar (plugin host), `jq` (JSON), `perl` (ANSI stripping), `claude` CLI (usage data), macOS `script` command (TTY capture)
- **User interaction**: SwiftBar menu click → manual refresh trigger; config file at `~/.config/claude-usage/config` for custom refresh interval
