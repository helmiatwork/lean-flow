# plugin/workflows/

# `plugin/workflows/` Codemap

## Responsibility
Defines the mandatory rules and orchestration flow for Claude-assisted development. `claude-rules.md` enforces lean-flow command discipline, branching strategy, and escalation gates; `standard-development-flow.md` visualizes the full session lifecycle from triage through merge, separating orchestrator (coordination) from execution (fixer/designer/reviewer roles).

## Design
- **Rule-driven gates**: TDD, verification-before-completion, and 3-strike escalation prevent blind retries and enforce quality checkpoints.
- **Role separation**: Orchestrator (opus, decision-only) vs. Execution (fixer haiku, designer, reviewers). Orchestrator never edits code; dispatches work and verifies summaries.
- **Step-branching model**: Complex tasks split into sequential steps (step-1 → step-2 → parent) with parallel designer dispatch for frontend work; simple tasks skip steps, go direct to main.
- **Pattern reuse**: Pre-planning pattern search + research phase (phase-researcher, assumptions-analyzer, spike) reduce rework and surface hidden complexity.

## Flow
1. **Triage** (AUTORECALL + STAR classify) → pattern search → if found, dispatch fixer with pattern; if not, brainstorm + planning.
2. **Planning** (EnterPlanMode → superpowers:writing-plans → plan-checker gate) → user approval → ExitPlanMode.
3. **Branching & Execution**: Parent branch + step branches; each step: TDD (RED→GREEN→REFACTOR) → fixer impl → tests → cartography → PR to parent.
4. **Verification**: Parent→main PR → code-reviewer (sonnet) → oracle spot-check → codemap update → CI gate.
5. **Escalation**: Fixer fails 3×same step → oracle diagnoses (think-only); oracle escalates 3× → flag human intervention.

## Integration
- **Entry**: SessionStart hook loads orchestrator.md; UserPromptSubmit hook triggers auto-recall (FTS5 pattern search).
- **Dispatch targets**: Fixer (lean-flow commands), designer (optional, parallel frontend work), explorer (cartography), oracle (debugging & final validation).
- **Outputs**: PRs (simple→main, steps→parent, parent→main), release notes, codemap updates (§12a), pattern_store entries.
- **Dependencies**: Knowledge MCP (pattern_search), codebase-map.md (triage check), ADRs/PRDs/SPECS (ingest-docs), orchestrator.md (session briefing).
