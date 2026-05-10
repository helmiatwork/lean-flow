# plugin/scripts/

## Responsibility
Automation hooks and utilities for the Claude plugin ecosystem. Includes PreToolUse/PostToolUse interceptors (compress output, block unsafe git operations, auto-update codemaps), memory consolidation (auto-dream), session observation (patterns.db), and repository mapping (cartographer). All scripts are opt-outable via environment flags.

## Design
**Hook pattern**: Most scripts read JSON from stdin, validate command/input, output JSON to stdout or exit with code 2 (block). **Guard consolidation**: `bash-guard.sh` unifies all git/gh blockers into one script with per-check `LEAN_FLOW_*_CHECK_DISABLED` flags. **Token budgeting**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs), runs them directly, compresses via Haiku if output exceeds 25 lines. **Dual-gating**: `auto-dream.sh` runs memory consolidation only after N sessions AND N hours elapsed. **File hashing**: `cartographer.py` uses `.slim/cartography.json` to track directory state changes without API calls.

## Flow
1. **PreToolUse hooks** (bash-guard, block-* scripts, auto-compress-output): intercept Bash commands before execution
2. **PostToolUse hooks** (auto-update-codemaps): fire after git commit, read `git diff-tree HEAD`, call Claude API for each changed directory
3. **Background tasks** (auto-dream on session stop, auto-observe logs to patterns.db): triggered by session lifecycle, write to `~/.claude/` directories
4. **Repository mapping** (cartographer): init creates hash baseline, changes compares current state, update persists new hashes

## Integration
- **With plugin core**: hooks read `CLAUDE_PLUGIN_ROOT`, config via `load-config.sh` (sets `LEAN_FLOW_*` variables)
- **With CLI**: auto-compress-output uses `claude` binary for Haiku summarization; auto-dream/auto-update-codemaps use Claude API (OAuth from macOS keychain or `ANTHROPIC_API_KEY`)
- **With git/gh**: all guard scripts parse command strings, block unsafe patterns (--no-verify, protected branches, secret files, Claude identity)
- **With knowledge system**: auto-observe writes to `~/.claude/knowledge/patterns.db`; auto-dream reads/prunes memory files in `~/.claude/projects/`
