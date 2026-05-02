# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines the six specialist agents that orchestrate delegates to for parallel execution: explorer (search), librarian (docs), oracle (architecture), code-reviewer (quality), designer (UI), fixer (implementation). Each agent is a distinct persona with scoped tools, skills, and off-scope routing rules. The orchestrator (in `orchestrator.md`) is the session manager that coordinates them.

## Design
- **Agent-as-markdown pattern**: Each agent is a single `.md` file with frontmatter (`name`, `description`, `model`, `tools`) + prose role/skills/rules + off-scope routing table.
- **Tool granularity**: Agents declare exactly which tools they can use (Read, Write, Edit, Bash, Grep, Glob, WebSearch, Agent, etc.). Oracle intentionally has `tools: []` (think-only).
- **Skill taxonomy**: Each agent lists required superpowers in order (e.g., fixer: executing-plans → test-driven-development → verification → finishing → requesting-review). Skills are cross-referenced to enable skill-based routing.
- **Off-scope as safety**: Every agent includes an off-scope routing table mapping task types to the correct agent, enforcing specialization boundaries.

## Flow
1. Orchestrator (main session) receives a user request.
2. Orchestrator classifies as simple/medium/heavy/greenfield.
3. For simple: orchestrator edits directly (no agent dispatch).
4. For medium/heavy: orchestrator writes a structured plan, then dispatches `lean-flow:fixer` (haiku, cheap execution).
5. Fixer executes the plan step-by-step, calling sub-agents as needed (explorer for search, librarian for docs, code-reviewer for quality review, oracle for architecture decisions).
6. Explorer, librarian, code-reviewer, designer are always dispatched via the Agent tool; oracle is dispatched by orchestrator or fixer with PR context + diffs.
7. Designer (sonnet, UI specialist) executes frontend tasks on step branches, writes tests, then stops—fixer takes over for PR.
8. Plan-plus-executor is a minimal ephemeral context used for single-step execution with context/ files for sharing discoveries.

## Integration
- **Orchestrator** (`orchestrator.md`) is the hub; it reads this folder to understand which agent to dispatch and what their constraints are.
- **Fixer** (`fixer.md`) is the primary delegated executor for medium/heavy; it may dispatch other agents (explorer, librarian, code-reviewer, designer, oracle) mid-execution via the Agent tool.
- **Explorer** (`explorer.md`) provides cartography (directory mapping) after each fixer/designer commit; orchestrator triggers it to keep codemaps current.
- **Oracle** (`oracle.md`) is think-only (no file tools); it receives summaries from explorer and fixer, returns structured approvals/issues. Used for final PR reviews and unblocking stuck fixers.
- **Code-reviewer** and **designer** are dispatched by fixer for quality/UI review mid-task or by orchestrator for PR feedback loops.
- **Librarian** is on-demand read-only research for library APIs and docs.
- **Plan-plus-executor** is used internally when a plan has been restructured into skeleton + context files; ephemeral and scoped to single steps.
