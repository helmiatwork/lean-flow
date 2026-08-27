# plugin/scripts/

## Responsibility

`plugin/scripts/` contains the hook system backbone — PreToolUse blockers, PostToolUse nudges, and session lifecycle automation. These scripts enforce workflow rules (git hygiene, branch naming, PR templates, TDD), compress large command output, auto-update codemaps on commits, consolidate memory on session stop, and provide just-in-time dependency auditing.

## Design

**Hook pattern**: Each script reads JSON from stdin, applies a condition (regex on command, tool name, or file path), and outputs JSON or exits with status 0 (pass) / 2 (block). Hooks are opt-outable via `LEAN_FLOW_*_DISABLED=true` env vars.

**Key abstractions**:
- `bash-guard.sh` — unified Bash gate combining six discrete checks (no-verify, no-gpg-sign, protected branch, secret files, Claude identity, PR comments)
- `auto-compress-output.sh` — PreToolUse: intercepts high-output commands (git log, grep -r, test runs), runs them directly, haiku-summarizes if >25 lines
- `cartographer.py` / `auto-update-codemaps.py` — post-commit codemap regeneration via git diff-tree → file collection → Claude API
- `auto-dream.sh` + `auto-dream-prompt.md` — dual-gated memory consolidation (N sessions AND N hours since last consolidation)
- `delegate-task-retry.sh` — Task tool error recovery: regex-matches failure patterns, emits fix hints for next turn

## Flow

**PreToolUse (blocking layer)**:
1. Hook receives command via stdin JSON
2. Pattern match against blocklist (bash-guard: --no-verify, protected branches; enforce-branch-naming: invalid branch names; enforce-pr-template: ad-hoc body without template)
3. Exit 0 (pass stdin through) or exit 2 (block + error message)

**PostToolUse (correction/nudging layer)**:
1. Tool response received with exit code + output
2. auto-compress-output: if output >25 lines and command is high-output type, haiku-summarize and emit compressed version
3. delegate-task-retry: Task errors pattern-matched → fix hints appended to model context
4. enforce-tdd: implementation file written without test → TDD reminder injected
5. compact-nudge: context usage ≥30% → /compact reminder (debounced every 10 tool calls)

**SessionStart/Stop**:
- `check-dependencies.sh`: runs after bootstrap, audits superpowers plugin, jq, omni, gitnexus, knowledge-mcp; caches findings by hash to avoid spam
- `auto-dream.sh`: on SessionStop, dual-gates: fires only if ≥N sessions *and* ≥N hours since last consolidation; locks to prevent concurrency; runs `auto-dream-prompt.md` against memory files
- `auto-observe.sh`: silent post-stop observation capture — parses session log, extracts tool patterns, writes compressed observations to ~/.gemini/knowledge/patterns.db

**Repository mapping**:
- `cartographer.py`: manages `.slim/cartography.json` (file hashes, timestamps, codemap tracking)
- `auto-update-codemaps.py`: triggers on PostToolUse after `git commit`, reads changed dirs via `git diff-tree`, coll
