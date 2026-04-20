# plugin/scripts/claude-monitor/

## Responsibility
Provides real-time monitoring and usage tracking for Claude Code sessions via a SwiftBar menu bar widget. Tracks session events (prompts, tool use, stops), fetches token usage percentages and reset times from the Claude CLI, and displays live session state with color-coded usage indicators.

## Design
- **Event-driven session tracking** (`claude-session-track.sh`): intercepts hook events (UserPromptSubmit, PreToolUse, PostToolUse, Stop), extracts context (tool name, command, file path), and writes JSON state files + append-only logs to `/tmp/claude-sessions/`.
- **Cached usage model** (`claude-usage-fetch.sh`): runs Claude CLI in a controlled terminal session, parses `/usage` output with ANSI-stripping regex, extracts percentages and reset times, writes immutable cache to `/tmp/claude-usage-cache.json`.
- **SwiftBar plugin pattern** (`claude-usage.3m.sh`): stateless renderer reading cached JSON, detects recent updates via blink flag (10s TTL), renders color-coded icon (🟢/🟡/🔴) and dropdown menu.
- **Daemon automation**: launchd plist runs fetcher every 180s; SwiftBar refreshes every 30s (asymmetric polling avoids thundering herd).

## Flow
1. Claude Code emits events → `claude-session-track.sh` reads stdin (jq-parsed), writes `${SESSION_ID}.json` (state) and `.log` (append-only history)
2. Launchd timer → `claude-usage-fetch.sh` spawns `script` wrapper around Claude CLI, extracts `/usage` via ANSI-stripped regex, writes cache + blink flag
3. SwiftBar timer → `claude-usage.3m.sh` reads cache, checks blink flag age, renders icon + dropdown; menu actions (refresh, interval config) trigger fetcher or update config file

## Integration
- **Hook integration**: expects Claude Code to pipe event JSON to `claude-session-track.sh` with event type as `$1` (UserPromptSubmit, PreToolUse, PostToolUse, Stop).
- **SwiftBar integration**: plugins discover via symlink in `~/Library/Application Support/SwiftBar/Plugins/`, interval suffix (`*.3m.sh`) controls refresh cadence, menu item `bash:` commands trigger scripts.
- **CLI integration**: `claude-usage-fetch.sh` depends on `claude` binary in PATH or `~/.nodenv/versions/*/bin/claude`, uses disallowed tools list to prevent accidental file edits during `/usage` polling.
- **Shared state**: all scripts read/write `/tmp/` files (cache, lock, blink flag, session dir) — no persistent DB; install script creates symlinks for updatability.
