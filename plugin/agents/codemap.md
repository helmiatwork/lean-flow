# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility
Defines nine specialized agent personas for the lean-flow plugin, each optimized for a specific type of work in the development cycle. The orchestrator dispatches these agents based on task classification (simple/medium/heavy) and required skillset. Each agent is a Claude model instance with scoped permissions and required superpowers.

## Design
- **Agent-per-concern pattern**: Each `.md` file defines one agent with distinct role, required skills, tools, model size, and hard constraints
- **Skill-based dispatch**: Agents declare mandatory superpowers (e.g., `superpowers:test-driven-development`, `superpowers:receiving-code-review`) that orchestrator matches to task requirements
- **Model-cost tradeoffs**: Haiku agents (explorer, librarian, fixer) handle parallel search/execution; Sonnet agents (oracle, code-reviewer, designer) handle complex reasoning; Opus reserved for orchestrator only
- **Tool restrictions**: Read-only agents (explorer, librarian, oracle) prevent accidental writes; executor agents (fixer, designer) have edit permissions bounded by plan constraints
- **End-to-end contracts**: Fixer and designer document full execution chains (TDD → tests → linters → PR → reviews → merge), not single-step work

## Flow
1. **Orchestrator receives task** → classifies via STAR (simple/medium/heavy)
2. **Simple tasks**: Orchestrator executes directly
3. **Medium/heavy tasks**: Orchestrator writes plan, dispatches `fixer` (haiku) with exact code/paths/commands
4. **During execution**: Fixer may spawn `code-reviewer` (sonnet) for diff review, `oracle` (sonnet) for architecture review, `designer` (sonnet) for UI work
5. **Pre-work research**: Dispatch `explorer` (haiku) for codebase discovery or `librarian` (haiku) for API docs before planning
6. **Post-merge**: `explorer` fills codemaps from changed folders; `oracle` decides if `docs/CODEBASE_MAP.md` (Tier 1) needs update
7. **Stuck escalation**: If fixer fails 3+ times, dispatch `oracle` for diagnosis; if still blocked after oracle, human intervention

## Integration
- **Orchestrator** (main session, not an agent file) reads this folder to understand dispatch rules and agent capabilities
- **Superpowers MCP**: Each agent declares required superpowers (defined in `/plugin/superpowers/`) that must exist
- **Skill mappings**: `code-reviewer.md` → `superpowers:receiving-code-review` + `superpowers:verification-before-completion`; `fixer.md` → `superpowers:executing-plans` + `superpowers:test-driven-development` + (3 more)
- **PR workflow**: `fixer.md` owns full chain; spawns `code-reviewer` then `oracle` in sequence; both must `APPROVED` before merge (hard cap 3 rounds)
- **Cartography**: `explorer.md` runs per-commit after fixer/designer pushes; fills `codemap.md` templates via `lean-flow:cartography` skill; fixer writes results
