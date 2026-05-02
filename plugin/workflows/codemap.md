# plugin/workflows/

# plugin/workflows/ Codemap

## Responsibility
Defines the orchestration rules and execution patterns for all Claude-assisted development workflows. `claude-rules.md` specifies mandatory skill triggers (TDD, debugging, verification), branch strategy, and escalation rules. `standard-development-flow.md` documents the full session lifecycle (STAR classification → planning → parallel execution with fixer/designer/reviewers) and role assignments (opus orchestrator vs. haiku fixer vs. sonnet reviewers).

## Design
Two-lane architecture: **Orchestrator lane** (opus) coordinates via pattern recall, triage, brainstorming, and plan gates without writing code; **Execution lane** (haiku fixer + sonnet reviewers) implements code in step branches with parallel frontend/backend dispatch. Key patterns: step-branch sequencing (step-1 → PR → step-2), TDD-first with coverage ≥90%, escalation after 3 retry failures, and inlined oracle review for hotfixes. Branch naming enforces kebab-case prefixes (`feature/`, `fix/`, `improvement/`, `hotfix/`, `docs/`) with step suffixes.

## Flow
Session starts with role declaration (orchestrator loads `orchestrator.md`). User prompt → auto pattern recall (FTS5 search) → STAR classification (simple/medium/heavy/greenfield/hotfix) → conditional dispatch: simple/hotfix skip planning; medium/heavy invoke brainstorm → `superpowers:writing-plans` → parent branch → sequential step branches with fixer/designer parallel work → coverage gate → step PRs auto-merge → final parent→main PR with code-reviewer + oracle gates. Failures feed back to fixer via systematic-debugging; 3 failures escalate to oracle (think-only).

## Integration
Embedded in session initialization via `session-briefing.sh` and `orchestrator.md` injection. References external tools: `lean-flow:*` commands (TDD, debugging, verification, map-codebase, phase-researcher), `superpowers:writing-plans/executing-plans`, knowledge MCP pattern search, and cartography for changed-folder updates. Final PR gates validate against `CLAUDE.md` compliance. Codemap updates merge into `docs/CODEBASE_MAP.md` and `patterns.db` (hybrid pattern store).
