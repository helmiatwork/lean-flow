# plugin/scripts/

## Responsibility

`plugin/scripts/` contains automation hooks and utilities that intercept Claude's tool execution, memory consolidation, and repository state tracking. It enforces workflow rules (branch naming, protected pushes, secret protection), compresses verbose output, auto-updates documentation, and manages session-level pattern observation.

## Design

**Hook-based interception**: Most scripts are PreToolUse/PostToolUse hooks that read stdin JSON, examine `.tool_input.command` or `.tool_response`, and emit JSON decisions (`exit 0` = allow, `exit 2` = block, `exit 1` = error). `auto-compress-output.sh` intercepts high-output commands (git log, tests, grep -r), runs them directly, and uses `claude-haiku-4-5-20251001` to summarize if output exceeds 25 lines.

**State machines**: `auto-dream.sh` gates memory consolidation with dual triggers (N sessions + N hours elapsed), uses lockfile to prevent concurrent runs, and backgrounds the process. `cartographer.py` maintains `.slim/cartography.json` with directory hashes and codemaps, supporting `init`/`changes`/`update` subcommands. `auto-observe.sh` silently writes session observations to `~/.claude/knowledge/patterns.db` from session logs.

**Pattern-based blocking**: `block-*.sh` scripts use grep regexes on command strings to enforce rules (no `--no-verify`, no direct pushes to main/master/develop, no .env staging, no Claude identity in commits). Config-driven: `LEAN_FLOW_PROTECTED_BRANCHES` loaded from `load-config.sh`.

**Python CLI tools**: `cartographer.py` and `auto-update-codemaps.py` handle heavy lifting — cartographer uses PathLib + regex PatternMatcher for efficient gitignore evaluation; auto-update-codemaps reads changed dirs from `git diff-tree`, samples files, calls Claude API via OAuth (macOS keychain fallback) to generate documentation.

## Flow

1. **PreToolUse hooks** (block-*.sh, enforce-branch-naming.sh): inspect incoming command → emit decision JSON or exit code
2. **Output compression** (auto-compress-output.sh): identify high-output Bash → run directly → compress if >25 lines → return summary JSON
3. **PostToolUse hooks** (auto-update-codemaps.sh → cartographer.py): after git commit → detect changed dirs → read file samples → call Claude API → write/update codemap.md sections
4. **Session lifecycle**: SessionStart runs `check-dependencies.sh` (audit missing tools); SessionStop triggers `auto-dream.sh` (dual-gate → spawn background consolidation); during session, `auto-observe.sh` writes pattern observations to SQLite DB
5. **Task delegation** (delegate-task-retry.sh): post-execution error pattern matching → append inline retry guidance JSON to next turn

## Integration

- **Hooks registered in** `~/.claude/settings.json` → Claude Code invokes on matching events
- **Config sourced from** `load-config.sh` → provides LEAN_FLOW_PROTECTED_BRANCHES, LEAN_FLOW_DREAM_SESSIONS, LEAN_FLOW_DREAM_HOURS
- **Memory system**: `auto-dream.sh` runs `auto-dream-prompt.md` via `claude --allowedTools`; `auto-observe.sh` writes to
