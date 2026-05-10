# lean-flow Hooks Registry

Complete listing of hooks shipped with the lean-flow plugin. Each hook fires on a specific event and can be toggled via environment variable.

## Hook Organization

Hooks are organized by event type. For each hook:
- **Event** — when it fires (e.g., SessionStart, PreToolUse, PostToolUse)
- **Matcher** — tool/action filter (if any; empty = runs on all)
- **Default** — opt-in or opt-out behavior
- **Env toggle** — environment variable to disable/enable
- **Purpose** — one-line description

---

## SessionStart

Fires once when the Claude Code session starts. Core initialization.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| ensure-knowledge-mcp | `ensure-knowledge-mcp.sh` | opt-out | `LEAN_FLOW_ENSURE_KNOWLEDGE_MCP_DISABLED` | Validate knowledge MCP server (pattern memory) is installed |
| ensure-plugins | `ensure-plugins.sh` | opt-out | `LEAN_FLOW_ENSURE_PLUGINS_DISABLED` | Verify lean-flow plugin and subagents are registered |
| ensure-permissions | `ensure-permissions.sh` | opt-out | `LEAN_FLOW_ENSURE_PERMISSIONS_DISABLED` | Check script/tool permissions (executable bits, paths) |
| ensure-playwright-mcp | `ensure-playwright-mcp.sh` | opt-out | `LEAN_FLOW_ENSURE_PLAYWRIGHT_MCP_DISABLED` | Validate Playwright MCP server is available |
| ensure-plan-viewer | `ensure-plan-viewer.sh` | opt-out | `LEAN_FLOW_ENSURE_PLAN_VIEWER_DISABLED` | Register plan viewer for `/plan` command |
| ensure-rtk | `ensure-rtk.sh` | opt-out | `LEAN_FLOW_ENSURE_RTK_DISABLED` | Verify Rust Token Killer (rtk) CLI is installed |
| ensure-omni | `ensure-omni.sh` | opt-out | `LEAN_FLOW_ENSURE_OMNI_DISABLED` | Verify omni CLI is installed |
| ensure-gitnexus | `ensure-gitnexus.sh` | opt-out | `LEAN_FLOW_ENSURE_GITNEXUS_DISABLED` | Validate gitnexus helper for branch/PR management |
| ensure-cartography | `ensure-cartography.sh` | opt-out | `LEAN_FLOW_ENSURE_CARTOGRAPHY_DISABLED` | Verify cartographer.py (codemap generator) is available |
| check-dependencies | `check-dependencies.sh` | opt-out | `LEAN_FLOW_CHECK_DEPENDENCIES_DISABLED` | Sanity check core dependencies (git, bash, jq, node) |
| workflow-hook | `workflow-hook.sh SessionStart` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Orchestrator role re-binding (injects lean-flow context) |

---

## PreToolUse (Bash)

Fires before a Bash tool executes. Guards against dangerous/disallowed patterns.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| bash-guard | `bash-guard.sh` | opt-out | `LEAN_FLOW_BASH_GUARD_DISABLED` | Unified blocker: --no-verify, --no-gpg-sign, protected-branch push, secret-file staging, Claude identity, PR comments |
| enforce-pr-template | `enforce-pr-template.sh` | opt-out | `LEAN_FLOW_ENFORCE_PR_TEMPLATE_DISABLED` | Require PR body follows repo's `.github/PULL_REQUEST_TEMPLATE.md` |
| enforce-branch-naming | `enforce-branch-naming.sh` | opt-out | `LEAN_FLOW_ENFORCE_BRANCH_NAMING_DISABLED` | Enforce branch prefix (feature/, fix/, hotfix/, etc.) |
| prepush-rubocop | `prepush-rubocop.sh` | opt-out | `LEAN_FLOW_PREPUSH_RUBOCOP_DISABLED` | Run rubocop linter before pushing Ruby code |
| warn-browser-snapshot | `warn-browser-snapshot.sh` | opt-out | `LEAN_FLOW_WARN_BROWSER_SNAPSHOT_DISABLED` | Warn when `browser_snapshot` MCP tool is called (heavy pages risk) |
| auto-compress-output | `auto-compress-output.sh` | opt-out | `LEAN_FLOW_AUTO_COMPRESS_OUTPUT_DISABLED` | Trim verbose/duplicate Bash output to reduce token cost |

---

## PreToolUse (Write / Edit)

Fires before Edit or Write tool call. Prevents code without planning and stops secret file modifications.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| require-plan-for-medium-heavy | `require-plan-for-medium-heavy.sh` | opt-in | `LEAN_FLOW_REQUIRE_PLAN_ENABLED` | Enforce plan existence for medium/heavy tasks before code edits |
| warn-secret-files | `warn-secret-files.sh` | opt-out | `LEAN_FLOW_WARN_SECRET_FILES_DISABLED` | Warn when editing .env or credential files |
| block-wrong-plan-dir | `block-wrong-plan-dir.sh` | opt-out | `LEAN_FLOW_BLOCK_WRONG_PLAN_DIR_DISABLED` | Prevent plan files in wrong directory (must be in `/plans/`) |

---

## PreToolUse (Read)

Fires before Read tool call. Input validation gate.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| file-read-gate | `file-read-gate.sh` | opt-out | `LEAN_FLOW_FILE_READ_GATE_DISABLED` | Prevent reading very large or binary files |

---

## PostToolUse (Write / Edit)

Fires after a file is written or edited. Workflow bookkeeping.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| workflow-hook | `workflow-hook.sh PostToolUse 'Write\|Edit'` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Update session state, track modified files |

---

## PostToolUse (EnterPlanMode)

Fires when user enters plan mode (e.g., `/plan`).

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| workflow-hook | `workflow-hook.sh PostToolUse EnterPlanMode` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Record plan mode entry time/context |

---

## PostToolUse (ExitPlanMode)

Fires when exiting plan mode. Restructures and archives the plan.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| restructure-plan | `restructure-plan.py` | opt-out | `LEAN_FLOW_RESTRUCTURE_PLAN_DISABLED` | Parse plan into machine-readable YAML/JSON with steps |
| workflow-hook | `workflow-hook.sh PostToolUse ExitPlanMode` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Log plan completion, archive state |

---

## PostToolUse (Bash)

Fires after a Bash command completes. Tracks builds, tests, and commits.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| workflow-hook | `workflow-hook.sh PostToolUse Bash` (if gh pr create) | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Auto-dispatch babysit (CI monitoring) after PR creation |
| track-test-failures | `track-test-failures.sh` | opt-out | `LEAN_FLOW_TRACK_TEST_FAILURES_DISABLED` | Record test failure counts for retry logic |
| update-plan-checklist | `update-plan-checklist.sh` (if git commit) | opt-out | `LEAN_FLOW_UPDATE_PLAN_CHECKLIST_DISABLED` | Auto-check off completed plan steps |
| compact-nudge | `compact-nudge.js` | opt-out | `LEAN_FLOW_COMPACT_NUDGE_DISABLED` | Remind user to `/compact` when context ≥ 30% |

---

## SubagentStop

Fires when a subagent (lean-flow:fixer, lean-flow:designer, etc.) finishes and stops.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| post-agent-review | `post-agent-review.sh` | opt-out | `LEAN_FLOW_POST_AGENT_REVIEW_DISABLED` | Summarize agent work and recommend next steps |
| workflow-hook | `workflow-hook.sh SubagentStop` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Clean up agent session state |

---

## Stop

Fires when the main session ends (user stops Claude). Final cleanup.

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| todo-hygiene | `todo-hygiene.sh stop` | opt-out | `LEAN_FLOW_TODO_HYGIENE_DISABLED` | Warn on unfinished TODOs in commit messages |
| workflow-hook | `workflow-hook.sh Stop` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Finalize session logs and memory |

---

## PostCompact

Fires after the user runs `/compact` (context compaction).

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| workflow-hook | `workflow-hook.sh PostCompact` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Reset session metrics and edge-case state |

---

## UserPromptSubmit

Fires when the user submits a new prompt (before STAR classification).

| Hook | Script | Default | Env Toggle | Purpose |
|------|--------|---------|------------|---------|
| workflow-hook | `workflow-hook.sh UserPromptSubmit` | opt-out | `LEAN_FLOW_WORKFLOW_HOOK_DISABLED` | Trigger STAR classification and dispatch routing |
| todo-hygiene | `todo-hygiene.sh user-prompt-submit` | opt-out | `LEAN_FLOW_TODO_HYGIENE_DISABLED` | Check for unfinished TODOs from prior steps |

---

## Summary by Default Behavior

### Opt-out (enabled by default)
Set `<ENV_TOGGLE>=true` to disable. Most hooks are production-ready and run by default.

### Opt-in (disabled by default)
Set `<ENV_TOGGLE>=true` to enable. These are experimental or context-sensitive:
- `LEAN_FLOW_REQUIRE_PLAN_ENABLED` — enforce plan requirement (stronger guardrail)

---

## Common Toggle Patterns

```bash
# Disable a single hook
export LEAN_FLOW_BASH_GUARD_DISABLED=true

# Disable all hooks (nuclear option)
export LEAN_FLOW_BASH_GUARD_DISABLED=true \
       LEAN_FLOW_ENFORCE_PR_TEMPLATE_DISABLED=true \
       # ... etc
```

Or edit `~/.claude/hooks/` (personal overrides) or `plugin/hooks/hooks.json` (repo-wide).

---

## Adding New Hooks

To register a new hook:
1. Create the script in `plugin/scripts/<name>.sh` or `.js`
2. Add entry to `plugin/hooks/hooks.json` under the appropriate event
3. Document in this file with name, default toggle, and purpose
4. Test with `bash tests/shell/test-*.sh`
