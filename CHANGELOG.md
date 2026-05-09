# Changelog

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
