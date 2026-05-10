# plugin/scripts/

## Responsibility

The `plugin/scripts/` directory implements the lean-flow automation layer — a suite of PreToolUse, PostToolUse, and SessionStart hooks that enforce workflow discipline, compress token overhead, and maintain codebase cartography. It bridges Claude's tool execution with repository governance (branch protection, TDD enforcement, PR templates), output optimization (haiku summarization, session observation), and documentation sync (auto-update codemaps after commits).

## Design

**Hook-based interception**: Each script targets a specific event (PreToolUse Bash blocks `--no-verify`, PostToolUse Write triggers TDD reminders, SessionStart runs cartography checks). Scripts are idempotent, silent on success, and use JSON for structured output to the Claude API.

**Dual-gating patterns**: `auto-dream.sh` consolidates memory only after N sessions *and* N hours have elapsed; `compact-nudge.js` debounces across multiple tool uses; cartographer uses commit hash tracking to detect stale documentation.

**Zero-token operations**: `auto-observe.sh` and `auto-compress-output.sh` run client-side (no API call), passively logging patterns or intercepting high-output commands before Claude sees them. `bash-guard.sh` blocks dangerous git operations early, preventing wasted turns.

**Pattern matching and regex compilations**: `cartographer.py` pre-compiles glob-to-regex converters for .gitignore; `delegate-task-retry.sh` maintains a pattern table mapping error signatures to fix hints.

## Flow

1. **SessionStart** → `ensure-cartography.sh` detects stale Tier 1/2 maps; `check-dependencies.sh` audits required/recommended plugins.
2. **PreToolUse (Bash)** → `bash-guard.sh` blocks `--no-verify`, protected-branch pushes, secret files; `enforce-branch-naming.sh` validates new branch names; `enforce-pr-template.sh` requires `--body-file` if template exists; `enforce-tdd.sh` checks for test files.
3. **PreToolUse (any)** → `auto-compress-output.sh` intercepts high-output commands (git log, pytest, grep -r), runs them client-side, summarizes via haiku, blocks original call.
4. **PostToolUse (Write/Edit)** → `enforce-tdd.sh` injects TDD reminder if implementation file written without test.
5. **PostToolUse (Task)** → `delegate-task-retry.sh` matches error patterns, appends fix hints for re-delegation.
6. **PostToolUse (any)** → `compact-nudge.js` reminds user to run `/compact` when context crosses 30%.
7. **SessionStop** → `auto-observe.sh` logs session patterns to `~/.claude/knowledge/patterns.db`; `auto-dream.sh` (after N sessions + N hours) triggers `auto-dream-prompt.md` for memory consolidation.
8. **Post-commit** → `auto-update-codemaps.sh` (PostToolUse wrapper) calls `auto-update-codemaps.py` to refresh affected directory codemaps via Claude API.

## Integration

- **Config**: `load-config.sh` (sourced by hooks) supplies `LEAN_FLOW_*` env vars (dream thresholds, disabled checks).
- **Cartographer**: `cartographer.
