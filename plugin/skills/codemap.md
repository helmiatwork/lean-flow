# plugin/skills/

## Responsibility
`plugin/skills/` houses the decision-making and workflow orchestration skills that guide the agent through structured processes before and during implementation. These skills define when to use which tool, how to validate assumptions, and how to avoid common pitfalls (bugs, incomplete plans, scope creep). They are the "guardrails" that prevent expensive mistakes.

## Design
Each skill is a self-contained markdown document defining a process with clear entry conditions, steps, and output format. Skills follow **hierarchical invocation patterns**:
- **Master skill** (`using-lean-flow.md`) routes to task-appropriate skills based on situation
- **Pre-work skills** (discuss, phase-researcher, assumptions-analyzer, ingest-docs, map-codebase) run sequentially before planning
- **Execution skills** (test-driven-development, systematic-debugging) guide implementation behavior
- **Completion skills** (plan-checker, finishing-a-development-branch, nyquist-auditor) validate work before merge
- **Utility skills** (delegate-to-haiku, spike, brainstorming, cartography) support specific tactical needs

Each skill specifies: when to invoke, what agent type to dispatch (explorer/fixer/oracle), input/output format, and failure modes.

## Flow
**Task → Classification** (simple/medium/heavy/hotfix/bug) **→ Skill selection** (via using-lean-flow) **→ Sequential pre-work** (discuss → research → plan) **→ Execution with guards** (TDD, systematic-debugging on failures) **→ Validation** (plan-checker, verifier, completion checklist) **→ Merge**.

Pre-work skills are lightweight (2-3 steps) to gather decisions before entering implementation. Execution skills enforce discipline (red-green-refactor, root-cause-first debugging). Post-work skills prevent shipping incomplete or untested work.

## Integration
Skills are invoked by the orchestrator (opus) based on task context. They typically dispatch sub-agents (haiku explorers/fixers for execution, sonnet for review). Skills read from `docs/`, codebase files, and git history; they produce outputs (decision summaries, plans, test files, merge artifacts) that feed into the next skill. `using-lean-flow.md` is the entry point — it classifies the task and routes to the appropriate skill chain. `delegate-to-haiku.md` is referenced within other skills to prevent expensive orchestrator context usage on mechanical tasks.
