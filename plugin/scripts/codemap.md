# plugin/scripts/

## Responsibility

`plugin/scripts/` contains hook handlers and daemon processes that inject lean-flow guardrails, memory consolidation, and output optimization into Claude Code sessions. These scripts intercept tool calls (PreToolUse/PostToolUse), block unsafe operations, compress verbose output, update documentation, and manage long-term memory via background consolidation.

## Design

- **Hook-based interception**: Each block-*.sh and auto-*.sh script is registered as a SessionStart/PreToolUse/PostToolUse hook that receives JSON stdin and emits JSON stdout to permit/deny/modify operations.
- **Dual-gate pattern**: `auto-dream.sh` uses session count + time elapsed to trigger memory consolidation only when both thresholds are met, preventing token waste on frequent consolidations.
- **Zero-cost fallthrough**: `auto-compress-output.sh` exits immediately for small outputs (< 25 lines), allowing normal execution to proceed; only intercepts large command outputs (git log, test runs, grep -r) and summarizes via Haiku.
- **Cartography state machine**: `cartographer.py` maintains `.slim/cartography.json` tracking file hashes and codemap freshness; enables `init` (create state), `changes` (detect diffs), `update` (commit state) workflow.
- **Pattern database backend**: `auto-observe.sh` and memory consolidation write session observations to `~/.claude/knowledge/patterns.db` (SQLite); provides long-term pattern storage for future context retrieval.

## Flow

1. **Session lifecycle**: SessionStart → dependency check (`check-dependencies.sh`) → run bootstrap hooks
2. **Tool interception**: PreToolUse → run block-*.sh (git commit, push, staging checks) + `auto-compress-output.sh` (intercept high-output commands)
3. **Post-execution**: PostToolUse → `auto-update-codemaps.py` (on git commit, update changed dirs' codemap.md), `enforce-tdd.sh` (reminder if test missing), `delegate-task-retry.sh` (retry guidance on Task tool failure)
4. **Observation**: `auto-observe.sh` reads session log at session end, extracts tool/command patterns, writes to patterns.db
5. **Memory consolidation**: After N sessions + N hours, `auto-dream.sh` spawns background Haiku task that reads patterns.db + memory files, prunes duplicates, merges patterns, updates `~/.claude/memory/MEMORY.md`

## Integration

- **Settings**: Reads `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS` from `load-config.sh` (sourced by each script)
- **API**: `auto-update-codemaps.py` calls Claude API (OAuth token from macOS keychain or `ANTHROPIC_API_KEY` env var) to fill codemap sections
- **Git hooks**: Scripts assume git repo context; use `git diff-tree`, `git branch`, `git rev-parse` for repo state
- **Knowledge layer**: Pattern database at `~/.claude/knowledge/patterns.db` (created by separate ensure-knowledge-mcp.sh); scripts read/write observations and pruning results
- **File system**: Writes state to `~/.claude/dream-state/`, `~/.claude/plans/`, `.slim/cartography.json`; reads
