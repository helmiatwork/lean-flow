# plugin/scripts/claude-monitor/

## Responsibility
Monitors Claude Code CLI token usage and displays it in the macOS menu bar via SwiftBar. Provides session lifecycle tracking (prompts, tool invocations) and real-time usage statistics with automatic refresh. Serves as a dashboard for token consumption across session, weekly, and model-specific quotas.

## Design
- **Layered architecture**: data collection (fetcher) → caching (JSON) → display (SwiftBar plugin)
- **Session tracking via JSON + log files**: `claude-session-track.sh` writes state and event history to `/tmp/claude-sessions/{session_id}.json` and `.log`; supports subagent monitoring
- **ANSI stripping pipeline**: multi-pass Perl regex in fetcher to handle cursor movement, CSI codes, and OSC sequences from Claude CLI terminal output
- **Blink-on-update signaling**: flag file `/tmp/claude-usage-blink` triggers visual feedback (⚡) for 10 seconds without additional API calls
- **Tool summarization**: `PreToolUse` events capture command, file path, query, or subagent description per tool type (Bash, Edit, WebSearch, Agent, Glob, Grep)

## Flow
1. **launchd agent** (`com.ichigo.claude-usage-fetch.plist`) runs fetcher every 180s
2. **Fetcher** (`claude-usage-fetch.sh`): spawns `claude` CLI with `/usage` command, scrapes ANSI output (percentages + reset times), writes `/tmp/claude-usage-cache.json`, touches blink flag
3. **Session tracking** (hook): `claude-session-track.sh` receives stdin JSON for `UserPromptSubmit`/`PreToolUse`/`PostToolUse`/`Stop` events, updates state file and appends to history log
4. **SwiftBar plugin** (`claude-usage.3m.sh`): reads cache + blink flag, renders icon (🟢/🟡/🔴) + percentages + reset times in menu bar; dropdown shows session history via `claude-session-view.sh`
5. **Manual viewer** (`claude-session-view.sh`): live display of a session state + last 60 events with timestamps, tool names, and summaries

## Integration
- **SwiftBar**: plugin symlinked to `~/Library/Application Support/SwiftBar/Plugins/` as `.3m.sh`; reads cache files and executes refresh commands
- **launchd**: manages background fetcher daemon; stdout redirected to `/tmp/claude-usage-fetch.log` for fallback parsing if session file missing
- **Claude Code CLI**: invoked with `--disallowedTools` flag to prevent side effects; requires installation via npm
- **Session hooks**: expects JSON stdin (from Claude Code integration) with fields like `session_id`, `tool_name`, `tool_input`, `prompt`, `cwd`; writes to shared `/tmp/claude-sessions/` directory for cross-session visibility
