# scripts/

## Responsibility

Install-time and session-time utility scripts. Handles environment bootstrapping (MCP registration, permissions, plugin setup), session support (briefing, plan viewer, test failure tracking), and safety warnings. Also contains `cartographer.py` for codemap generation.

## Design

All `ensure-*.sh` scripts are idempotent — check if already configured before making changes. Scripts reference `${CLAUDE_PLUGIN_ROOT}` for portability. `plan-server.mjs` and `plan-viewer.mjs` are Node.js servers for the live plan viewer UI. `cartographer.py` scans directories and seeds empty codemap templates.

## Flow

`install.command` invokes setup scripts sequentially. On each session start, hooks trigger `ensure-*` scripts to verify dependencies are still configured. `session-briefing.sh` runs once per session to summarize git state. `remind-check-step.sh` and `track-test-failures.sh` enforce workflow discipline.

## Integration

Scripts are invoked by `hooks/hooks.json` (session hooks) and by `install.command` (one-time setup). `cartographer.py` is run standalone. Subdir `claude-monitor/` is a separate SwiftBar plugin bundled here for distribution.
