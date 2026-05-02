# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines Claude's operational playbooks and mandatory skill invocation rules. `claude-rules.md` establishes non-negotiable workflows (TDD, verification gates, escalation paths, branch naming). `standard-development-flow.md` documents the session orchestration architecture (STAR classification, pattern recall, fixer/designer dispatch, PR gates).

## Design
**Two-lane architecture**: Orchestrator (opus, coordinates via hooks/MCPs—never edits code) + Execution (fixer/designer haiku implement in parallel, sonnet reviewers gate merges). **Skill gates** enforce TDD→verification→code-review→oracle-sign-off. **Branch model** uses parent + step-N sequential PRs, with hybrid solo-dev shortcut. **Escalation**: 3-strike fixer retry → oracle diagnosis → human flag. **Classification**: STAR (simple/medium/heavy) routes to different fastpaths (direct PR, hotfix, or full planning).

## Flow
**Session start** → auto-recall patterns (FTS5 `patterns.db`) → STAR classify → route (simple→direct PR; hotfix→minimal fix; complex→map-codebase/brainstorm/plan). **Plan approval** → orchestrator creates parent branch → fixer dispatches per step (TDD RED→GREEN→REFACTOR, ≥90% coverage gate). **Step PR merges to parent**, orchestrator advances to next step. **Final PR parent→main** → lean-flow:code-reviewer (sonnet) → fixer routes issues (backend/frontend/cross-cutting) → lean-flow:oracle signs off → cartography updates codemap.

## Integration
Imported via `session-briefing.sh` (additionalContext) into orchestrator.md role declaration. Hooks: `SessionStart`, `UserPromptSubmit` trigger auto-recall and STAR classification. MCPs: knowledge (pattern_search), explorer (cartography, map-codebase), phase-researcher (verify APIs). Commands invoked: `lean-flow:*` (TDD, debugging, code-review, oracle). Output: branch structure, PR gates, codemap updates feed back to `docs/CODEBASE_MAP.md` and `patterns.db`.
