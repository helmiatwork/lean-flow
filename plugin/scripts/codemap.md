# plugin/scripts/

# plugin/scripts/ Codemap

## Responsibility
Hook system for workflow enforcement and automation. Intercepts tool calls (PreToolUse/PostToolUse), git operations, and session lifecycle events to apply guardrails (block unsafe patterns), auto-optimize (compress output, update codemaps), and collect observability (session patterns). Dual-layer: blocking hooks exit with code 2; guidance hooks emit JSON with `.hookSpecificOutput` for in-turn feedback.

## Design
**Hook multiplexing**: Each script is a focused single-concern validator/transformer on a specific event (e.g., `block-protected-push.sh` on git push, `enforce-tdd.sh` on Write/Edit, `auto-dream.sh` on SessionStop). **Config loading**: Common settings (`LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`) sourced from `load-config.sh`. **Stateful gates**: `auto-dream.sh` uses dual-gate (session count + elapsed hours) with lockfile to prevent concurrent memory consolidations. **Token optimization**: `auto-compress-output.sh` runs high-output commands directly (bash, git log, test runners) and substitutes haiku summaries for large output. **Cartography**: `cartographer.py` maintains `.slim/cartography.json` hash state of source files and codemaps for change detection without tree walking.

## Flow
**PreToolUse hooks** (block/compress layer):
- `block-*.sh` scripts inspect `jq .tool_input.command` and exit 2 to deny unsafe patterns (no-verify, protected branch push, secret files, Claude identity in commits).
- `auto-compress-output.sh` detects high-output commands, runs them directly, substitutes haiku summaries if >25 lines, returns code 2 to prevent duplicate execution.

**PostToolUse hooks** (guidance/retry layer):
- `enforce-tdd.sh` reminds on Write/Edit of implementation files without tests; emits TDD phase guidance.
- `delegate-task-retry.sh` parses Task tool failures, pattern-matches error messages, appends concrete retry hints (missing parameters, rate limits, agent types).
- `auto-update-codemaps.py` (invoked by `.sh` wrapper) runs post-commit: reads `git diff-tree HEAD`, discovers changed directories, calls Claude API to fill/update `codemap.md` sections.

**SessionStart/Stop hooks**:
- `check-dependencies.sh` audits REQUIRED (superpowers, jq) and RECOMMENDED (omni, gitnexus, rtk) companion tools; emits actionable install guidance.
- `auto-observe.sh` captures session log into patterns DB on SessionStop (repo name, branch, tool counts, key commands, duration).
- `auto-dream.sh` dual-gates on session count + elapsed hours; triggers memory consolidation via `auto-dream-prompt.md` prompt routed to Haiku model.

## Integration
- **OAuth fallback chain**: `auto-update-codemaps.py` reads token from macOS keychain (`security find-generic-password`) or `ANTHROPIC_API_KEY` env var.
- **Config**: all scripts source `load-config.sh` for runtime settings; scripts assume `CLAUDE_PLUGIN_ROOT` env var points to plugin root.
- **Git hooks integration**: block/compress scripts are wired as PreToolUse mat
