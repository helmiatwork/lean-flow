# scripts/claude-monitor/

## Responsibility

SwiftBar plugin for monitoring Claude API usage (session %, weekly %) in the macOS menu bar. Bundled within lean-flow so `ensure-claude-monitor.sh` can deploy it automatically during install.

## Design

Two-script split: `claude-usage-fetch.sh` drives the `claude` CLI through a TTY emulation to capture `/usage` output and writes JSON to `/tmp/claude-usage-cache.json`. `claude-usage.3m.sh` is the SwiftBar display script that reads the cache and emits menu-bar text with refresh/interval controls.

## Flow

SwiftBar triggers the display script every 3 minutes. If cache is stale, it spawns the fetcher in background. Fetcher acquires a lock, sends keystrokes to the CLI, parses the response, and updates the cache file. Display script re-reads cache on next trigger.

## Integration

Deployed by `ensure-claude-monitor.sh` to the SwiftBar plugins directory. Depends on SwiftBar, the `claude` CLI, and `jq`. This is the source for the standalone `claude-usage-monitor` repo — kept in sync manually.
