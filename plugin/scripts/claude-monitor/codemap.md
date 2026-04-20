# plugin/scripts/claude-monitor/

## Responsibility

Monitors Claude Code token usage via SwiftBar menu bar widget. Tracks three usage tiers (session, week all-models, week Sonnet-only) with color-coded status and auto-refresh via launchd. Also provides live session tracking for Claude conversations including tool execution history and subagent spawning.

## Design

**Session Tracking** (`claude-session-track.sh`): Event-driven JSON logging per `session_id`. Writes live state file (`${session_id}.json`) + append-only history log (`${session_id}.log`). Tracks lifecycle (UserPromptSubmit → PreToolUse/PostToolUse → Stop) with tool-specific summary extraction (Bash commands, file paths, queries, etc.). Auto-cleanup of stopped sessions >10 min old.

**Usage Fetcher** (`claude-usage-fetch.sh`): Spawns Claude CLI in headless mode via `script` command, sends `/usage` command, strips ANSI codes with perl, regex-parses three percentages + three reset times. Caches to JSON; prevents concurrent runs via lock file. Runs in launchd (default 180s interval).

**SwiftBar Plugins** (`claude-usage.30s.sh`, `claude-usage.3m.sh`): Read cached JSON, compute max percentage for color logic (🟢 <50%, 🟡 50-80%, 🔴 >80%), detect "blink" flag for 10s cyan flash on data updates. Render dropdown with session/week/sonnet breakdowns and countdown timer.

## Flow

1. **launchd** triggers fetcher every 3 minutes → spawns minimal Claude session → runs `/usage` → parses output → writes `/tmp/claude-usage-cache.json` + sets `/tmp/claude-usage-blink` flag
2. **SwiftBar plugin** (runs on fixed 30s/3m schedule) reads cache, checks blink age, renders title bar icon + dropdown
3. **Session tracking** runs inline on Claude events: hook receives JSON stdin (session_id, cwd, tool name, etc.) → writes state + appends log → viewer (`claude-session-view.sh`) reads state + renders live progress with last 60 events

## Integration

- **Upstream**: Receives Claude Code CLI events (hook integration via stdin) and must have Claude CLI installed (`npm install -g @anthropic-ai/claude-code`)
- **SwiftBar ecosystem**: Symlinked plugins in `~/Library/Application Support/SwiftBar/Plugins/`; uses `swiftbar://refreshplugin` URL scheme to trigger manual refreshes
- **System integrations**: launchd plist for background daemon; uses `jq`, `perl`, standard Unix tools; stores temp files in `/tmp/` (cache, logs, state)
- **Config**: `~/.config/claude-usage/config` for refresh interval customization; `install.command` is macOS-specific installer (Homebrew, launchctl)
