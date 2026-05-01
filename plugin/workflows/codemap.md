# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility

Defines Claude's operational workflows and rule enforcement:
- **claude-rules.md**: Mandatory skill triggers (TDD, verification, debugging), escalation rules, branch naming conventions, and triage logic for simple/complex/greenfield/hotfix tasks
- **standard-development-flow.md**: Full orchestration flowchart (STAR triage → pattern search → planning → step execution → verification) with parallel agent dispatch (explorer, librarian, researcher, fixer)

## Design

**Two-layer workflow model:**
1. **Rules layer** (claude-rules.md): Deterministic rules — when to invoke skills (`lean-flow:systematic-debugging`, `lean-flow:test-driven-development`), escalation thresholds (3 failures → oracle), branch strategy (feature/name/step-N)
2. **Flow layer** (standard-development-flow.md): Decision-tree orchestration — auto-recall patterns, STAR complexity classification, triage branching (simple→direct, complex→plan, greenfield→docs-first, hotfix→fast-path), parallel dispatch of fixer/explorer/librarian agents

**Key patterns:**
- TDD mandatory before implementation (RED→GREEN→REFACTOR→E2E→coverage ≥80%)
- Brownfield orientation: `map-codebase` + `ingest-docs` before planning
- Plan verification gated by `plan-checker` (8-dimension validation)
- Escalation on repeated failures (3× same step blocks, oracle escalates 3× for human intervention)

## Flow

User prompt → Auto pattern recall (FTS5) → STAR clarify (haiku complexity) → Orchestrator triage:
- **Simple** (1-2 files): fixer → tests → PR
- **Complex**: pattern search → research (assumptions/pitfalls) → plan (EnterPlanMode) → plan-checker → branching → parallel step execution (fixer + tests)
- **Greenfield**: brainstorm → PRD/HLA/TRD → same complex path
- **Hotfix**: minimal planning, fast hotfix/ branch, inline oracle review

Verification gates: TDD red/green, `verification-before-completion` (unit+E2E+coverage), `plan-checker` post-plan, `nyquist-auditor` for coverage gaps.

## Integration

- **Skills system**: references lean-flow commands (`systematic-debugging`, `test-driven-development`, `verification-before-completion`, `code-reviewer`, `map-codebase`, `ingest-docs`, `brainstorming`, `phase-researcher`, `spike`, `finishing-a-development-branch`)
- **Knowledge MCP**: pattern search (pattern_search knowledge), ADR/PRD/SPEC ingestion
- **Branching**: interfaces with Git strategy (parent + step branches, PR workflow)
- **Agent dispatch**: orchestrates explorer (haiku), librarian (haiku), researcher, fixer agents in parallel for complex tasks
- **Verification layer**: `plan-checker`, `nyquist-auditor` validate completeness before merge
