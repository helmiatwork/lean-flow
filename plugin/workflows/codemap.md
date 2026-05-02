# plugin/workflows/

# plugin/workflows/ Codemap

## Responsibility
Defines Claude's operational workflows and rule-based decision engines. `claude-rules.md` enforces mandatory skill triggers (TDD, debugging, verification) and branch governance. `standard-development-flow.md` orchestrates the session lifecycle: STAR classification → pattern recall → planning → fixer dispatch → verification, with distinct lanes for orchestrator (opus) vs. execution (haiku/sonnet fixer).

## Design
- **Dual-layer governance**: `claude-rules.md` sets hard constraints (escalation rules, branching schema, mandatory lean-flow commands); `standard-development-flow.md` provides the control-flow diagram.
- **Swim-lane separation**: Orchestrator (coordinator, no code edits) vs. Execution (fixer/designer/reviewer, all writes).
- **Context-aware dispatch**: Simple tasks skip planning; complex tasks trigger brainstorm → plan-checker gate; greenfield tasks auto-generate PRD/HLA/TRD first.
- **Escalation gate**: Failures at same step ≥3 times block retry; oracle diagnoses root cause.

## Flow
1. SessionStart hook loads `orchestrator.md` role + `claude-rules.md` constraints.
2. User prompt triggers auto-recall (FTS5 pattern search).
3. STAR classify → route: simple (direct fixer PR), hotfix (fast path), or complex (brainstorm → plan-checker → execute via step branches).
4. Fixer implements with TDD, verifies coverage ≥90%, commits with orchestrator-dispatched cartography.
5. Step PRs auto-merge to parent; parent PR to main requires code-reviewer + oracle approval + CLAUDE.md validation.

## Integration
- **Consumed by**: SessionStart hook (loads rules), UserPromptSubmit hook (STAR classify), fixer dispatch (lean-flow:* commands), oracle review (verification-before-completion, code-reviewer).
- **Reads from**: `docs/CODEBASE_MAP.md` (triage gate), `docs/orchestrator.md` (role config), knowledge MCP (pattern search).
- **Writes to**: pattern_store, codemap updates (§12a hybrid merge), branch naming reflects schema.
- **Dependencies**: lean-flow skill triggers (TDD, debugging, finishing), superpowers:writing-plans/executing-plans, cartography for changed folders.
