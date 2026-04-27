# plugin/scripts/

# plugin/scripts/ Codemap

## Responsibility
Lifecycle hooks and automation for lean-flow: gate commands (block secrets, protected branches, Claude identity), consolidate session memory, auto-update codemaps on commits, monitor token usage, and enforce TDD patterns. Zero-cost transparent passes for allowed operations.

## Design
**Hook-based architecture**: PreToolUse (block/warn), PostToolUse (auto-update/remind), SessionStart (ensure state), SessionStop (consolidate). Each script is independent, exits 0 to pass-through or exits 2 to block. **Two-gate patterns**: auto-dream uses session count + elapsed time; cartography uses git log + file hash state. **Token efficiency**: haiku compression for large output (auto-compress-output.sh), pattern pruning (auto-dream-prompt.md), direct execution without Claude for high-output commands.

## Flow
1. **PreToolUse** scripts (block-*.sh) parse `jq` input command, match against regexes, output decision (block=exit 2, pass=exit 0)
2. **PostToolUse** scripts (auto-update-codemaps.sh → .py, enforce-tdd.sh) read changed files, invoke Claude API or local tools, output guidance
3. **SessionStart** scripts (ensure-cartography.sh, ensure-claude-monitor.sh) check repo state, report missing tiers or monitors
4. **SessionStop** script (auto-dream.sh) increments session counter, checks dual gates (hours + count), runs cartographer + memory consolidation in background
5. **Utility tools** (cartographer.py: git diff-tree → hashes + codemaps; auto-observe.sh: session log → patterns.db)

## Integration
- **CLI**: cartographer.py called by auto-update-codemaps.py and ensure-cartography.sh; claude-monitor scripts monitor API usage via SwiftBar
- **Storage**: .slim/cartography.json (file state), ~/.claude/dream-state/ (dream gates), ~/.claude/knowledge/patterns.db (session patterns), ~/.claude/projects/*/memory/ (consolidated memories)
- **Config**: load-config.sh sources LEAN_FLOW_* vars (protected branches, dream thresholds, monitor enable flag)
- **Git hooks**: auto-update-codemaps.sh runs post-commit; block-*.sh gate all Bash/gh commands via PreToolUse
