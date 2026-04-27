# plugin/scripts/claude-monitor/

## Responsibility

Session monitoring and token usage tracking for Claude Code via SwiftBar menu bar widget. Captures real-time Claude activity (prompts, tool use, subagents) into per-session JSON logs and provides live viewing; separately tracks OAuth API quota consumption with color-coded status indicator.

## Design

**Session tracking** (`claude-session-track.sh`): Event-driven hook that parses stdin JSON (session_id, tool_name, prompt, etc.), writes atomic state files (`/tmp/claude-sessions/{id}.json`) for current status, and appends JSONL history logs (`/tmp/claude-sessions/{id}.log`). Handles five event types (UserPromptSubmit, PreToolUse, PostToolUse, Stop) with tool-specific summary extraction (Bash commands, file paths, search queries, subagent descriptions).

**Session viewer** (`claude-session-view.sh`): ANSI-colored terminal UI rendering live state + last 60 events with timestamps, tool icons, and truncated details. Embedded Python post-processor formats event logs into colorized rows.

**Usage monitor** (`claude-usage.30s.sh`): SwiftBar plugin fetching `/api/oauth/usage` directly via Bearer token from macOS keychain every 30s. Computes percentages for 5-hour session and 7-day windows (all models + Sonnet-specific), formats reset times ("3d", "11am"), maps thresholds to traffic-light icons (🟢/🟡/🔴).

**Local token counter** (`local-tokens.py`): Aggregates token usage from Claude Code project JSONL logs (`~/.claude/projects/**/*.jsonl`) by model, filtering by window ("today" or "7d"), reporting input/output/cache metrics.

## Flow

1. Claude Code subprocess emits events → stdin of `claude-session-track.sh`
2. Hook parses session_id + event type → updates `/tmp/claude-sessions/{id}.json` + appends to `.log`
3. User clicks session ID in SwiftBar → invokes `claude-session-view.sh` → renders live state + history tail
4. SwiftBar plugin tick (30s) → reads keychain token → calls `api.anthropic.com/api/oauth/usage` → caches percentages + reset times → menu bar renders icon + tooltip
5. Manual token audit: `local-tokens.py` scans JSONL projects → aggregates by model + window → JSON output

## Integration

- **Entrypoint**: `install.command` (double-click installer) symlinks plugin to `~/Library/Application Support/SwiftBar/Plugins/`, ensures jq + SwiftBar present, hardens SwiftBar LaunchAgent against state-restore crash
- **Keychain**: OAuth token stored by Claude Code CLI under "Claude Code-credentials" key; `claude-usage.30s.sh` reads via `security find-generic-password`
- **Claude Code CLI hooks**: Subprocess dispatch expects `claude-session-track.sh` as pre/post-tool and session stop handler
- **File storage**: Session state/logs in `/tmp/claude-sessions/` (ephemeral); local JSONL audit trails in `~/.claude/projects/` (persistent)
