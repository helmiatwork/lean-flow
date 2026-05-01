# plugin/scripts/

## Responsibility

`plugin/scripts/` implements the lean-flow automation layer: pre/post-tool hooks that intercept Claude's tool use for compression, memory consolidation, validation, and cartography. Zero-overhead interventions that either fall through transparently (small outputs, no violations) or gate/redirect commands (large outputs, protected branches, secret files).

## Design

**Hook-based interception**: Each script is a stateless PreToolUse or PostToolUse handler that reads JSON stdin, decides to pass-through (exit 0), block (exit 2 + error), or ask (exit 0 + jq output). `auto-compress-output.sh` detects high-output commands and swaps Haiku summarization in-place. `block-*.sh` scripts enforce invariants (no `--no-verify`, no secrets staged, no direct main/master pushes). `auto-update-codemaps.py` calls Claude API to regenerate directory docs after commits. `cartographer.py` is a standalone file-hash tracker for change detection; `ensure-cartography.sh` and `enforce-tdd.sh` surface stale codemaps and missing tests at session start.

**Dual-gate pattern**: `auto-dream.sh` consolidates memory only after *both* N sessions *and* N hours elapsed (prevent thrashing; see `auto-dream-prompt.md` for task spec). Lock files prevent concurrent runs.

## Flow

1. **PreToolUse hooks** (auto-compress, block-*) run before tool execution; exit codes: 0=pass-through, 2=block.
2. **PostToolUse hooks** (auto-update-codemaps, enforce-tdd) run after Write/Edit; modify or annotate output.
3. **SessionStart hooks** (ensure-cartography, ensure-claude-monitor) emit system messages if state is stale.
4. **Background consolidation** (auto-dream, auto-observe): triggered on SessionStop, update `~/.claude/` memory and patterns.db without blocking the session.
5. **Cartographer** runs on-demand or via `auto-update-codemaps.py`: reads `.slim/cartography.json` hash state, detects changed dirs, triggers codemap regeneration for affected folders.

## Integration

- **Keychain + OAuth**: `auto-update-codemaps.py` fetches token from macOS keychain (or `ANTHROPIC_API_KEY` env) to call Claude API.
- **git hooks**: Scripts inspect `git diff-tree`, branch names, `.gitignore` via `cartographer.py` for change detection.
- **SwiftBar monitor**: `ensure-claude-monitor.sh` scaffolds launchd plist + SwiftBar plugin for real-time usage tracking (macOS only).
- **Config loader**: `load-config.sh` (referenced but not shown) sets `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, etc.
- **claude CLI**: Scripts invoke `claude` binary for Haiku summarization, TDD reminders, and memory consolidation (detected via PATH or keychain integration).
- **.slim/ state dir**: Cartographer writes `cartography.json` hash manifest; hooks read it to decide which codemaps are stale.
