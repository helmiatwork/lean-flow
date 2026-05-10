# plugin/scripts/

## Responsibility

`plugin/scripts/` contains the hook system and automation layer for the lean-flow workflow. It implements PreToolUse/PostToolUse hooks that intercept, validate, and transform tool calls; session lifecycle automation (memory consolidation, dependency audit, change detection); and repository mapping tools. These scripts enforce workflow rules, optimize token usage, and maintain documentation synchronization.

## Design

**Hook architecture**: Bash scripts receive JSON via stdin, emit JSON to stdout, exit with status codes (0=pass, 2=block). Hooks are composable—`auto-compress-output.sh` truncates large command output via haiku summarization; `block-*.sh` scripts enforce rules (no `--no-verify`, no protected branch pushes, no secret files); `delegate-task-retry.sh` parses Task tool errors and appends inline fix hints.

**Automation gates**: `auto-dream.sh` uses dual gates (session count + elapsed time) to trigger memory consolidation asynchronously; `auto-observe.sh` logs session patterns to SQLite; `cartographer.py` maintains file hashes and codemap state in `.slim/cartography.json`.

**Documentation sync**: `auto-update-codemaps.py` (PostToolUse on git commit) detects changed directories via `git diff-tree`, reads file contents up to token budget, calls Claude API to generate codemap sections, and writes back to `codemap.md` files.

## Flow

1. **Tool invocation** → PreToolUse hooks (block-*.sh, auto-compress-output.sh, enforce-branch-naming.sh) validate/transform command, exit 0 (pass) or 2 (block)
2. **Tool execution** → tool runs (or `auto-compress-output.sh` intercepts high-output commands, runs directly, compresses via haiku, exits 2 to skip model execution)
3. **Tool completion** → PostToolUse hooks (delegate-task-retry.sh, auto-update-codemaps.sh) parse results, append guidance or update docs
4. **Session end** → `auto-dream.sh` checks dual gates, spawns background process to consolidate memory via `auto-dream-prompt.md`; `auto-observe.sh` silently logs session activity to patterns.db
5. **Repository change** → `cartographer.py` tracks file hashes, `auto-update-codemaps.py` regenerates codemaps for affected directories

## Integration

- **Settings**: `load-config.sh` (referenced in auto-dream.sh, block-protected-push.sh, check-dependencies.sh) supplies LEAN_FLOW_* environment variables
- **Memory**: `auto-dream.sh` reads/writes to `~/.claude/dream-state/`; `auto-observe.sh` writes to `~/.claude/knowledge/patterns.db`
- **Git hooks**: Scripts are wired as PreToolUse/PostToolUse matchers in `~/.claude/settings.json`; cartographer state lives in `.slim/cartography.json`
- **API**: `auto-update-codemaps.py` fetches OAuth token from macOS keychain or `ANTHROPIC_API_KEY` env var, calls Claude API with SYSTEM_PROMPT
- **project-doctor/**: Sibling directory contains diagnosis/repair tools (referenced in check-dependencies.sh as companion utilities)
