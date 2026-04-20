# plugin/agents/

# Codemap: `plugin/agents/`

## Responsibility
Defines the agent personas and capabilities for the lean-flow plugin orchestration system. Each `.md` file is an agent specification that describes role, tools, decision rules, and workflow constraints. Agents are dispatched by the orchestrator based on task type and complexity.

## Design
- **Agent-as-spec pattern**: Each agent is a declarative profile (YAML frontmatter + markdown rules), not code. The orchestrator reads these specs to select and prompt agents.
- **Role segregation by expertise**: Designer (UI/UX), Discuss (scoping), Explorer (read-only navigation), Fixer (implementation), Librarian (research), Oracle (architecture review), Plan-Plus-Executor (plan step execution). Each has explicit tool restrictions to prevent cross-cutting work.
- **Hard prohibitions**: Oracle has `tools: []` (think-only); Explorer and Librarian are read-only; Designer focuses frontend; Discuss blocks implementation until scope is locked.
- **Spec + Rules pattern**: Each agent file pairs capability declaration (YAML) with detailed operational rules (markdown sections like Role, Rules, Step-by-step flows, Checklists).

## Flow
1. **Orchestrator reads agent spec** from this directory (e.g., `discuss.md` for scoping)
2. **Agent is dispatched** with its declared tools and role context
3. **Agent executes workflow** following its Rules section (e.g., Discuss: analyze → generate options → present → capture → confirm → hand off)
4. **Agent returns structured output** (decisions locked, code changes, findings, diagnosis)
5. **Orchestrator chains agents** (e.g., Discuss → Fixer → Oracle review → codemap update)

## Integration
- **Orchestrator** reads these specs to instantiate agents with correct model, tools, and system prompts
- **Plan-Plus-Executor** inherits tool set from assigned plan step context
- **Explorer** scans codebase to feed Oracle (architecture) and Fixer (implementation context)
- **Fixer** implements changes and reports to Oracle for review
- **Oracle** outputs guidance that Fixer executes; also triggers codemap updates via `cartographer.py`
- **Designer** and **Librarian** are optional specialists called when UI/research work is in scope
