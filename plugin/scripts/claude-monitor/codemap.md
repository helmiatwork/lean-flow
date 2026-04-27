# plugin/scripts/claude-monitor/

# Codemap: `plugin/scripts/claude-monitor/`

## Responsibility
SwiftBar menu bar plugin suite for monitoring Claude Code sessions and token usage. Tracks real-time session state (thinking/running/idle/stopped) with tool execution history, and displays OAuth usage quotas (5-hour, 7-day, model-specific) with color-coded warnings and automatic refresh via launchd.

## Design
- **Session tracking** (`claude-session-track.sh`): Hook-based JSON state machine — writes per-session `.json` state file + append-only `.log` JSONL for history. Handles `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Stop` events with tool-specific summary extraction (Bash commands, file paths, web queries, subagent spawns).
- **Usage monitoring**: Two SwiftBar plugins with complementary strategies — `claude-usage.30s.sh` for aggressive sync (30s interval, no cache fallback), `claude-usage.3m.sh` for rate-limit resilience (3m interval, caches last-good response). Both directly hit `api.anthropic.com/api/oauth/usage` with OAuth Bearer token from macOS keychain.
- **Local token accounting** (`local-tokens.py`): Parse `~/.claude/projects/*.jsonl` conversation logs, aggregate input/output/cache tokens by model, filter by time window ("today" or "7d").
- **Installation** (`install.command`): Idempotent one-click setup — installs SwiftBar/jq, symlinks plugins, hardens SwiftBar LaunchAgent against state-restore crashes (macOS 26.x Tahoe), sets plugin directory via defaults.

## Flow
1. **Session lifecycle**: Claude Code CLI invokes hook with event JSON (session_id, prompt, tool_name, cwd) → `claude-session-track.sh` parses, updates state file, appends log entry, auto-cleans stopped sessions >10min old.
2. **Session viewing**: User clicks SwiftBar session link → `claude-session-view.sh` renders terminal UI with colored status, tool timeline (last 60 events), elapsed time. Reads state JSON + log JSONL.
3. **Usage display**: SwiftBar ticks every 3m → `claude-usage.3m.sh` fetches `/api/oauth/usage` with OAuth token from keychain. On success, updates cache; on API error, falls back to cached JSON (shows ⚠️ icon + age). Parses utilization %, reset times (ISO → "3pm"/"1d" format), picks icon 🟢/🟡/🔴 by max usage ≥80%/≥50%.
4. **Local accounting**: `local-tokens.py` reads `.jsonl` files, sums tokens per model since cutoff (midnight or 7 days ago), outputs JSON sorted by output tokens desc.

## Integration
- **Claude Code CLI hooks**: Called by `@anthropic-ai/claude-code` on session events; pushes JSON to stdin of `claude-session-track.sh`.
- **macOS keychain**: `security find-generic-password` retrieves OAuth token stored by Claude.ai web UI under key `'Claude Code-credentials'`.
- **SwiftBar ecosystem**: Plugins symlinked to `~/Library/Application Support/SwiftBar/Plugins/claude-usage.*.sh`; Sw
