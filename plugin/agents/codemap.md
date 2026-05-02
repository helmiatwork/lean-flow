# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Lean-flow specialist agent definitions. Each `.md` file is a contract defining a single agent's role, constraints, skills, off-scope routing, and tool access. Agents are Claude instances with different model sizes, tool permissions, and behavioral guidelines — used by the orchestrator to delegate tasks by type (code review, architecture, search, implementation, research, UI, scoping).

## Design
- **Contract-driven dispatch**: Each agent's `.md` is a system-context file injected into Claude at runtime. No runtime code — pure declarative contracts.
- **Tool-gated permissions**: Each agent declares `tools: []` in frontmatter; orchestrator enforces which agent runs which task based on tool availability and scope.
- **Off-scope routing**: Every agent includes an off-scope table and returns `OFF-SCOPE: dispatch to <agent> — <brief>` if work falls outside its contract.
- **Cost/speed tiers**: haiku agents (explorer, librarian, fixer) for fast/cheap search and execution; sonnet agents (code-reviewer, oracle, designer) for quality reasoning.
- **Skill injection**: Each agent declares required superpowers (e.g., `superpowers:test-driven-development`, `frontend-design:frontend-design`) — orchestrator verifies availability before dispatch.

## Flow
1. Orchestrator classifies task → determines agent(s) needed (explorer for search, librarian for docs, fixer for code, code-reviewer/oracle for review).
2. Orchestrator reads agent contract (e.g., `fixer.md`) → extracts role, rules, required skills, tool list.
3. Orchestrator injects contract as system context → instantiates agent → passes task.
4. Agent reads contract rules → executes work within constraints → returns result or `OFF-SCOPE` dispatch instruction.
5. On off-scope: orchestrator parses return string → re-dispatches to named agent.
6. Agent reports back: work done, files changed, any blockers.

## Integration
- **orchestrator.md**: Documents the main session; references all agents, decision rules for delegation (when to dispatch vs. do-it-yourself), and Tier routing (simple/medium/heavy).
- **Tier execution**: Fixer (`fixer.md`) owns end-to-end chain on medium/heavy tasks (implement → test → lint → commit → PR → code-reviewer → oracle → merge); designer (`designer.md`) stops before PR (fixer takes over).
- **Code review chain**: On parent → main PRs, code-reviewer runs first (diff-level quality), then oracle (architecture); both must return APPROVED before merge (§9–10 in fixer.md).
- **Explorer dispatch**: After fixer/designer commits, orchestrator auto-dispatches explorer (`explorer.md`) to update affected `codemap.md` files (cartography rule).
- **Off-scope cascade**: If an agent receives out-of-scope work, it returns a re-dispatch instruction; orchestrator reads it and re-instantiates the correct agent mid-conversation.
