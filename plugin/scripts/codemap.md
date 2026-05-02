# plugin/scripts/

## Responsibility
`plugin/scripts/` contains pre/post-tool-use hooks and automation triggers that enforce workflow discipline, optimize Claude API usage, and manage project memory. Scripts gate dangerous operations (secret commits, protected branch pushes), compress high-volume output, auto-consolidate memory on session boundaries, and inject TDD/planning reminders during development.

## Design
**Hook pattern**: Most scripts read stdin JSON, pattern-match tool commands/responses, emit decision JSON (`exit 2` to block, `jq` output for guidance, `exit 0` to pass-through). **State management**: `auto-dream.sh` uses dual-gate counters (session count + timestamp) to trigger expensive memory ops only after N sessions AND N hours. **Tokenomics**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs, grep -r), executes locally, compresses via haiku if >25 lines. **Cartography**: `cartographer.py` maintains `.slim/cartography.json` state—tracks file hashes and dir structure to detect changes without re-scanning entire repo. **Pattern db**: `auto-observe.sh` silently logs session tool usage to `~/.claude/knowledge/patterns.db` (sqlite3) for pattern learning.

## Flow
1. **PreToolUse hooks** (`block-*.sh`, `auto-compress-output.sh`): intercept Bash/Tool calls → validate against rules → block/compress/pass-through before Claude execution
2. **PostToolUse hooks** (`enforce-tdd.sh`, `delegate-task-retry.sh`): observe tool results → inject guidance (test reminders, retry hints) via additionalContext
3. **SessionStart** (`check-dependencies.sh`): audit installed companion plugins/tools, emit single systemMessage with fixes
4. **SessionStop** (`auto-dream.sh`, `auto-observe.sh`): increment counters → if gates pass, trigger memory consolidation; silently log session patterns to db
5. **Commit hooks** (`auto-update-codemaps.py`): PostToolUse on git commit → detect changed dirs → auto-generate codemap.md sections via Claude API

## Integration
- **Settings**: hooks load `~/.claude/settings.json` and `LEAN_FLOW_*` env vars (via `load-config.sh`) for protected branches, dream frequency, TDD enforcement toggles
- **Knowledge layer**: `patterns.db` (observed via `auto-observe.sh`) feeds pattern_search MCP, integrates with `claude-monitor/` for session analytics
- **Repo structure**: `cartographer.py` watches `.slim/cartography.json` state; codemaps sit adjacent to source dirs; plans route to `~/.claude/plans/` (enforced by `block-wrong-plan-dir.sh`)
- **API tier**: `auto-update-codemaps.py` uses OAuth token from macOS keychain → falls back to `ANTHROPIC_API_KEY` env var for codemap generation; `auto-dream.sh` shells out to `claude` CLI with haiku model for memory compression
