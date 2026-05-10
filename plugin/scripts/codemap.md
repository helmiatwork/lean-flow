# plugin/scripts/

## Responsibility
Central hook library for the Lean Flow workflow. Provides PreToolUse guards (bash-guard.sh), PostToolUse nudges (compact-nudge.js, enforce-tdd.sh), auto-update mechanisms (auto-update-codemaps.py), and memory consolidation (auto-dream.sh). Guards block unsafe git/gh commands, risky patterns, and wrong directory saves. Nudges remind about context usage and TDD discipline. Auto-mechanisms update codemaps after commits and consolidate session patterns into memory.

## Design
- **Hook hierarchy**: Each script is a single responsibility hook (PreToolUse Bash, PostToolUse Task, etc.). Hooks read JSON from stdin, optionally mutate state files, emit JSON to stdout for Claude instruction.
- **Opt-out pattern**: Most guards/nudges use `LEAN_FLOW_<CHECK>_DISABLED=true` env var to allow per-check disabling without rewriting scripts.
- **Dual-gate safety**: auto-dream.sh uses both session count AND time elapsed before running consolidation — prevents noise while ensuring eventual cleanup.
- **Pattern matching**: bash-guard.sh combines multiple blockers (no-verify, protected branches, secret files, Claude identity, PR comments) into one unified PreToolUse guard with per-check toggles.
- **Token-efficient**: auto-compress-output.sh intercepts high-output commands (git log, pytest, etc.), runs them directly, compresses via haiku if >25 lines, returns summary. Zero cost for small output.

## Flow
1. **Session start** → check-dependencies.sh audits installed plugins/tools, caches findings by hash to avoid repeat warnings.
2. **PreToolUse Bash** → bash-guard.sh validates command (--no-verify, protected branches, secrets, Claude identity). Blocks or passes through.
3. **PreToolUse Bash** (high-output) → auto-compress-output.sh intercepts git log/pytest/etc., runs directly, compresses output if >25 lines via haiku, returns summary instead of letting Claude re-run.
4. **PreToolUse Bash** (new branch) → enforce-branch-naming.sh validates `git checkout -b` matches `feature/|fix/|...` pattern.
5. **PreToolUse Bash** (PR creation) → enforce-pr-template.sh blocks `gh pr create --body ...` when a template exists; requires `--body-file`.
6. **PostToolUse Write|Edit** → enforce-tdd.sh checks if test already exists for impl file; if not, injects TDD reminder (RED/GREEN/REFACTOR).
7. **PostToolUse Task** → delegate-task-retry.sh detects common delegation errors (missing subagent_type, InputValidationError), appends inline fix hints.
8. **PostToolUse any** → compact-nudge.js reads metrics from /tmp/claude-ctx-{session_id}.json; at 30% usage, reminds user to run /compact (debounced every 10 calls).
9. **Post git commit** → auto-update-codemaps.py detects changed dirs via `git diff-tree`, reads file contents, calls Claude API to regenerate codemap.md sections.
10. **Session stop** (dual-gate: N sessions + N hours) → auto-dream.sh consolidates memory: prunes/merges patterns.db, updates memory files, runs consolid
