# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines nine specialized agent roles for the lean-flow plugin orchestrator. Each agent file (e.g., `fixer.md`, `explorer.md`, `oracle.md`) documents a single agent's purpose, required superpowers, permissions, and operational rules. Together they form a division-of-labor model: orchestrator classifies work → delegates to appropriate agent(s) → agent executes within its scope → result feeds back to orchestrator or user.

## Design
- **Agent-as-spec pattern:** Each `.md` file is a YAML frontmatter + Markdown spec. Frontmatter declares `name`, `description`, `model` (haiku/sonnet/opus), and `tools` (list of available MCPs). Body documents role, required skills (superpowers), rules, and end-to-end contract (for fixer) or workflow (for orchestrator).
- **Specialization by cost/speed:** Haiku agents (explorer, librarian, fixer) handle fast search/impl; sonnet agents (code-reviewer, designer, oracle) handle synthesis/review; opus orchestrator (orchestrator.md) handles delegation logic.
- **Permission boundaries:** Oracle has `tools: []` (think-only); explorer/librarian are read-only; fixer/designer have write; orchestrator has full toolset for dispatch.
- **Superpowers as skill contracts:** Each agent lists required superpowers (e.g., `superpowers:executing-plans`, `superpowers:test-driven-development`) — these map to learned behaviors in the plugin's LLM fine-tuning or prompt injection layer.

## Flow
1. User submits task → orchestrator classifies (simple/medium/heavy/greenfield/hotfix).
2. Simple: orchestrator edits directly.
3. Medium/heavy: orchestrator runs `lean-flow:discuss` (discuss.md) for scope confirmation, then writes a structured plan.
4. Orchestrator dispatches appropriate agent(s):
   - `explorer.md`: Pre-work discovery (file locations, codebase map, diff summaries for oracle).
   - `librarian.md`: API/docs research (WebSearch, Context7 MCP for current library docs).
   - `fixer.md`: End-to-end implementation (code, tests, commits, PR, code-reviewer/oracle dispatch, merge).
   - `designer.md`: UI/UX polish (components, styling, a11y, tests — stops before PR).
   - `code-reviewer.md`: Code-quality/SOLID/coverage review (diff-level, before oracle on parent→main PRs).
   - `oracle.md`: Architecture/security/design review (think-only, receives summaries from explorer, returns APPROVED or issues).
5. Agent executes, reports completion or blockers.
6. Fixer loops: code-reviewer → apply fixes → oracle → apply fixes → CI gate → merge. Max 3 combined rounds before escalation.
7. Post-merge: explorer scans changed folders, fills `codemap.md` templates (hybrid cartography, § 12a).

## Integration
- **Orchestrator hub:** `orchestrator.md` documents the orchestrator role and agent dispatch rules — it is the canonical reference for delegation logic, not invoked as a subagent itself.
- **Plan contract:** `fixer.md` executes plans written by orchestrator in step-by-step detail (files, line numbers, exact
