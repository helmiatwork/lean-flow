# plugin/agents/

# `plugin/agents/` Codemap

## Responsibility
Nine specialized agent definitions that implement the lean-flow plugin's delegation model. Each agent has a distinct role: orchestrator coordinates work; fixer executes code changes; designer handles UI/UX; code-reviewer enforces quality; oracle makes architectural decisions; explorer discovers unknowns; librarian researches libraries; discuss scopes ambiguous tasks; plan-plus-executor runs individual plan steps in isolation.

## Design
Each agent is a Markdown file defining:
- **Metadata** (`name`, `description`, `model`, `tools`) — controls dispatch, model selection, and capability enforcement
- **Required Skills** — superpowers or tool specializations the agent applies
- **Role & Rules** — concrete scope boundaries and execution constraints
- **Off-scope Routing** — table mapping out-of-scope tasks to correct agent with re-dispatch format
- **Contracts/Checklists** — fixer/code-reviewer/oracle define end-to-end execution contracts; explorer/librarian define read-only discovery contracts

Key abstractions: **tools: [] enforcement** (oracle cannot edit/bash), **haiku cost optimization** (fixer/explorer/librarian use cheaper model), **diff-range incremental review** (code-reviewer/oracle support rounds 2+ with carried-over findings), **PR comment contracts** (code-reviewer/oracle use `gh` CLI for direct PR feedback).

## Flow
1. **Orchestrator** (orchestrator.md) receives user prompt → classifies tier (simple/medium/heavy) → plans work with exact code paths
2. **Dispatch to specialist** → fixer executes full E2E chain (impl → test → lint → PR → review loop); designer handles UI; explorer searches; librarian researches; oracle reviews architecture
3. **Code review cycle** (fixer.md §9–10) → dispatch code-reviewer (diff scan) → dispatch oracle (architecture) → loop until both `APPROVED` (max 3 rounds)
4. **Merge** → orchestrator waits for CI green, oracle issues final GitHub PR approval, fixer merges with `--squash`
5. **Context management** → plan-plus-executor handles isolated step execution with ephemeral context files in `context/` directory

## Integration
- **Orchestrator entry point** — orchestrator.md defines delegation logic; STAR classifier (UserPromptSubmit hook) routes tiers
- **Agent dispatch** — orchestrator uses Agent tool to spawn fixer/designer/explorer/librarian/oracle/discuss/plan-plus-executor as subagents
- **PR feedback loop** — code-reviewer and oracle post GitHub PR comments via `gh` CLI; fixer applies feedback and re-dispatches them
- **Codemap updates** — explorer fills `codemap.md` templates after fixer commits; orchestrator triggers explorer after each commit via `git diff --name-only`
- **Skills MCP** — agents reference superpowers (executing-plans, test-driven-development, etc.) defined in skills registry; CLAUDE.md maps superpowers to these agent definitions
