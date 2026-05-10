# Codebase Map

Layout of the lean-flow plugin repository.

## Root

- `.claude-plugin/` — plugin metadata (plugin.json).
- `CHANGELOG.md` — release history.
- `README.md` — install guide, features, quick start.
- `CLAUDE.md` — conventions, tech stack, overview.
- `LICENSE` — MIT.

## `plugin/` — Plugin Internals

Bundled into the lean-flow distribution.

### `plugin/agents/`

Subagent contracts (6 markdown files, no `lean-flow:` prefix on disk):

- `orchestrator.md` — main session binding, tier routing, hard rules.
- `fixer.md` — end-to-end execution (impl, tests, lint, commit, push, PR, reviews, merge).
- `oracle.md` — think-only architecture, security, PR review. No file access.
- `code-reviewer.md` — code quality, SOLID principles, patterns.
- `explorer.md` — file discovery, codebase structure, pre-oracle diff reading.
- `librarian.md` — docs lookup, web search, API reference (Context7 MCP).
- `designer.md` — frontend/UI/UX, responsive design, a11y.

### `plugin/commands/`

Slash command definitions:

- `project-doctor.md` — read-only audit of 25 AI-readiness items + 2 advisory.
- `project-doctor-fix.md` — auto-generate missing artefacts.

### `plugin/hooks/`

- `hooks.json` — SessionStart, PreToolUse, PostToolUse hook registrations.

### `plugin/scripts/`

Hook bodies and utilities (all registered in hooks.json or used by other scripts).

**Workflow hooks** (consolidated into `workflow-hook.sh`):

- `session-briefing.sh` — SessionStart: git state summary.
- `pattern-recall.sh` — UserPromptSubmit: knowledge MCP pattern search.
- `load-workflow.sh` — UserPromptSubmit: inject orchestrator context (once/session).
- `star-clarify.sh` — UserPromptSubmit: detect vague prompts.
- `enforce-tdd.sh` — PostToolUse Write/Edit: mandatory TDD reminder.
- `knowledge-prefilter.sh` — PostToolUse EnterPlanMode: inject patterns.
- `generate-plan-viewer.sh` — PostToolUse ExitPlanMode: open plan dashboard.
- `remind-check-step.sh` — SubagentStop: remind mark step [x].
- `auto-dream.sh` — Stop: memory consolidation (background).
- `auto-observe.sh` — Stop: session observations (background).
- `session-summary.sh` — Stop/PostCompact: write summary (background).

**Safety hooks** (separate):

- `block-protected-push.sh` — PreToolUse Bash: block push to main/master/staging.
- `block-no-verify.sh` — PreToolUse Bash: block --no-verify flags.
- `block-secret-commits.sh` — PreToolUse Bash: block .env/.credentials staging.
- `block-claude-identity.sh` — PreToolUse Bash: block Claude attribution.
- `warn-secret-files.sh` — PreToolUse Write/Edit: warn near secret paths.
- `block-wrong-plan-dir.sh` — PreToolUse Write/Edit: block plans outside ~/.claude/plans/.

**Automation hooks**:

- `file-read-gate.sh` — PreToolUse Read: inject git activity (~20 tokens).
- `track-test-failures.sh` — PostToolUse Bash: count failures, escalate at 3.
- `auto-update-codemaps.sh` — PostToolUse Bash(git commit): update codemaps.

**Ensure scripts** (SessionStart):

- `ensure-knowledge-mcp.sh` — auto-install SQLite pattern memory.
- `ensure-plugins.sh` — auto-enable superpowers, caveman, plan-plus.
- `ensure-permissions.sh` — auto-configure workflow permissions.
- `ensure-playwright-mcp.sh` — auto-install Playwright + Chromium.
- `ensure-claude-monitor.sh` — auto-install SwiftBar monitor (macOS).
- `ensure-rtk.sh` — auto-install RTK.
- `ensure-cartography.sh` — detect codebase map changes.
- `ensure-plan-viewer.sh` — auto-start plan viewer server.

**Utilities**:

- `workflow-hook.sh` — single entry point, routes by event, merges additionalContext.
- `load-config.sh` — load ~/.claude/lean-flow.json config.
- `token-budget.sh` — token budget tracking.
- `restructure-plan.py` — plan-plus restructuring (PostToolUse ExitPlanMode).
- `cartographer.py` — Tier 2: MD5 change detection per folder.
- `scan-codebase.py` — Tier 1: codebase scanner with token counts.
- `uninstall.sh` — remove all lean-flow components.
- `lean-preset.sh` — switch model presets (cheap, balanced, powerful, thinking).

**Subfolders**:

- `project-doctor/` — project-doctor audit and fix suite (score.sh, fix.sh).
- `claude-monitor/` — SwiftBar plugin + fetcher daemon.

### `plugin/skills/`

Auto-discoverable skill modules (invoked via Skill tool):

- `cartography.md` — codebase mapping (cartographer command).
- `project-doctor.md` — project-doctor audit skill.
- `project-doctor-fix.md` — project-doctor fix generation skill.

### `plugin/workflows/`

- `standard-development-flow.md` — canonical workflow (mermaid + prose).

### `plugin/mcp-servers/`

- `knowledge/` — SQLite + FTS5 pattern memory MCP server.

## `templates/`

PR and commit style guides:

- `PULL_REQUEST_TEMPLATE.md` — step branch → parent (no release notes).
- `PULL_REQUEST_TEMPLATE_MAIN.md` — parent → main (include release notes).
- `COMMIT_CONVENTION.md` — commit format + types.

## `tests/`

Bash + Python + Node test suite. Register new tests in `tests/run-all.sh`.

### `tests/shell/`

Bash smoke + integration tests:

- `test-project-doctor.sh` — audit and fix commands.
- `test-load-config.sh` — config loading.
- `test-workflow-hook.sh` — hook router.
- `test-ensure-*.sh` — bootstrap scripts.
- `test-block-*.sh` — safety hooks.
- (additional tests per coverage)

### `tests/python/`

- `test-cartographer.py` — Tier 2 change detection.
- `test-scan-codebase.py` — codebase scanner.

### `tests/node/`

- `test-plan-server.mjs` — SSE + file watch.
- `test-plan-viewer.mjs` — static HTML generator.

### `tests/run-all.sh`

Test runner — explicit list (not auto-discovered), includes shellcheck gate.

## `docs/`

Architectural and reference documentation.

- `ARCHITECTURE.md` — system design, hook lifecycle, agent models (mermaid).
- `CODEBASE_MAP.md` — this file.
- `DOMAIN.md` — entities, relationships, boundaries.
- `SYMBOL_GRAPH.md` — symbol indexing tooling (GitNexus).
- `adr/` — Architectural Decision Records (Nygard format).

## Other Directories

- `.github/workflows/` — CI tests (GitHub Actions).
- `.claude-plugin/` — plugin manifest (plugin.json).
- `.slim/` — cartography metadata (MD5 tracking, .gitignored).
- `src/`, `scripts/` — repo-level utilities (minimal, mostly empty).
