# plugin/scripts/claude-monitor/

## Responsibility
Monitors and displays Claude Code token usage in the macOS menu bar via SwiftBar, tracking per-session activity and local model consumption. Provides real-time session state tracking for Claude Code interactions (user prompts, tool execution, subagents).

## Design
- **Session tracking**: `claude-session-track.sh` hooks into Claude events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) and writes JSON state + append-only logs per session to `/tmp/claude-sessions/`
- **Live viewer**: `claude-session-view.sh` renders terminal UI showing current session status, tool chain, elapsed time, and last 60 events from the log
- **Usage monitor**: `claude-usage.30s.sh` directly queries `api.anthropic.com/api/oauth/usage` every 30s with OAuth token from macOS keychain, computes utilization % across 5-hour session / 7-day windows (all models + Sonnet), renders SwiftBar menu with color-coded icons (🟢/🟡/🔴)
- **Local token accounting**: `local-tokens.py` aggregates `.claude/projects/*.jsonl` conversation logs by model and window (today/7d), computing input/output/cache metrics for offline dashboarding

## Flow
1. **Session events** → `claude-session-track.sh` receives JSON via stdin, extracts session_id/tool/summary, updates `/tmp/claude-sessions/{session_id}.json` state + appends to `.log` with timestamp
2. **Session view** → user clicks SwiftBar or runs `claude-session-view.sh {SESSION_ID}`, reads state file + tails log, renders formatted terminal UI with color codes and elapsed times
3. **Usage fetch** → `claude-usage.30s.sh` retrieves OAuth token from keychain, calls `/api/oauth/usage`, parses utilization percentages, renders menu bar icon + dropdown with reset times
4. **Local accounting** → `local-tokens.py` scans project JSONLs (triggered externally), groups by model, outputs JSON with per-model token counts and % of total output

## Integration
- **Hooks into Claude Code**: session-track.sh receives event JSON from Claude CLI (integration point via stdin redirection in Claude config)
- **macOS keychain**: OAuth token stored by Claude Code app; usage monitor reads via `security` CLI
- **SwiftBar plugins**: `claude-usage.30s.sh` installed as `~/Library/Application Support/SwiftBar/Plugins/` symlink; refreshes on 30s tick
- **Local filesystem**: session state in `/tmp/claude-sessions/` (ephemeral); project logs in `~/.claude/projects/` (persistent, queried by local-tokens.py)
- **Installer**: `install.command` symlinks plugins, checks dependencies (jq, Claude CLI, SwiftBar), optionally configures LaunchAgent for periodic refresh
