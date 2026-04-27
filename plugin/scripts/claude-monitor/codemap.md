# plugin/scripts/claude-monitor/

## Responsibility
Monitors Claude Code token usage and session activity via SwiftBar menu bar widgets. Tracks real-time session events (prompts, tool use, subagents) and displays usage percentages with countdown timers for rate-limit resets.

## Design
- **Event-driven tracking** (`claude-session-track.sh`): Hooks into Claude Code lifecycle (UserPromptSubmit, PreToolUse, PostToolUse, Stop) via stdin JSON, writes state + append-only logs per session to `/tmp/claude-sessions/{session_id}.{json,log}`
- **Live session viewer** (`claude-session-view.sh`): Terminal UI with colored status indicators and scrollable event history (Python + jq for JSON parsing)
- **Direct OAuth fetch** (`claude-usage.30s.sh`): SwiftBar plugin reads macOS keychain for Claude OAuth token, queries `api.anthropic.com/api/oauth/usage` every 30s, formats reset times dynamically ("11am", "3d", etc.) with color-coded icons (🟢/🟡/🔴) based on utilization thresholds
- **Local token accounting** (`local-tokens.py`): Aggregates `~/.claude/projects/*.jsonl` by model with cache stats; supports "today" and "7d" windows

## Flow
1. Claude Code CLI emits session events (via hook) → `claude-session-track.sh` parses event type and tool name, appends to session log and updates state file
2. User clicks SwiftBar menu → `claude-session-view.sh` reads session state/logs, renders terminal with last 60 events in human-readable format
3. Every 30s SwiftBar invokes `claude-usage.30s.sh` → fetches OAuth token from keychain → calls `/api/oauth/usage` → extracts session/week/sonnet percentages and reset timestamps → renders title bar + dropdown
4. `local-tokens.py` scans project JSONL history, tallies input/output/cache tokens per model, outputs JSON sorted by usage

## Integration
- **SwiftBar**: Plugin symlinked to `~/Library/Application Support/SwiftBar/Plugins/claude-usage.30s.sh`; runs on 30-second interval with click handlers for refresh
- **macOS keychain**: OAuth token stored by Claude Code CLI under `'Claude Code-credentials'`; script reads via `security find-generic-password`
- **Claude Code CLI hooks**: Session tracking activated by hook subscription (event stream via stdin in JSON format)
- **Anthropic API**: Direct HTTPS calls to `/api/oauth/usage` with Bearer token auth and beta header (`oauth-2025-04-20`)
- **Install orchestration** (`install.command`): Sets up plugin symlinks, hardens SwiftBar against state-restore crashes (disables NSQuitAlwaysKeepsWindows, creates LaunchAgent with KeepAlive)
