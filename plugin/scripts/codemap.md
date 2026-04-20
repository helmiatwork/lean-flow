# plugin/scripts/

## Responsibility
Plugin scripts that enforce lean workflow patterns—blocking unsafe operations (commits without tests, direct pushes to protected branches, secrets), auto-compressing large command output, consolidating session memories, and maintaining codebase cartography (change detection + auto-generating codemap.md).

## Design
Hook-based architecture: scripts run as PreToolUse/PostToolUse hooks intercepting tool calls (Bash, Write, Edit). Each guard script (block-*.sh) makes a binary decision: allow (exit 0), block (exit 2), or ask (jq output). Compression and consolidation run asynchronously in background. Cartography uses git diff-tree to track changed directories and maintains .slim/cartography.json state. Helper scripts (load-config.sh, claude-monitor/) provide shared utilities and monitor setup.

## Flow
1. **Guard hooks** (PreToolUse): block-*.sh intercept commands, check rules (protected branches, secrets, --no-verify), emit JSON decision
2. **Compression** (PreToolUse): auto-compress-output.sh runs high-output commands directly, compresses >25 lines via haiku, returns summary
3. **Post-commit**: auto-update-codemaps.py reads git diff-tree, updates codemap.md in changed dirs via Claude API
4. **Session lifecycle**: SessionStart runs ensure-cartography.sh (Tier 1: CODEBASE_MAP.md staleness, Tier 2: per-folder changes) and ensure-claude-monitor.sh; SessionStop triggers auto-dream.sh (dual-gated: N sessions + N hours) to consolidate memory via auto-dream-prompt.md
5. **Observation**: auto-observe.sh silently logs session patterns to patterns.db

## Integration
- **Config**: load-config.sh sources LEAN_FLOW_* env vars (protected branches, dream gates, monitor toggle)
- **Cartographer**: cartographer.py (not a hook; standalone CLI) computes file hashes, detects changes, feeds Tier 2 status to ensure-cartography.sh
- **Claude monitor** (claude-monitor/): SwiftBar plugin + launchd agent for usage tracking, installed by ensure-claude-monitor.sh
- **OAuth**: auto-update-codemaps.py fetches token from macOS keychain or ANTHROPIC_API_KEY env
- **Patterns DB**: auto-observe.py writes to ~/.claude/knowledge/patterns.db (used by auto-dream.sh for cleanup)
