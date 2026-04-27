# plugin/scripts/claude-monitor/

## Responsibility

Claude Code usage monitoring and session tracking for SwiftBar menu bar widget. Provides real-time token consumption metrics (5-hour, 7-day windows by model), live session activity viewer, and local token accounting from Claude Code project files.

## Design

- **Stateless fetcher + cache pattern**: `claude-usage.3m.sh` reads cached JSON directly; no daemon needed. Falls back to last-good cache on API errors with age indicator.
- **Event-stream tracking**: `claude-session-track.sh` hooks Claude Code lifecycle events (UserPromptSubmit, PreToolUse, PostToolUse, Stop) into per-session JSON log + state file in `/tmp/claude-sessions/`.
- **Tool-specific summaries**: Extracts context per tool type (Bash command, file path, search query, agent description) for compact logging.
- **Local token accounting**: `local-tokens.py` scans `~/.claude/projects/*.jsonl` files; no API calls needed for offline usage reports.

## Flow

1. **Usage display** (`claude-usage.3m.sh`): SwiftBar invokes every 3min → curl `/api/oauth/usage` with keychain token → cache result → render menu bar (color: 🟢/🟡/🔴 based on utilization %).
2. **Session monitoring**: Claude Code emits JSON events to stdin → `claude-session-track.sh` EVENT_TYPE parses, extracts tool/summary, writes state file + appends log → `claude-session-view.sh` reads live state/log, renders colored activity feed in terminal.
3. **Local accounting**: `local-tokens.py` parses JSONL logs, groups by model, sums input/output/cache tokens, outputs JSON with percentages.

## Integration

- **Keychain**: Stores Claude OAuth token at key `'Claude Code-credentials'`; retrieved by usage plugin.
- **SwiftBar**: Discovers plugins in `~/Library/Application Support/SwiftBar/Plugins/`; respects `.3m.sh` naming for 3-min refresh.
- **LaunchAgent**: `install.command` creates plist to keep SwiftBar alive and workaround macOS 26.x state-restore crash.
- **Claude Code CLI**: Hooks into session lifecycle; emits events to scripts via stdin. Local projects stored in `~/.claude/projects/`.
