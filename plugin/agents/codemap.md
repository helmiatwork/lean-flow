# plugin/agents/

# plugin/agents/ Codemap

## Responsibility
This directory defines the lean-flow plugin's seven specialized agent roles. Each agent is a Claude prompt template (`*.md`) that describes a specific responsibility: code review (code-reviewer), UI/UX implementation (designer), pre-work scoping (discuss), codebase navigation (explorer), primary code execution (fixer), documentation lookup (librarian), think-only architecture review (oracle), orchestration (orchestrator), and single-step execution (plan-plus-executor). Together they form a delegation system for the main orchestrator to route tasks efficiently by cost, speed, and quality.

## Design
- **Agent as Markdown**: Each agent is defined in a frontmatter-plus-body `.md` file. Frontmatter (`name`, `description`, `model`, `tools`) specifies the agent's identity, dispatch trigger, LLM size, and tool access. Body contains the agent's full system prompt (role, skills, rules, checklist).
- **Tool-gated permissions**: Each agent declares `tools: []` (oracle: no file/shell access) or `tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent", "WebSearch", "WebFetch"]` (fixer/designer: full write). Explorer, librarian, oracle are read-only or think-only by design.
- **Skill declarations**: Agents declare required superpowers (e.g., `superpowers:executing-plans`, `superpowers:test-driven-development`) to signal what orchestrator must verify before dispatch.
- **Hard constraints**: Fixer has explicit end-to-end contracts (steps 1–12); oracle has hard prohibitions (never Write/Edit/Bash); designer never opens PRs. Code-reviewer always runs before oracle on parent→main PRs.

## Flow
1. **Orchestrator classifies** a user task into simple/medium/heavy/greenfield/hotfix.
2. **Simple tasks**: Orchestrator edits directly; no agent dispatch.
3. **Medium/heavy tasks**: Orchestrator writes a structured plan with exact code/paths/commands, then dispatches `lean-flow:fixer` with the plan.
4. **Parallel discovery** (if needed): Orchestrator dispatches `lean-flow:explorer` to scan, `lean-flow:librarian` to research, `lean-flow:discuss` to scope ambiguities — results feed back to orchestrator before fixer dispatch.
5. **Fixer execution**: Fixer executes plan steps, writes tests, runs linters, commits, pushes, creates PR.
6. **Code review chain**: Fixer dispatches `lean-flow:code-reviewer` (sonnet) for diff-level quality, then `lean-flow:oracle` (sonnet, think-only) for architecture/security. Fixer applies feedback, re-runs tests/linters, loops until both APPROVED (max 3 combined rounds; escalate on round 4).
7. **Merge**: Once CI is green and oracle is APPROVED, fixer merges with `gh pr merge --squash`.
8. **Cartography**: After fixer commits, orchestrator dispatches `lean-flow:explorer` to fill affected `codemap.md` templates (Tier 2 cheap update; Tier 1 conditional if structural changes).

## Integration
- **Orchestrator** (never a subagent; the main session) reads all agent `.md` files to understand available specializations and rules
