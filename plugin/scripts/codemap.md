# plugin/scripts/

## Responsibility
Houses the lean-flow automation hooks and utilities that intercept Claude's tool calls, enforce workflow rules, and maintain codebase documentation. Spans session lifecycle (startup checks via `ensure-*`, runtime guards via PreToolUse/PostToolUse hooks, memory consolidation via auto-dream).

## Design
**Hook-based architecture**: Each script is a bash/Python/Node hook triggered by Claude Code's lifecycle events (SessionStart, PreToolUse, PostToolUse). No central dispatcher—Claude routes to them via settings.json.

**Layered checks**: bash-guard.sh unifies multiple git/gh blockers (--no-verify, protected branches, secret files, Claude identity). delegate-task-retry.sh patterns match Task errors to specific fix hints. enforce-tdd.sh detects implementation-without-test.

**Token-conscious design**: auto-compress-output.sh intercepts high-output commands (git log, grep -r, test suites), executes them directly, and returns haiku-compressed summaries instead of raw output. compact-nudge.js reads context metrics from a bridge file and debounces reminders.

**Cartography (state management)**: cartographer.py and auto-update-codemaps.py maintain directory hashes and auto-generate/update codemap.md files after commits. Dual-track: Tier 1 (docs/CODEBASE_MAP.md via git log), Tier 2 (per-folder codemaps via change detection).

## Flow
1. **SessionStart**: ensure-cartography.sh checks if codemaps are stale; check-dependencies.sh audits plugins (REQUIRED/RECOMMENDED/DEPRECATED). auto-observe.sh silently logs session activity to patterns.db.
2. **PreToolUse (Bash)**: bash-guard.sh blocks unsafe git/gh commands (--no-verify, protected branch push, secret file staging, Claude identity in commits). enforce-branch-naming.sh validates new branch names. enforce-pr-template.sh forces template usage.
3. **PreToolUse (any)**: auto-compress-output.sh intercepts commands like `git log`, runs them, and returns compressed output if >25 lines.
4. **PostToolUse**: auto-update-codemaps.py reads git diff-tree, identifies changed directories, calls Claude API to generate codemap.md sections. compact-nudge.js checks context usage and emits reminders at 30%. enforce-tdd.sh nudges test creation after implementation writes. delegate-task-retry.sh pattern-matches Task errors and suggests fixes.
5. **SessionStop** (dual-gated): auto-dream.sh runs memory consolidation (N sessions AND N hours elapsed), cleans up MEMORY.md, prunes patterns.db.

## Integration
- **settings.json hooks**: Each script is registered as a hook trigger (event + matcher + command path).
- **keychain/env**: auto-update-codemaps.py reads OAuth token from macOS keychain or ANTHROPIC_API_KEY.
- **Git repo metadata**: bash-guard.sh, cartographer.py, ensure-cartography.sh all call `git rev-parse` and `git diff-tree` for state.
- **Temp bridge files**: compact-nudge.js reads /tmp/claude-ctx-{session_id}.json (written by statusline integration) for context metrics.
- **Filesystem state**: .slim/cartography.json, ~/.claude/dream-state/, ~/.claude
