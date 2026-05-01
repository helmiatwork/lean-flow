# plugin/scripts/

## Responsibility
`plugin/scripts/` houses git hooks, session lifecycle handlers, and repository mapping tools that enforce development practices (TDD, protected branches, secret blocking), optimize token usage (output compression, memory consolidation), and maintain codebase documentation (cartography, codemaps).

## Design
- **Hook-based guards**: PreToolUse blocks (block-*.sh) intercept dangerous git commands; PostToolUse (enforce-tdd.sh, auto-update-codemaps.sh) enforce patterns after writes.
- **Dual-gate session hooks**: auto-dream.sh and auto-observe.sh use lock files + session counters + time thresholds to prevent concurrent runs and token waste.
- **Cartography tier system**: Tier 1 (docs/CODEBASE_MAP.md via git log) covers high-level changes; Tier 2 (per-folder codemap.md via cartographer.py) tracks module-level diffs.
- **Compression on demand**: auto-compress-output.sh detects high-output commands (git log, test runs, find) and summarizes via haiku before returning to Claude.

## Flow
1. **SessionStart** → ensure-cartography.sh and ensure-claude-monitor.sh check repo state, emit status messages.
2. **PreToolUse** → block-*.sh guards (secret commits, no-verify, protected branches, identity markers) reject unsafe commands with exit code 2.
3. **PreToolUse** → auto-compress-output.sh intercepts command execution, runs locally if high-output, compresses via haiku, returns summary (exit 2 blocks original).
4. **PostToolUse** → enforce-tdd.sh reminds on implementation writes; auto-update-codemaps.py updates codemap.md files in changed directories via Claude API.
5. **SessionStop** → auto-dream.sh (gated by session count + hours) triggers memory consolidation via auto-dream-prompt.md; auto-observe.sh logs session patterns to patterns.db.

## Integration
- **Cartographer**: cli tool (cartographer.py) reads/writes .slim/cartography.json state; ensure-cartography.sh invokes it on SessionStart.
- **Claude monitor** (claude-monitor/): ensure-claude-monitor.sh installs SwiftBar plugin + launchd agent for usage tracking; detects claude binary via PATH, nodenv, nvm, n.
- **Config loading**: block-protected-push.sh and auto-dream.sh source load-config.sh to read LEAN_FLOW_* environment variables.
- **API calls**: auto-update-codemaps.py uses OAuth token from macOS keychain or ANTHROPIC_API_KEY env var; auto-dream.sh invokes claude CLI via timeout wrapper.
