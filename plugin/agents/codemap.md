# plugin/agents/

# codemap.md

## Responsibility
The `plugin/agents/` directory defines specialized agent personas for the lean-flow plugin orchestration system. Each agent is a focused Claude instance (via `Agent` tool) with specific capabilities, tools, and role constraints. The orchestrator dispatches agents based on task classification — agents are NOT invoked as subagents by each other, only by the main orchestrator session.

## Design
- **Agent-per-role pattern**: Each `.md` file declares one agent persona with `name`, `description`, `model` (claude-3-5-sonnet, haiku, opus), and `tools` array. The agent's instructions are in the file body.
- **Skill/capability declarations**: Agents declare required superpowers (e.g., `superpowers:executing-plans`, `frontend-design:frontend-design`) that map to orchestrator's knowledge base.
- **Off-scope routing rules**: Every agent includes an identical routing table redirecting out-of-scope tasks to the correct agent (e.g., code-reviewer routes frontend tasks to designer). Format: `OFF-SCOPE: dispatch to <agent> — <brief>`.
- **Tool restrictions by agent**: Read-only agents (explorer, librarian, code-reviewer) lack Write/Edit; oracle has no tools at all (think-only); fixer and designer are full-capability.
- **Hard constraints documented inline**: Fixer's 3-round review cap, oracle's prohibition on file/shell tools, designer's stop-before-PR rule.

## Flow
1. **Orchestrator receives user task** → classifies via STAR (simple/medium/heavy) → routes per tier.
2. **For medium/heavy tasks**: Orchestrator writes a structured plan with exact code/paths/commands, optionally dispatches explorer/librarian/discuss for pre-work, then **dispatches fixer with the plan** as the execution contract.
3. **Fixer executes the plan end-to-end**: implements → tests → linters → commits → PR → dispatches code-reviewer (sonnet, diff-level quality) → dispatches oracle (sonnet, architecture/security) → applies feedback loops (max 3 combined rounds) → merges CI-green PR.
4. **After merge**: Explorer cartographer updates affected `codemap.md` templates, oracle decides if Tier 1 (docs/CODEBASE_MAP.md) needs update.
5. **Designer and oracle never write code** — designer commits to branch, fixer opens PR; oracle only thinks and advises.

## Integration
- **With orchestrator**: Agents are invoked via `Agent` tool in prompts; orchestrator owns the dispatch logic, plan creation, and verification loops. Agents report findings/status back to orchestrator, which continues the session.
- **With each other**: Agents don't call agents — only orchestrator dispatches. Code-reviewer and oracle are run sequentially on the same PR (code-reviewer first, oracle second). Explorer pre-work (codebase maps, diff scans) feeds into oracle's summaries.
- **With plugin infrastructure**: Agents read `CLAUDE.md` for project context, follow project-specific patterns detected in existing code, and respect pre-commit hooks (no Co-Authored-By attribution).
- **With CI/codemap system**: Fixer pushes branches; explorer runs cartographer.py changes to populate affected `codemap.md` stubs; oracle flags structural changes for Tier 1 docs update.
