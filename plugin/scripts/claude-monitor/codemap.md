# plugin/scripts/claude-monitor/

## Responsibility

This directory provides SwiftBar menu bar widgets and data collection scripts for monitoring Claude API usage and session activity on macOS. It tracks token consumption against quotas, displays live Claude Code session state, and auto-refreshes via launchd.

## Design

- **SwiftBar plugins** (`claude-usage.30s.sh`, `claude-session-view.sh`) — stateless renderers that fetch current state and format for menu bar display; update every 30 seconds
- **State tracking** (`claude-session-track.sh`) — event-driven hook that writes JSON state files and append-only logs per session to `/tmp/claude-sessions/`
- **Local analysis** (`local-tokens.py`) — reads project `.jsonl` files and aggregates token usage by model for a time window ("today" or "7d")
- **Installation** (`install.command`) — bash installer that wires SwiftBar plugins into `~/Library/Application Support/SwiftBar/Plugins/`, manages LaunchAgents, and hardens against macOS 26.x state-restore crashes

## Flow

1. **Usage monitoring**: `claude-usage.30s.sh` queries `api.anthropic.com/api/oauth/usage` directly (reads OAuth token from macOS keychain), formats percentages + reset times, renders color-coded icon (🟢/🟡/🔴 based on max utilization ≥50%/≥80%)
2. **Session tracking**: Claude Code CLI pipes JSON events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) to `claude-session-track.sh`, which extracts tool names/summaries and writes to `$SESSION_DIR/{session_id}.json` (state) and `.log` (history)
3. **Session viewer**: `claude-session-view.sh` reads state + log files for a session ID, renders formatted terminal UI with live status, tool execution timeline, and activity age
4. **Local token accounting**: `local-tokens.py` scans `~/.claude/projects/*.jsonl`, sums input/output/cache tokens by model within a time window, outputs JSON with per-model percentages

## Integration

- **SwiftBar**: plugins symlinked into Plugins directory and executed on 30s interval; CLI actions (refresh, menu clicks) invoke bash subcommands with `refresh=true` parameter
- **Claude Code CLI**: hooks pipe structured JSON events to `claude-session-track.sh` via stdin; session state is queried by `claude-session-view.sh` for live display
- **macOS keychain**: OAuth token read via `security find-generic-password` from 'Claude Code-credentials' entry
- **LaunchAgent**: installer optionally creates `com.ameba.SwiftBar.plist` for crash recovery with `KeepAlive` flag
- **Local projects**: `local-tokens.py` reads `.claude/projects/` directory structure for off-API token analysis
