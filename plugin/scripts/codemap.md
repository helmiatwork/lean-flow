# plugin/scripts/

# plugin/scripts/ Codemap

## Responsibility
Hooks and automations that enforce workflow rules, compress output, consolidate memory, and detect dependency issues at session boundaries and tool invocations. Acts as the enforcement layer between Claude's actions and the repo/knowledge system.

## Design
- **Hook-based intercepts**: PreToolUse (block/compress), PostToolUse (guidance/retry), SessionStart (audit), SessionStop (consolidate)
- **Dual-gate patterns**: `auto-dream.sh` uses session count + time elapsed; `auto-observe.sh` silently logs to patterns.db
- **Pattern matching on command strings**: Bash hooks (block-*.sh) grep git/push/commit commands from jq-parsed tool_input
- **Fallback chains**: `auto-update-codemaps.py` tries OAuth keychain first, then `ANTHROPIC_API_KEY` env var; `cartographer.py` uses pre-compiled regex for gitignore matching
- **Zero-token output compression**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs), runs them locally, calls haiku to compress if >25 lines, returns summary via hook exit code 2

## Flow
1. **PreToolUse hooks** (block-*.sh, auto-compress-output.sh): intercept command before execution; return 2 to compress, 0 to deny, else pass through
2. **PostToolUse hooks** (enforce-tdd.sh, delegate-task-retry.sh, auto-update-codemaps.sh): analyze tool response, append additionalContext guidance or trigger codemap update on git commit
3. **SessionStart** (check-dependencies.sh): audit installed plugins/MCPs, emit actionable system message if REQUIRED deps missing
4. **SessionStop** (auto-dream.sh): if both session count and hours thresholds met, spawn background consolidation task via haiku with memory cleanup prompt
5. **Background observation** (auto-observe.sh): parses session log into patterns.db using sqlite3, tags by tool/repo/branch

## Integration
- **CLI tools**: jq (parse hook input/settings), git (diff-tree, branch, log), python3 (pattern matching, sqlite3 writes), claude CLI (haiku model for compression/consolidation)
- **Config source**: `load-config.sh` supplies LEAN_FLOW_* env vars (protected branches, dream thresholds)
- **Knowledge backend**: writes to `~/.claude/knowledge/patterns.db` and `~/.claude/dream-state/` lock/counters
- **Codemap updates**: `auto-update-codemaps.py` reads repo dirs changed in HEAD commit, calls Claude API to generate/update codemap.md sections
- **Cartographer**: standalone tool for init/track/update workflow on structured file sets (pre-computed hashes, .slim state dir)
