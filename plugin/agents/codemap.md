# plugin/agents/

# codemap.md for `plugin/agents/`

## Responsibility
This directory defines all lean-flow agent specifications. Each `.md` file is a canonical agent contract: role, required skills, tools, delegation rules, and execution constraints. The orchestrator reads these to understand which agent to dispatch and when.

## Design
- **Agent-as-spec pattern**: Each agent (`fixer`, `designer`, `oracle`, etc.) is a role + skill mapping + tool list + workflow rules in one `.md` file. No shared code — pure declarative specs.
- **Skill-based dispatch**: Agents are selected by required superpowers (e.g., `superpowers:executing-plans` → fixer) and tools (Read/Write for fixer, `tools: []` for oracle).
- **Hierarchical execution**: Orchestrator (opus) → dispatches haiku/sonnet specialists → specialists may spawn sub-agents (fixer spawns code-reviewer + oracle) per hard contracts.
- **Read-only vs full-write tiers**: explorer/librarian/oracle are read-only or think-only (haiku/sonnet). Fixer/designer have full Read/Write/Bash (haiku/sonnet). Orchestrator (opus) does simple tier work directly.

## Flow
1. User submits task → orchestrator classifies (simple/medium/heavy)
2. **Simple**: orchestrator edits directly
3. **Medium/Heavy**: orchestrator writes plan → dispatches fixer (haiku) with exact steps
4. **Fixer executes plan**: write code → test → lint → commit → push → create PR → dispatch code-reviewer + oracle → apply feedback → merge
5. **Designer (sonnet)**: invoked by fixer for UI/UX steps, writes to branch, stops before PR (fixer takes PR responsibility)
6. **Explorer/Librarian (haiku)**: dispatched in parallel for codebase discovery, docs lookup, pre-oracle prep
7. **Oracle (sonnet, think-only)**: receives summaries from explorer/fixer, returns APPROVED or issues, never reads/writes files

## Integration
- **Orchestrator** (`orchestrator.md`) is the main session; reads all agent specs to decide dispatch rules
- **Fixer** (`fixer.md`) is the workhorse; reads explorer/librarian summaries, executes plans, spawns code-reviewer + oracle inline
- **Code-reviewer** (`code-reviewer.md`) reviews diffs for SOLID/patterns/coverage before oracle's architecture review
- **Oracle** (`oracle.md`) synthesizes explorer's codebase scans and fixer's diffs; decides architecture fitness and security
- **Designer** (`designer.md`) handles UI/UX steps in fixer-dispatched plans; commits to branch, fixer manages PR
- **Explorer** (`explorer.md`) is dispatched pre-plan for codebase discovery, and post-commit for cartography updates
- **Librarian** (`librarian.md`) looks up library/framework docs; no dispatch rule in workflow, called ad-hoc by orchestrator/fixer
- **Discuss** (`discuss.md`) scopes ambiguous tasks pre-work; optional, triggered by orchestrator before dispatching fixer
- **Plan-plus-executor** (`plan-plus-executor.md`) is an ephemeral focused executor for structured plan steps; used by orchestrator as a lighter-weight alternative to fixer for isolated step work
