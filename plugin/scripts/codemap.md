# plugin/scripts/

# plugin/scripts/ – Codemap

## Responsibility

Automation hooks and utilities for workflow enforcement, memory consolidation, and documentation maintenance. Acts as the glue layer between Claude sessions and the filesystem—blocking unsafe operations, capturing patterns, updating codemaps, and triggering async cleanup tasks.

## Design

**Hook-based architecture**: Most scripts are PreToolUse/PostToolUse hooks (bash/python reading stdin JSON, emitting exit codes or JSON responses). Common patterns:
- Input validation via `jq` to extract tool name/command
- Early exit on mismatches (exit 0 = passthrough)
- Exit 2 or JSON emission to block/warn
- Config inheritance via sourced `load-config.sh`

**Guard rails** (block-*.sh): Negative enforcement—blocks commits with Claude attribution, --no-verify flags, pushes to protected branches, secret files, wrong directories.

**Async background tasks** (auto-dream.sh, auto-observe.sh): Dual-gated or fire-and-forget background processes. Lock files prevent concurrent runs; no model output or API tokens consumed.

**Documentation generation** (auto-update-codemaps.py/sh): PostToolUse on git commit—detects changed directories, reads file samples, calls Claude API to generate/update codemap.md sections in batch.

## Flow

1. **Session lifecycle**: `check-dependencies.sh` on SessionStart audits required plugins (superpowers, jq, MCPs); emits single systemMessage if missing.

2. **Pre-execution guards** (PreToolUse):
   - `enforce-branch-naming.sh` validates git branch name pattern
   - `block-*.sh` scripts reject unsafe operations (secrets, identity markers, flags, protected pushes)
   - `auto-compress-output.sh` intercepts high-output commands, runs directly, summarizes large results via Haiku

3. **Post-execution capture** (PostToolUse):
   - `auto-update-codemaps.py` reads git diff-tree, collects file samples, calls Claude API to write/update codemap.md
   - `auto-observe.sh` parses session log, inserts tool/branch observation into patterns.db (zero API cost)
   - `delegate-task-retry.sh` detects Task delegation failures, appends inline retry guidance

4. **Background consolidation**:
   - `auto-dream.sh` fires on SessionStop if N sessions elapsed AND M hours passed (dual-gated)
   - Runs Haiku against memory files to consolidate/prune patterns.db and MEMORY.md
   - Locked to prevent concurrent runs; 5-minute timeout

5. **Repository mapping** (cartographer.py): Standalone utility—reads include/exclude patterns, builds state file with file hashes and empty codemaps; used by auto-update-codemaps.py to detect changes.

## Integration

- **Settings**: Reads `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS` from `load-config.sh`
- **Credentials**: `auto-update-codemaps.py` fetches OAuth token from macOS keychain (`security find-generic-password`) or `ANTHROPIC_API_KEY` env var
- **Filesystem**:
  - `~/.claude/dream-state/` – dream lock, session count, last-dream timestamp
  -
