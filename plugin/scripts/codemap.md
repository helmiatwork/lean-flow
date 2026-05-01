# plugin/scripts/

## Responsibility

`plugin/scripts/` contains lifecycle hooks and automation for lean-flow: intercepting tool calls, blocking unsafe git operations, auto-updating documentation, managing memory consolidation, and guiding task delegation. Each script runs at a specific Claude Code event (`PreToolUse`, `PostToolUse`, `SessionStart`, `SessionStop`) to enforce policy, compress output, or trigger background maintenance.

## Design

- **Hook-based event dispatch**: Scripts read JSON from stdin, pattern-match on command/tool name, emit structured JSON responses (block, ask, additionalContext, systemMessage).
- **Gate-based execution**: `auto-dream.sh` uses dual gates (N sessions + N hours) to prevent runaway consolidation; `auto-compress-output.sh` only intercepts high-output commands (git log, pytest, grep -r).
- **Token budget awareness**: `auto-compress-output.sh` uses haiku summarization for 25+ line outputs; `auto-dream-prompt.md` explicitly prunes memory when total exceeds 5000 tokens.
- **Fallback chains**: OAuth token lookup (macOS keychain → env var); Python/uv detection for cartography; lock files prevent concurrent runs.
- **Pattern → fix hints**: `delegate-task-retry.sh` maps error regex to concrete retry guidance (e.g., "missing_subagent_type" → "Add subagent_type='fixer'").

## Flow

1. **Pre-execution** (`PreToolUse`): `auto-compress-output.sh` intercepts git/test commands; `block-*.sh` scripts reject unsafe git operations, secret staging, protected branch pushes.
2. **Post-execution** (`PostToolUse`): `auto-update-codemaps.py` reads git diff-tree to find changed dirs, calls Claude API to regenerate codemap sections; `enforce-tdd.sh` reminds on implementation writes; `delegate-task-retry.sh` appends fix hints on Task errors.
3. **Session lifecycle** (`SessionStart`): `ensure-cartography.sh` checks if Tier 1 (CODEBASE_MAP.md) or Tier 2 (per-folder codemap.md) need updates. (`SessionStop`): `auto-observe.sh` silently logs session patterns to patterns.db; `auto-dream.sh` runs memory consolidation if gates pass.
4. **Background**: `cartographer.py` maintains .slim/cartography.json (file hashes, codemap state); `auto-dream-prompt.md` is fed to claude CLI with allowedTools=[Read,Write,Edit,Glob,Grep], max-turns=20, 5-min timeout.

## Integration

- Reads from: git (diff-tree, log, branch), .env/.gitignore, .slim/cartography.json, ~/.claude/dream-state, ~/..claude/knowledge/patterns.db, ~/.claude/plans/, macOS keychain (security CLI).
- Writes to: stdout/stderr (hook responses), .slim/cartography.json, ~/.claude/memory/*, patterns.db (session observations), git commits (via auto-update-codemaps).
- Calls: Claude API (via `claude` CLI in auto-dream.sh, auto-compress-output.sh; via urllib in auto-update-codemaps.py for OAuth); jq (JSON parsing/emission); sqlite3 (patterns.db).
- Triggered by: Claude Code event hooks (
