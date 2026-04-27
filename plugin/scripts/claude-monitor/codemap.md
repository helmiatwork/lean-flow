# plugin/scripts/claude-monitor/

# codemap.md — `plugin/scripts/claude-monitor/`

## Responsibility
Monitors Claude Code session activity and API usage quotas. Provides SwiftBar menu bar widget showing token consumption across session/weekly/model windows, plus live session viewer. Tracks tool invocations and spawned subagents via event hooks.

## Design
- **Event-driven tracking**: `claude-session-track.sh` receives `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop` events; writes JSON state file + appends JSONL history per session.
- **Dual data sources**: API rate-limit headers (`claude-usage-fetch.sh`) + local token accounting (`local-tokens.py` scans `~/.claude/projects/*.jsonl`).
- **Stateless display**: SwiftBar plugin reads cached JSON (`/tmp/claude-usage-cache.json`), checks blink flag, renders color-coded icon (🟢/🟡/🔴) + percentages.
- **Lazy subagent support**: Session tracking extracts `Agent` tool summaries; spawned agents get their own `session_id` entries.

## Flow
1. **Session tracking**: Event hook → `claude-session-track.sh` (stdin JSON) → parses event type + tool details → writes `$SESSION_DIR/{session_id}.json` (current state) + `.log` (JSONL history)
2. **Usage refresh**: launchd timer (every 3m) → `claude-usage-fetch.sh` → minimal Claude API call → parses `anthropic-ratelimit-unified-*` headers → merges `local-tokens.py` stats → `/tmp/claude-usage-cache.json`
3. **Display**: SwiftBar calls `claude-usage.30s.sh` → reads cache + blink flag → renders title bar + dropdown menu with reset times
4. **Session viewer**: `claude-session-view.sh {SESSION_ID}` → reads state + log → live terminal display (last 60 events, colored by event type)

## Integration
- **Input**: Claude Code CLI event hooks (via stdin JSON); OAuth token from macOS keychain (`security find-generic-password`)
- **Output**: SwiftBar menu bar icon + dropdown; JSON caches in `/tmp/`; session state in `/tmp/claude-sessions/`
- **Dependencies**: `jq`, `python3`, `curl`, SwiftBar app, launchd agent for timer (`com.claude.usage-fetch.plist`)
- **Install**: `install.command` symlinks plugin to `~/Library/Application Support/SwiftBar/Plugins/`, copies fetcher to `~/.local/bin/`, registers launchd agent
