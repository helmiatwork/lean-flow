# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines nine specialized agent personas for the lean-flow orchestration system. Each agent is a Claude prompt template with specific capabilities, constraints, and skills that the orchestrator (main session) dispatches for focused work. Agents are not interdependent — orchestrator routes tasks to them based on work type (explore, research, implement, review, architect, design, scope, execute single step).

## Design
Each agent is a standalone Markdown file with YAML frontmatter (name, description, model, tools) followed by role definition, required skills, rules, and execution contract. The nine agents are organized by function:
- **Read-only discovery:** explorer (codebase nav, ~haiku), librarian (docs/API lookup, haiku)
- **Decision-makers:** oracle (architecture/security, think-only sonnet), code-reviewer (quality/SOLID, sonnet)
- **Executors:** fixer (all code changes, haiku), designer (UI/UX impl, sonnet), plan-plus-executor (single-step plan work, inherit model)
- **Preparation:** discuss (pre-work scoping, sonnet)
- **Meta:** orchestrator (main session reference, opus — not spawned as subagent)

No shared state between agents; all coordination via orchestrator's prompt context.

## Flow
1. Orchestrator classifies task → selects agent(s) to dispatch via `Agent` tool
2. Explorer/librarian do read-only research → return summaries to orchestrator
3. Orchestrator synthesizes summaries → feeds to oracle or fixer
4. Fixer executes plan steps → spawns code-reviewer + oracle for PR review → applies feedback → merges
5. Designer runs in parallel with fixer for UI work → commits to step branch, fixer opens PR
6. Discuss validates ambiguous scope before any agent starts work
7. plan-plus-executor runs ephemeral steps with isolated context files

## Integration
- All agents invoked via orchestrator's `Agent` tool with structured prompts
- Agents never invoke each other directly (orchestrator mediates)
- Read-only agents (explorer, librarian, code-reviewer) feed findings to thinking agents (oracle, fixer, designer)
- Fixer is the only agent that manages PR lifecycle (create, request reviews, apply feedback, merge)
- Oracle's post-approval triggers hybrid codemap update (explorer fills `codemap.md`, fixer writes)
- All agents conform to `CLAUDE.md` global rules and skill definitions from `skills/` directory
