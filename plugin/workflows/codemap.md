# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines the operational rules and decision frameworks that govern Claude's development workflow. `claude-rules.md` prescribes mandatory lean-flow skill triggers, escalation discipline, and branching conventions. `standard-development-flow.md` documents the complete session orchestration flow, distinguishing the orchestrator (opus, coordinates only) from execution lanes (fixer/designer haiku, reviewers sonnet). Together they form the "laws of motion" for the codebase.

## Design
Two complementary rule documents:
- **claude-rules.md**: Tabular reference (mandatory triggers, branch naming, flow phases) — triage → pattern search → brainstorm → planning → branching → execution steps → verification.
- **standard-development-flow.md**: Mermaid flowchart showing role separation (orchestrator/fixer/designer/oracle), STAR classification (simple/medium/heavy/greenfield/hotfix), dispatch routing, parallel execution (designer + fixer), and gating (coverage ≥80–90%, CI green, oracle approval before main PR merge).

Key patterns: TDD-first (RED→GREEN→REFACTOR), step-branch sequencing (step-N → parent only after step-N−1 merged), escalation caps (fixer fails 3× → oracle diagnoses), and hybrid codemap updates post-merge.

## Flow
User prompt → auto pattern recall (STAR classify) → orchestrator decides path (simple: direct PR; complex: map/brainstorm/plan; greenfield: doc-first PRD/HLA/TRD; hotfix: fast bypass) → orchestrator dispatches fixer/designer to step branches (parallel when independent) → step PR → parent (auto-merge) → loop next step → final parent PR → oracle code review + finish checklist → CI gate → merge to main.

Escalation: fixer stuck 3× → oracle (think-only systematic-debugging) → human flag if oracle escalates 3×.

## Integration
Enforces discipline across `lean-flow:*` commands (systematic-debugging, test-driven-development, code-reviewer, finishing-a-development-branch, plan-checker, phase-researcher, etc.). Orchestrator lane reads from `docs/CODEBASE_MAP.md` (via `/cartographer`) and patterns.db (FTS5 pattern recall). Post-merge, step-branch commits trigger `lean-flow:cartography` for hybrid codemap updates (§12a). Branch naming and PR strategy drive CI/release-notes generation. Hotfix path bypasses planning but still runs oracle inline review; all other paths gate on coverage ≥80–90% and oracle final approval.
