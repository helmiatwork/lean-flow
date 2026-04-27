# plugin/scripts/claude-monitor/

## Responsibility
Monitor and display Claude Code token usage in the macOS menu bar via SwiftBar. Track active Claude sessions in real-time, including tool usage and subagent activity. Provide local token accounting across project directories without repeated API calls.

## Design
- **Direct OAuth API fetch** (`claude-usage.30s.sh`): queries `api.anthropic.com/api/oauth/usage` every 30s with Bearer token from macOS keychain, renders color-coded usage % (🟢/🟡/🔴) and reset times
- **Session tracking** (`claude-session-track.sh`): hook-based event logger that writes per-session state + append-only JSON logs (`/tmp/claude-sessions/{sid}.json`, `{sid}.log`); captures tool invocations (Bash, Write, Agent, WebSearch, etc.) with truncated summaries
- **Session viewer** (`claude-session-view.sh`): live terminal UI showing current session status, active tool, and last 60 events with timestamps and styled output
- **Local token accounting** (`local-tokens.py`): parses `~/.claude/projects/*.jsonl` transcripts, aggregates input/output/cache tokens by model for "today" or "7d" windows, outputs JSON with % breakdown
- **One-click installer** (`install.command`): checks/installs jq + SwiftBar, symlinks plugins, creates LaunchAgent, hardens SwiftBar against state-restore crash (macOS 26.x Tahoe)

## Flow
1. **Usage fetch**: `claude-usage.30s.sh` runs every 30s via SwiftBar, reads OAuth token from keychain (`security find-generic-password`), calls `/api/oauth/usage`, parses 5h/7d utilization % and reset timestamps, renders menu bar
2. **Session tracking**: Claude Code CLI hooks (UserPromptSubmit → PreToolUse → PostToolUse → Stop) pipe JSON to `claude-session-track.sh`, which extracts session_id/tool_name/input and logs to `/tmp/claude-sessions/{sid}.json` (state) + `{sid}.log` (history); old stopped sessions auto-cleaned after 10m
3. **Session view**: user clicks session in menu → opens `claude-session-view.sh` terminal window, tails state file + renders last 60 log events with colors (yellow prompt, cyan tool-start, green tool-done, dim stop)
4. **Local accounting**: `local-tokens.py` ingests Claude project JSONL files, filters by timestamp window, sums tokens per model, outputs sorted JSON with % of total output tokens

## Integration
- **Keychain**: `claude-usage.30s.sh` reads Claude OAuth token via `security find-generic-password -s 'Claude Code-credentials'`
- **SwiftBar plugin interface**: `.30s.sh` symlinked into `~/Library/Application Support/SwiftBar/Plugins/`; outputs pipe-delimited format with bash actions for refresh/click-through
- **Claude Code CLI hooks**: session-track.sh receives JSON from Claude Code internal event stream (must be wired into CLI hook system)
- **Local Claude projects**: `local-tokens.py` reads `~/.claude/projects/*.jsonl` transcripts written by Claude Code during session operations
- **Install target**: `install.command` checks Claude CLI presence, installs SwiftBar + jq via Homebrew, manages Launch
