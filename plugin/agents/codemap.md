# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility

Houses the lean-flow plugin's specialized agent contracts. Each agent file (`*.md`) defines a single agent's role, required skills, tools, off-scope routing rules, and execution constraints. The orchestrator dispatches to these agents based on task classification and workflow stage. Together they implement a cost-optimized, quality-focused division of labor for code generation, review, and architecture decisions.

## Design

- **Agent contract pattern**: Each `*.md` file is a system-prompt template + role definition. No shared code; each agent is a distinct Claude model instance with its own tools and behavioral rules.
- **Skill-based dispatch**: Agents declare required superpowers (`superpowers:*` and domain-specific skills) and off-scope routing rules. Orchestrator routes work based on skill match and task type.
- **Read-only vs edit split**: Explorer, librarian, code-reviewer are read-only (cheaper, fast). Fixer and designer are write-capable. Oracle is think-only (no tools).
- **Hard prohibitions**: Each agent file documents what it must *not* do (e.g., oracle never writes code, designer never opens PRs, explorer never edits).

## Flow

1. **User submits task** → Orchestrator classifies (simple/medium/heavy)
2. **Simple tier**: Orchestrator edits directly
3. **Medium/heavy tier**:
   - Orchestrator may dispatch `discuss` for scope clarification (multiple choice options)
   - Orchestrator dispatches `explorer` for codebase discovery (read-only, parallel)
   - Orchestrator dispatches `librarian` for doc/API lookup (optional, read-only)
   - Orchestrator writes structured **plan** with exact code + paths
   - Orchestrator dispatches `fixer` (haiku) to execute plan end-to-end
4. **Review phase** (parent → main PRs only):
   - Fixer dispatches `code-reviewer` (sonnet) for diff-level quality
   - Fixer dispatches `oracle` (sonnet, think-only) for architecture + final verdict
   - Fixer applies feedback, loops until both APPROVED (hard cap: 3 rounds)
   - Oracle gates codemap update decision
5. **Frontend work**: Designer (sonnet) executes UI/UX steps, fixer takes over for PR management

## Integration

- **Orchestrator** (main session, `orchestrator.md`) coordinates all agents via the Agent tool and embeds this folder's contracts as system context
- **Fixer** (`fixer.md`) spawns code-reviewer and oracle as subagents, applies their feedback, manages CI and merge
- **Designer** (`designer.md`) executes frontend steps on branches; fixer takes over for PR lifecycle
- **Explorer** (`explorer.md`) runs post-commit via orchestrator trigger to fill/update codemaps after each fixer/designer push
- **Plan-plus-executor** (`plan-plus-executor.md`) is a lightweight ephemeral agent for executing single plan steps with isolated context
