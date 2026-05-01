# plugin/skills/

# Codemap: `plugin/skills/`

## Responsibility
Skill definitions for the lean-flow orchestration system. Each `.md` file defines a reusable task pattern—from pre-work discussion and research through implementation, testing, and completion. Skills are invoked by the orchestrator to guide structured work on software projects.

## Design
- **Skill as declarative template**: Each file defines when to invoke, process steps, rules, and output formats—not implementation code
- **Nested skill composition**: Complex work chains simple skills (e.g., `discuss` → `phase-researcher` → `map-codebase` → `write-plans`)
- **Agent routing patterns**: Skills dispatch work to appropriate agents (explorer/haiku for reads, fixer/haiku for writes, librarian for research)
- **Verification-first architecture**: Many skills include explicit "verify before proceeding" gates (test-driven-development, plan-checker, systematic-debugging)

## Flow
1. **Pre-work skills** (`discuss`, `assumptions-analyzer`, `ingest-docs`, `phase-researcher`) — lock decisions and context before planning
2. **Planning skills** (`map-codebase`, `cartography`) — understand the codebase structure
3. **Execution skills** (`test-driven-development`, `brainstorming`, `spike`) — guided implementation with validation
4. **Completion skills** (`plan-checker`, `nyquist-auditor`, `finishing-a-development-branch`) — verify work before shipping
5. **Operational skills** (`systematic-debugging`, `simplify`, `delegate-to-haiku`) — maintenance and debugging patterns

## Integration
- Skills reference each other (e.g., `assume-analyzer` invokes `spike` for unclear assumptions; `brainstorming` hands off to `write-plans`)
- All skills use consistent agent patterns: explorer (read-only), fixer (write-capable), librarian (research)
- Output from one skill feeds into the next (e.g., `discuss` decisions flow into `assumptions-analyzer`, which flows into planning)
- `delegate-to-haiku` is a cross-cutting pattern used within all skills to keep orchestrator context efficient
