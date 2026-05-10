# plugin/scripts/

## Responsibility

`plugin/scripts/` contains the hook ecosystem that enforces workflow guardrails, automates codemap updates, consolidates memory, and provides real-time feedback on command safety and code quality. These scripts run as PreToolUse/PostToolUse/SessionStart/SessionStop hooks injected into Claude's execution pipeline.

## Design

- **Guard pattern**: Bash hooks (bash-guard.sh, enforce-*.sh, block-*.sh) intercept commands early, validate against rules (branch naming, PR templates, protected branches, secret files), and exit with decision JSON to block or allow.
- **Output compression**: auto-compress-output.sh detects high-output commands (git log, test runs, grep -r), executes them directly, and summarizes via haiku when >25 lines—zero cost for small output.
- **Async background jobs**: auto-dream.sh and auto-observe.sh run as fire-and-forget after session stop/start, using dual gates (session count + elapsed time) to prevent over-consolidation.
- **Pattern-driven retry**: delegate-task-retry.sh pattern-matches Task tool errors and emits inline fix hints keyed to common failures (missing subagent_type, validation errors, rate limits).
- **File watching + codemap generation**: auto-update-codemaps.py/sh reads git diff-tree post-commit, identifies changed directories, reads their file contents, and calls Claude API to auto-fill codemap.md sections.

## Flow

1. **PreToolUse hooks** (bash-guard.sh, enforce-*.sh, block-*.sh): stdin → tool command validation → exit code 2 (block) or pass-through with decision JSON.
2. **Tool execution**: Claude runs the validated command directly.
3. **PostToolUse hooks** (auto-compress-output.sh, compact-nudge.js, delegate-task-retry.sh, enforce-tdd.sh): stdin → output analysis → emit additionalContext guidance or decision JSON → Claude sees context on next turn.
4. **SessionStop**: auto-observe.sh + auto-dream.sh run async in background — log session events to patterns.db, check dual gates (sessions + hours), trigger memory consolidation via claude CLI if gates pass.
5. **Git commit**: auto-update-codemaps.sh (PostToolUse on Bash) → calls cartographer.py → runs auto-update-codemaps.py → git diff-tree → Claude API to fill codemap sections.

## Integration

- **Settings**: Load config via `load-config.sh` for LEAN_FLOW_* env vars (dream thresholds, disabled checks, protected branches).
- **Keychain + OAuth**: auto-update-codemaps.py reads token from macOS keychain or ANTHROPIC_API_KEY fallback.
- **Memory/patterns**: auto-observe.sh + auto-dream.sh read/write `~/.claude/knowledge/patterns.db`, `~/.claude/projects/*/memory/`.
- **Output distillers**: auto-compress-output.sh chains to claude CLI with haiku model for summarization; cartographer.py used by codemap updates for state tracking (.slim/cartography.json).
- **Sibling hooks**: bash-guard.sh combines multiple blockers (git security, branch protection, secret files, Claude identity rules); enforce-tdd.sh pairs with write tool results to inject test reminders.
