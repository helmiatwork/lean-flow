# plugin/workflows/

# plugin/workflows/ Codemap

## Responsibility
Defines the canonical development workflows and rules that Claude agents follow when executing tasks in the lean-flow system. These files establish non-negotiable skill triggers, branching strategy, triage logic, and execution patterns across simple/complex/greenfield/hotfix paths.

## Design
- **claude-rules.md**: Prescriptive ruleset — mandatory skill invocations (TDD, debugging, verification), escalation thresholds (3 failures → oracle → human), branch naming conventions (feature/fix/hotfix/docs with kebab-case), and sequential step-branching strategy (parent → step-1 → step-2 → main).
- **standard-development-flow.md**: Visual flowchart (Mermaid) mapping user prompt → auto-recall → STAR triage → four paths (simple/complex/greenfield/hotfix) with decision gates, skill invocations (map-codebase, brainstorming, plan-checker, verifier, nyquist-auditor), and merge logic.

## Flow
Entry point: user prompt triggers `UserPromptSubmit` hook → auto-recall (pattern.db FTS5 lookup) → STAR clarification (haiku classifies complexity) → orchestrator triage. Branches into:
- **Simple**: fixer → tests → PR main (no planning).
- **Complex**: pattern search → codebase mapping → research → brainstorming → planning (with plan-checker gate) → branching (parent + step branches) → fixer execution + verification.
- **Greenfield**: brainstorm → doc-first (PRD/HLA/TRD) → planning → execution.
- **Hotfix**: minimal fix on hotfix/ branch → inline oracle review → merge + cherry-pick.

## Integration
- **claude-rules.md** enforces constraints on all agent behaviors (fixer, oracle, explorer, librarian, haiku classifiers) and feeds branch strategy to git operations.
- **standard-development-flow.md** orchestrates skill dispatch across `lean-flow:*` commands (TDD, debugging, verification-before-completion, finishing-a-development-branch), knowledge MCP pattern search, and downstream agents (plan-checker, verifier, nyquist-auditor).
- Both files are read during task triage and referenced during step execution to validate compliance with branching, escalation, and skill-trigger rules.
