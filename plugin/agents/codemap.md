# plugin/agents/

# codemap.md for `plugin/agents/`

## Responsibility
Defines specialized agent personas that the orchestrator dispatches for focused work: code review, design, discussion, exploration, implementation, research, architecture, and plan execution. Each agent file documents role, required skills, tools, and constraints.

## Design
- **Agent separation by concern**: explorer (search), librarian (docs), fixer (implementation), designer (UI), code-reviewer (quality), oracle (architecture), discuss (scoping), plan-plus-executor (step execution)
- **Skill-based dispatch**: orchestrator matches task type to agent via superpowers (e.g., `superpowers:test-driven-development`, `lean-flow:cartography`)
- **Model/cost optimization**: haiku (fast/cheap) for explorer/librarian; sonnet for oracle/code-reviewer/designer; opus for orchestrator only
- **Tool constraints**: oracle has `tools: []` (think-only); designer/fixer have write access; explorer/librarian are read-only

## Flow
1. Orchestrator classifies task (simple/medium/heavy) → picks agent(s) to dispatch
2. Agents execute in parallel or sequence per orchestrator's plan
3. Explorer scans before planning; librarian researches unknowns; discuss locks scope; fixer implements with TDD; designer polishes UI; code-reviewer audits diffs; oracle reviews PRs and architecture
4. Fixer owns full merge chain: implement → test → lint → commit → push → PR → dispatch reviewers → apply feedback → CI → merge
5. plan-plus-executor runs ephemeral single-step work, updates context files, reports back to main thread

## Integration
- **orchestrator.md** routes work to agents based on capability and cost
- **fixer.md** coordinates code-reviewer + oracle via `Agent` tool (step 9–10 of end-to-end contract)
- **explorer.md** feeds codebase summaries to oracle and fixer
- **discuss.md** gates ambiguous tasks before fixer/designer start
- **designer.md** hands off to fixer for PR management (never opens PRs itself)
- All agents return structured reports (summaries, file paths, actionable feedback) for orchestrator to synthesize
