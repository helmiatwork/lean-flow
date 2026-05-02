# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines nine specialized Claude agents that implement the lean-flow plugin's delegation model. Each agent is a role definition (name, description, model tier, tools, instructions) that the orchestrator dispatches for specific task types: code review (code-reviewer), frontend polish (designer), pre-work scoping (discuss), codebase exploration (explorer), core implementation (fixer), documentation lookup (librarian), architecture decisions (oracle), main session coordination (orchestrator), and single-step execution (plan-plus-executor).

## Design
- **Agent registry pattern**: Each `.md` file is a self-contained agent definition (YAML frontmatter + markdown instructions). No code objects — purely declarative role specs.
- **Tool-based capability gating**: Each agent declares `tools: [...]` to restrict what it can do (e.g., `oracle` has `tools: []` to enforce think-only behavior; `fixer` has full Read/Write/Bash to execute end-to-end chains).
- **Skill inheritance**: Agents reference superpowers via `superpowers:*` and plugin-scoped capabilities (e.g., `lean-flow:cartography`). Orchestrator maps these to actual implementations.
- **Tier stratification**: Agents span cost/quality spectrum: haiku (explorer, fixer, librarian — fast/cheap), sonnet (code-reviewer, designer, oracle — richer thinking), opus (orchestrator — top-level reasoning).

## Flow
1. **Orchestrator** (opus, main session) receives user task.
2. **Classifier** (STAR) routes to tier: simple (do it) / medium / heavy / greenfield / hotfix.
3. For medium/heavy: orchestrator dispatches **discuss** (sonnet) if scope is ambiguous, then **fixer** (haiku) with exact plan.
4. **Fixer** executes steps, writes code/tests, runs linters, creates PR.
5. **Fixer** dispatches **code-reviewer** (sonnet) + **oracle** (sonnet) in parallel for PR review.
6. **Code-reviewer** checks diff-level quality (SOLID, patterns, coverage). **Oracle** checks architecture/security.
7. **Explorer** (haiku) handles parallel codebase searches; **librarian** (haiku) handles API/docs lookups.
8. **Designer** (sonnet) handles frontend work; stops before PR (fixer takes over PR management).
9. **Plan-plus-executor** (inherit tier) runs single ephemeral steps from skeleton plans.

## Integration
- **Orchestrator** reads all agent definitions to map dispatches (e.g., `Agent("lean-flow:fixer", {...})` with plan payload).
- **Fixer** calls **code-reviewer** and **oracle** as subagents during PR review loop.
- **Fixer** dispatches **explorer** post-commit to update codemaps.
- **Oracle** receives summaries from **explorer** (never reads files itself).
- All agents reference shared superpowers (e.g., `superpowers:executing-plans`, `superpowers:test-driven-development`) defined in plugin capability registry.
- Agent YAML frontmatter (`name`, `description`, `model`, `tools`, `color`) is machine-parseable for UI rendering and dispatch logic.
