# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Agent definitions for the lean-flow plugin's specialization system. Each `.md` file defines a single agent's role, required skills, tools, model tier, and execution contract. The orchestrator uses these definitions to classify tasks, route work to appropriate agents, and verify completion.

## Design
Each agent file follows a consistent YAML frontmatter + markdown body pattern:
- **Frontmatter** (`name`, `description`, `model`, `tools`, optional `color`) — metadata for orchestrator dispatch
- **Superpowers** — named skill requirements (e.g., `superpowers:test-driven-development`) that ground execution contracts
- **Role** — high-level job description
- **Rules** — constraints and guardrails (what the agent must/must-not do)
- **Execution contract** — for complex agents (fixer, code-reviewer), detailed step-by-step workflow and done checklists

Key agents:
- **orchestrator.md** — main session coordinator; never spawned as subagent; routes classify → plan → dispatch → verify
- **fixer.md** (haiku) — primary implementation; owns end-to-end: code, tests, linters, commits, PR, code-reviewer + oracle loops, merge
- **code-reviewer.md** (inherit) — diff-level quality review (SOLID, patterns, coverage, naming); separate from oracle's architecture role
- **oracle.md** (sonnet) — think-only architect; receives summaries from explorer/fixer; `tools: []`; returns APPROVED or issues
- **designer.md** (sonnet) — UI/UX specialist; 90% component coverage, accessibility, responsive; stops before PR (fixer takes over)
- **explorer.md** (haiku) — read-only codebase scanner; cartography specialist; pre-oracle prep; parallel search 2x faster
- **librarian.md** (haiku) — read-only doc/API lookup; Context7 MCP + WebSearch for current library behavior
- **discuss.md** (sonnet) — pre-work scoping; surfaces 3–5 decision areas as AI-recommended multiple choice; locks scope before execution
- **plan-plus-executor.md** (inherit) — focused single-step executor for plan-plus structured plans; ephemeral context; updates `context/` files

## Flow
1. **Classify** (orchestrator) — STAR tier every prompt (simple/medium/heavy/greenfield/hotfix)
2. **Plan** (orchestrator, medium+) — write structured execution plan with exact paths, code, commands
3. **Dispatch** (orchestrator) — route to fixer (+ optional parallel explorer, librarian, oracle)
4. **Execute** (fixer, designer, or plan-plus-executor) — implement, test, lint, commit, push
5. **Review** (code-reviewer, then oracle) — approve or return issues; fixer loops until both APPROVED
6. **Merge** (fixer) — CI gate + codemap update + merge to main

Optional pre-dispatch gates:
- **discuss** — clarify ambiguous scope (user confirms choices before fixer starts)
- **explorer** — discover unknowns in parallel (search-and-summarize before planning)
- **librarian** — research unfamiliar APIs before planning (Context7 MCP + WebFetch)

## Integration
- **orchestrator.md** — references all other agents;
