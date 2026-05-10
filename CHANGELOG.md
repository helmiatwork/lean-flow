# Changelog

## [1.5.0] - 2026-05-10

### Added

- **P3 advisory checks for optional CLI tools** (#26, #27):
  - Check 26: RTK CLI installed — informational check for token-optimization CLI tool
  - Check 27: omni CLI installed — informational check for communication compression tool
- Advisory rows display in project-doctor report without affecting the 25-item score denominator.
- Advisory checks excluded from `--missing-only` output (informational only, not actionable).

### Changed

- `/project-doctor` report now includes 2 advisory rows (items 26–27) after the 25 scored items.
- Advisory rows use `[OK]` or `[ADVISORY]` status instead of `[MISSING]`.
- Documentation updated to clarify advisory vs. scored items in project-doctor and project-doctor-fix commands.

## [1.4.0] - 2026-05-10

### Added

- **`/project-doctor` extended to 25 checks** — 5 new audit items for governance and tooling:
  - **Check 21: STAR enforcement** (P1) — validates project has Tier Routing and STAR PROTOCOL documentation in CLAUDE.md
  - **Check 22: Orchestrator binding** (P1) — ensures orchestrator governance rules are explicitly documented
  - **Check 23: Companion plugins** (P2) — confirms superpowers and caveman plugins are active
  - **Check 24: Pre-commit gates** (P1) — verifies security gates (block-protected-push, block-no-verify, etc.) are declared
  - **Check 25: Pattern memory usage** (P2) — checks if pattern_search/pattern_store are documented in CLAUDE.md
- Updated scoring denominator: checks now total 25 (previously 20). Existing project scores will shift slightly.
- New clustering for `/project-doctor-fix`: rules cluster now includes items 18, 21, 22, 25; tooling cluster expanded to 23, 24.

### Changed

- `score.sh` total denominator updated from 20 to 25.
- `/project-doctor` final score now reported as `X/25 (Y%)`.
- `/project-doctor-fix` score delta now shows `X/25 → Y/25`.
- Test suite extended: smoke test now asserts 25 item rows in default markdown table output.
- README.md references updated to reflect 25-item audit.

## 1.3.0 — 2026-05-10

### Added

- `ensure-plugins.sh` now auto-enables `caveman@caveman` plugin (token-compressed communication mode) on SessionStart. Idempotent — does nothing if already enabled.
- `LEAN_FLOW_ENABLE_CAVEMAN` environment variable for users to opt out of caveman auto-enable (set to `false` to skip).

### Fixed

- `ensure-plugins.sh` now respects user-set `false` values in `enabledPlugins` — was silently re-enabling plugins that users explicitly disabled.

### Changed

- Updated companion plugin list in README.md to include caveman.
- `ensure-plugins.sh` now uses `has(...)` checks instead of `jq -e` to distinguish between absent keys (auto-enable) and explicit `false` values (respect user choice).

## 1.2.0 — 2026-05-10

### Added

- `/project-doctor` slash command — read-only audit of 20 AI-readiness context artefacts (project overview, codebase map, ADR folder, hooks, agent memory, etc.).
- `/project-doctor-fix` slash command — single-shot generation of all missing artefacts via 4W1H clusters; dispatches `lean-flow:fixer` haiku for file writes with direct-Write fallback for resilience.
- `scripts/project-doctor/score.sh` — bash scanner with `--score-only` and `--missing-only` modes.
- `tests/shell/test-project-doctor.sh` — 6-test smoke suite for the scanner.
- `plugin/CONVENTIONS.md` — namespace conventions for commands, skills, scripts, hooks.
- `docs/adr/0001-commands-vs-skills.md` — ADR documenting the commands/ vs skills/ distinction.

### Changed

- `README.md` "What's Inside" tree updated with `commands/`, `skills/project-doctor*.md`, and `scripts/project-doctor/`.
- `CLAUDE.md` "Bundled Commands" section now points to `README.md#bundled-commands` (single source of truth).

### Notes

- Imports project-doctor v0.3.0 functionality. The standalone helmiatwork/project-doctor plugin is planned for deletion in a follow-up.

## 1.1.0 (2026-04-04)
- Add greenfield doc-first development path (brainstorm → generate PRD/HLA/TRD/DB/API docs → plan from docs)
- Add solo dev workflow shortcut (skip step branches, commit on parent, parallel plan-plus-executor agents)
- Add multi-repo TRD splitting guidance (scope docs per repo to reduce token bloat)
- Update mermaid diagrams with greenfield path in both workflow and README

## 1.0.0 (2026-04-03)
- Initial release
- 7 agents: oracle, fixer, auditor, tester, librarian, designer, explorer
- Knowledge MCP: pattern_search, pattern_store, pattern_list, pattern_delete, pattern_stats, project_context
- Auto-install: permissions, Playwright, SwiftBar monitor, companion plugins
- Session briefing, auto-dream, PR review hooks
- Hierarchical branching strategy
- Branch naming convention
