# plugin/scripts/

# Codemap: `plugin/scripts/`

## Responsibility
Automated hooks and background jobs that enforce development practices, optimize Claude's memory/output, and maintain codebase documentation. Zero-cost interceptors (PreToolUse), post-commit handlers (PostToolUse), and session lifecycle tasks (SessionStart/Stop).

## Design
**Hook-based architecture**: Each script is a standalone PreToolUse/PostToolUse/Session hook that reads stdin (JSON tool event), makes a binary decision (allow/block/compress/update), and writes to stdout. No shared state except filesystem (dream-state, patterns.db, .slim cartography). 
- **Dual-gating pattern** (auto-dream.sh): session count + time elapsed before expensive operation
- **Haiku compression** (auto-compress-output.sh): identify high-output commands, run them directly, summarize via Claude Haiku if >25 lines
- **Pattern matching** (cartographer.py): pre-compiled regex for efficient gitignore + glob matching
- **Idempotent installation** (ensure-*.sh): check already-installed, install only once

## Flow
1. **PreToolUse** hooks (block-*.sh, auto-compress-output.sh) intercept commands before execution — validate (secret files, protected branches, identity markers), compress large output, or reject
2. **PostToolUse** hooks (auto-update-codemaps.sh, enforce-tdd.sh) trigger after Write/Edit — update codemap.md via Python API call, inject TDD reminders
3. **SessionStart** hooks (ensure-cartography.sh, ensure-claude-monitor.sh) check preconditions idempotently — initialize cartographer state, warn if Tier 1/2 maps stale, install SwiftBar monitor
4. **SessionStop** hook (auto-dream.sh, auto-observe.sh) fires on session end — dual-gate memory consolidation (N sessions + N hours), capture patterns.db observations from logs
5. **auto-update-codemaps.py** reads git diff-tree, collects files per changed dir, calls Claude API with SYSTEM_PROMPT to generate 2–5 bullet points per codemap.md

## Integration
- **Git hooks context**: embedded as PreToolUse/PostToolUse in lean-flow plugin hook system; reads/writes git state via subprocess (git log, diff-tree, rev-parse)
- **Claude API**: auto-update-codemaps.py and auto-dream.sh call Claude API (Haiku/standard models); OAuth token from macOS keychain → ANTHROPIC_API_KEY fallback
- **Filesystem state**: dream-state dir (~/.claude/dream-state), patterns.db (~/.claude/knowledge), .slim/cartography.json (per-repo), config via load-config.sh
- **SwiftBar monitor**: ensure-claude-monitor.sh installs fetcher + launchd agent + SwiftBar plugin; claude-monitor/ subdirectory contains fetcher and 3m refresh UI
- **User workspace**: plans must go to ~/.claude/plans/ (block-wrong-plan-dir.sh enforces); codemaps update in-repo under docs/CODEBASE_MAP.md + per-folder codemap.md files
