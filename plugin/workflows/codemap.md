# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines the orchestration rules and development workflows that Claude agents follow across all sessions. `claude-rules.md` enforces mandatory skill triggers (TDD, debugging, verification), branching strategy, and escalation policies. `standard-development-flow.md` provides the end-to-end session flow with role assignment (orchestrator vs. fixer/designer), dispatch patterns, and CI integration points.

## Design
- **Dual-track architecture**: Orchestrator lane (opus, coordinates only) and Execution lane (fixer haiku + reviewers sonnet, all writes) run in parallel
- **STAR classification** gates task complexity: simple (direct PR) → medium/heavy (planning) → greenfield (doc-first) → hotfix (fast path)
- **Pattern recall first**: FTS5 knowledge search before brainstorming; matching pattern skips planning and goes straight to dispatch
- **Mandatory gates**: `lean-flow:test-driven-development` (RED→GREEN→REFACTOR + ≥80% coverage), `lean-flow:verification-before-completion`, `lean-flow:code-reviewer`, `lean-flow:plan-checker` (8-dimension verification)
- **Escalation capped**: fixer fails 3× same step → oracle diagnoses; oracle escalates 3× → flag for human intervention

## Flow
User prompt → AutoRecall (pattern_search.db) → STAR classify → Pattern match? → Yes: Dispatch fixer with pattern / No: Brainstorm (researcher + assumptions-analyzer + spike if blocked) → Plan (EnterPlanMode → superpowers:writing-plans → plan-checker gate → approve) → Create parent branch → For each step: Create step branch → TDD (RED→GREEN→REFACTOR) → Fixer implements + self-verifies (coverage ≥90%) → PR step→parent (auto-merge) → Back to orchestrator STEP loop → Final: Dispatch post-steps (verifier + nyquist + finishing) → Open PR parent→main → Code review (lean-flow:code-reviewer sonnet) → Oracle final gate → Hybrid codemap update + pattern_store → CI green → Merge.

## Integration
- **Entry**: SessionStart hook loads `orchestrator.md` via session-briefing.sh; UserPromptSubmit hook fires AutoRecall
- **Knowledge tier**: Feeds pattern_search.db (FTS5); outputs to `pattern_store` post-merge
- **Dispatch contracts**: Rules specify which superpowers each role invokes (`superpowers:writing-plans`, `superpowers:executing-plans`, `lean-flow:*` skills)
- **CI/Coverage gates**: Coverage ≥90% blocks step completion; CI red triggers fixer loop or oracle escalation
- **Docs dependency**: Requires `docs/CODEBASE_MAP.md` pre-check; greenfield tasks output PRD/HLA/TRD to docs before planning
