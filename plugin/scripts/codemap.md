# plugin/scripts/

## Responsibility
Automation hooks and utilities that intercept Claude tool use, validate commands, optimize outputs, and consolidate project memory. This directory implements PreToolUse/PostToolUse gate checks (git safety, secret blocking, protected branches), output compression for high-volume commands, session observation for pattern learning, and codemap auto-generation after commits.

## Design
- **Modular gate checks**: Individual `block-*.sh` scripts implement single concerns (no-verify, branch delete, PR comments, secrets, identity), unified by `bash-guard.sh` with opt-out env vars (`LEAN_FLOW_*_DISABLED`)
- **Tiered execution**: PreToolUse blocks run synchronously (exit 2 to reject); PostToolUse updates (auto-update-codemaps.py) run async via git hooks; memory consolidation (auto-dream.sh) dual-gates on session count + elapsed time to batch work
- **Output optimization**: `auto-compress-output.sh` intercepts high-volume commands (git log, test runs, recursion), executes directly, compresses via Haiku API only if >25 lines, returns summary or truncated output
- **Repository cartography**: `cartographer.py` tracks file hashes in `.slim/cartography.json`, diffs against current state for change detection, feeds into codemap updates without re-reading unchanged files

## Flow
1. **Pre-execution validation** (PreToolUse): bash-guard.sh reads command from stdin, applies 7 gate checks (no-verify, no-gpg-sign, protected branches, secrets, Claude identity, PR comments, branch delete), exits 2 to block or passes through
2. **Command execution optimization**: auto-compress-output.sh intercepts eligible high-output commands, runs them directly, calls Haiku to summarize if output >25 lines, returns compressed result to avoid token waste
3. **Session observation** (background): auto-observe.sh parses session log, counts tool usage, stores observations in patterns.db for future context
4. **Memory consolidation** (async): auto-dream.sh triggers after N sessions AND N hours, reads MEMORY.md and patterns.db, calls Claude with auto-dream-prompt.md to prune, merge, and optimize
5. **Post-commit codemap updates** (async): auto-update-codemaps.sh runs PostToolUse, calls Python to extract changed dirs via git diff-tree, reads file contents, calls API to regenerate codemap.md sections

## Integration
- **Hook entry points**: Scripts invoked via `.git/hooks/pre-commit`, Pre/PostToolUse plugin events, session stop; configured via CLAUDE_PLUGIN_ROOT and load-config.sh
- **State files**: `~/.claude/dream-state/` (session counts, last-dream timestamp, lock file), `.slim/cartography.json` (file hashes), `~/.claude/knowledge/patterns.db` (learned patterns)
- **External deps**: Claude API (Haiku for compression, main model for codemap/consolidation), git (diff-tree, rev-parse), jq (JSON parsing), Python 3 (cartographer, pattern DB, auto-dream)
- **Keychain integration**: auto-update-codemaps.py reads OAuth token from macOS keychain (Claude Code-credentials) or ANTHROPIC_API_KEY env var
