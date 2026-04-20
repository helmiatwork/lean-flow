# plugin/scripts/

## Responsibility
Contains lifecycle hooks (PreToolUse, PostToolUse, SessionStart/Stop) and utilities that enforce workflow rules, optimize Claude's output, and maintain codebase documentation. These scripts gate dangerous operations, compress large outputs, consolidate memory, and auto-generate/update codemaps.

## Design
- **Hook scripts** (block-*.sh, auto-*.sh, ensure-*.sh) are small, composable, exit-code-driven filters that either allow (exit 0), ask (exit 1), or block (exit 2) tool invocations or prompt context
- **Cartographer.py** is a standalone state machine (init/changes/update) that tracks file hashes in `.slim/cartography.json` and detects which directories have changed code
- **Config inheritance** via `load-config.sh` sets gating thresholds (dream sessions, protected branches, monitor enabled flag)
- **Token-aware compression**: auto-compress-output.sh runs commands directly, measures output size, and uses Haiku to summarize large results before returning to Claude

## Flow
1. **PreToolUse** (tool about to run): block-*.sh filters validate command safety; auto-compress-output.sh pre-executes read-heavy commands and returns compressed summaries
2. **PostToolUse** (tool completed): auto-update-codemaps.py reads git diff, identifies changed dirs, calls Claude API to fill codemap.md sections; enforce-tdd.sh reminds about missing tests
3. **SessionStart**: ensure-cartography.sh checks Tier 1 (docs/CODEBASE_MAP.md commit age) and Tier 2 (per-folder .slim/cartography.json changes); ensure-claude-monitor.sh installs SwiftBar usage tracker
4. **SessionStop**: auto-observe.sh records tool usage to patterns.db; auto-dream.sh consolidates memory after N sessions + N hours via haiku-summarized memory pruning

## Integration
- **Cartographer.py**: called by auto-update-codemaps.py (PostToolUse) and ensure-cartography.sh (SessionStart) to detect changed directories; reads `.slim/cartography.json` state file and `.gitignore` patterns
- **Config**: all threshold-gated scripts source `load-config.sh` for LEAN_FLOW_* environment variables (dream gates, protected branches, monitor toggle)
- **Claude monitor** (claude-monitor/ subdirectory): ensure-claude-monitor.sh deploys SwiftBar plugin + launchd fetcher for real-time token usage on macOS
- **Knowledge DB**: auto-observe.py and auto-dream.sh both read/write `~/.claude/knowledge/patterns.db` to learn from sessions and consolidate memory
