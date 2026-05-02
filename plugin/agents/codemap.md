# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines the specialized agent roles that execute within the lean-flow orchestration system. Each agent has a distinct contract, permission level, and trigger rule. The orchestrator dispatches agents based on task classification and dependencies.

## Design
**Agent contract pattern**: Each agent is a YAML frontmatter + markdown spec defining:
- `name`, `description`, `model` (haiku/sonnet/opus), `tools` (permitted MCP/tool set)
- **Required Skills**: ordered superpowers (mandatory competencies)
- **Role & Rules**: scope, constraints, off-scope routing
- **Hard prohibitions** or **End-to-End Execution Contract** (if agent owns a full workflow)

**Key abstractions**:
- **Dispatch gate** (`OFF-SCOPE:` return format): agents reject out-of-scope tasks with structured re-dispatch instructions
- **Haiku vs Sonnet tiers**: haiku agents (explorer, librarian, fixer) cost less; sonnet agents (oracle, code-reviewer, designer, discuss) provide deeper reasoning
- **Read-only vs Edit permission**: explorer/librarian/oracle are read-only (no Write/Edit/Bash); fixer/designer/code-reviewer can edit; orchestrator is unrestricted

## Flow
1. **Orchestrator** classifies task (simple/medium/heavy) → triggers **discuss** (if ambiguous scope)
2. **Discuss** locks decisions → orchestrator plans
3. **Orchestrator** dispatches **fixer** (+ optional **designer** for UI) with plan
4. **Fixer/designer** execute steps, write code, run tests, commit
5. **Fixer** creates PR → dispatches **code-reviewer** (diff-level quality) → **oracle** (architecture/final verdict)
6. **Oracle/code-reviewer** approve or return issues → **fixer** applies fixes, loops
7. **Explorer** scans changed folders post-commit → updates codemaps (cartography pass)

**Agent independence rule**: each agent can be dispatched independently or chained; orchestrator manages sequencing and context passing.

## Integration
- **Orchestrator** (not in this folder; main session) reads these specs via `Agent` MCP to dispatch subagents
- **Off-scope routing** creates feedback loops: if fixer finds a security issue, it re-dispatches to oracle; if designer finds a perf issue, it re-dispatches to oracle
- **Cartography pass** (explorer post-commit) feeds into `docs/CODEBASE_MAP.md` updates via fixer writes
- **Context flow**: orchestrator passes summaries to oracle (never direct file reads); explorer reads files → produces summaries for oracle/code-reviewer
- **PR workflow**: fixer owns the full chain but delegates reviews (code-reviewer for SOLID/patterns, oracle for architecture); both must APPROVE before merge
