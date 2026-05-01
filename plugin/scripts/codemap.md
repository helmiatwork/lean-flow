# plugin/scripts/

## Responsibility

`plugin/scripts/` contains git hooks, session lifecycle handlers, and automation scripts that enforce workflows, capture telemetry, and maintain documentation. These scripts run at key moments (PreToolUse, PostToolUse, SessionStart/Stop) to gate risky operations, compress large outputs, update codemaps, and consolidate memory without blocking the main flow.

## Design

- **Hook-based interception**: Scripts parse stdin JSON from Claude Code's hook system and either block (exit 2), ask permission (jq output), or augment context (additionalContext field)
- **Lightweight guards**: Bash-first for gate checks (block-*.sh); Python for heavy lifting (auto-update-codemaps.py, cartographer.py)
- **Dual-gate patterns**: auto-dream.sh uses session count + elapsed time; auto-compress-output.sh checks line count before invoking Haiku
- **Token efficiency**: auto-observe.sh and auto-compress-output.sh run silently or use cheaper models; delegate-task-retry.sh injects fix hints instead of re-running
- **Cartography system**: Hybrid tier approach — Tier 1 (docs/CODEBASE_MAP.md via git log), Tier 2 (per-folder codemap.md via cartographer.py file hashing)

## Flow

1. **SessionStart** → ensure-cartography.sh checks if Tier 1/Tier 2 maps are stale; emits systemMessage if updates needed
2. **PreToolUse (high-output commands)** → auto-compress-output.sh intercepts git/grep/test commands; runs directly, compresses >25 lines via Haiku, returns summary (exit 2)
3. **PreToolUse (git/Task)** → block-*.sh gates (protected branches, --no-verify, secrets, identity markers, wrong plan dir); exit 2 blocks, jq output asks permission
4. **PostToolUse (Write/Edit)** → enforce-tdd.sh injects test reminder; auto-update-codemaps.py reads git diff-tree, updates affected dir codemaps via Claude API
5. **PostToolUse (Task)** → delegate-task-retry.sh pattern-matches error output, appends fix hints as additionalContext
6. **SessionStop** → auto-observe.sh silently logs session activity to patterns.db; auto-dream.sh checks dual gates (sessions + hours), runs memory consolidation in background via Haiku

## Integration

- **Git hooks layer**: block-*.sh enforce policy (no commits to protected branches, no secrets, no Claude identity markers)
- **Cartography subsystem**: cartographer.py maintains .slim/cartography.json file hashes; auto-update-codemaps.py and ensure-cartography.sh consume it for targeted documentation updates
- **Memory system**: auto-dream.sh invokes Claude with auto-dream-prompt.md to prune ~/.claude/projects/*/memory/MEMORY.md and patterns.db
- **Configuration**: load-config.sh (referenced but not shown) provides LEAN_FLOW_PROTECTED_BRANCHES, LEAN_FLOW_DREAM_SESSIONS, LEAN_FLOW_DREAM_HOURS
- **Tool interop**: delegate-task-retry.sh, enforce-tdd.sh, auto-compress-output.sh all parse/emit hook JSON to integrate with Claude Code's tool pipeline
- **Subdir**: `claude-
