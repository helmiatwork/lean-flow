# plugin/agents/

# codemap.md: `plugin/agents/`

## Responsibility
Defines the lean-flow agent specializations that the orchestrator dispatches for code tasks. Each agent file (markdown) declares a single agent's role, required skills (superpowers), tools, model, and execution rules. The orchestrator reads these files to understand delegation boundaries and cost/quality trade-offs.

## Design
- **Agent pattern**: Each `.md` file is a self-contained agent spec with frontmatter (name, description, model, tools) + detailed instructions.
- **Skill-driven dispatch**: Agents declare required superpowers (e.g., `superpowers:executing-plans`, `frontend-design:frontend-design`) that map to agent capabilities. Orchestrator matches task type to agent superpowers.
- **Read-only vs. execution split**: Explorer, Librarian, Oracle have restricted tools (no Write/Edit). Fixer, Designer handle state changes. Code-reviewer is read-only for diff analysis.
- **Cost optimization**: Haiku agents (Explorer, Librarian, Fixer) handle parallel searches and mechanical work. Sonnet agents (Oracle, Designer, Code-Reviewer) handle complex reasoning and UX decisions.
- **Hard prohibitions**: Oracle has `tools: []` — enforces think-only architecture. Fixer has explicit hard-cap rules (3 review rounds max, no `--no-verify`, no AI attribution in commits).

## Flow
1. **Orchestrator receives task** → classifies via STAR (simple/medium/heavy/greenfield/hotfix).
2. **Simple tier**: Orchestrator edits directly.
3. **Medium/heavy tier**: Orchestrator writes plan → dispatches `lean-flow:fixer` (haiku) to execute full end-to-end chain (impl → tests → linters → commit → PR → code-reviewer → oracle → merge).
4. **Parallel specialists**: Fixer may dispatch Explorer (search), Librarian (docs), Designer (UI), or Code-Reviewer (diff review) as needed. Oracle is dispatch-only by Orchestrator for architecture/security gates.
5. **Feedback loops**: Code-Reviewer and Oracle return issues; Fixer routes to appropriate agent (IssueRoutingRules) and re-runs checks.

## Integration
- **Orchestrator** (`orchestrator.md`) reads and coordinates all agents in this folder.
- **Plan-plus-executor** (`plan-plus-executor.md`) is a lightweight single-step executor that shares the same tool/skill model but is context-ephemeral; used for structured multi-step plans.
- **Codemap cartography**: Explorer fills `codemap.md` templates per folder after commits; Oracle synthesizes explorer scans into `docs/CODEBASE_MAP.md` Tier 1 entries.
- **Skills registry**: Each agent's required superpowers must exist in the global skills system (referenced in CLAUDE.md or agent-skill mappings); unknown superpowers block agent dispatch.
