# plugin/scripts/

# plugin/scripts/ Codemap

## Responsibility
Implements the lean-flow automation layer: pre/post-tool hooks that intercept Claude's tool calls for compression, blocking, routing, and memory consolidation. Provides guard rails (block secret commits, protected branches, Claude identity markers), output optimization (auto-compress large command output), and background memory cleanup (auto-dream).

## Design
**Hook-based interceptors**: Each script is a single-responsibility hook (PreToolUse or PostToolUse) that reads JSON stdin, pattern-matches on commands/files, and emits allow/block/transform decisions via JSON stdout or exit codes.

**Dual-gated consolidation** (auto-dream.sh): Memory cleanup runs only after N sessions AND N hours elapsed — prevents thrashing while ensuring regular optimization.

**Pattern-to-fix mapping** (delegate-task-retry.sh): Regex table of common Task failures paired with concrete retry hints; matched error surfaces guidance for the next turn instead of silent failure.

**OAuth + fallback** (auto-update-codemaps.py): Reads API token from macOS keychain first, falls back to env var; git diff-tree identifies changed directories, Claude fills codemap.md sections.

## Flow
1. **Git hooks** (block-*.sh): Intercept `git commit`, `git push`, `git add` — block secrets, protected branches, Claude attribution
2. **Tool pre-flight** (auto-compress-output.sh, auto-observe.sh): Before executing high-output commands (git log, grep -r, test suites), either compress via haiku or silently log patterns to knowledge DB
3. **Post-execution** (enforce-tdd.sh, delegate-task-retry.sh): After Write/Edit/Task tools, inject TDD reminders or retry guidance
4. **Consolidation** (auto-dream.sh → auto-dream-prompt.md): On session stop, if gates passed, spawn background haiku-powered memory cleanup
5. **Codemap updates** (auto-update-codemaps.py): PostToolUse after git commit — reads changed dirs, generates concise directory descriptions

## Integration
- **Settings**: Reads `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS` from load-config.sh
- **Knowledge base**: auto-observe.sh writes observations to `~/.claude/knowledge/patterns.db`; auto-dream.sh reads/prunes it
- **Memory system**: auto-dream-prompt.md instructs Claude to consolidate `~/.claude/projects/*/memory/MEMORY.md`
- **Cartographer**: cartographer.py pairs with auto-update-codemaps.py for directory mapping and change detection
- **Dependencies**: check-dependencies.sh audits required companions (superpowers, jq, omni, gitnexus, rtk) on SessionStart
- **Token budget**: All hooks designed as zero-cost pass-throughs for normal cases; compressions only trigger on large output
