# plugin/agents/

# plugin/agents/ codemap

## Responsibility

Contains lean-flow agent role definitions and capabilities. Each `.md` file is a Claude system prompt that defines a specialist agent—orchestrator dispatches these agents based on task tier and type. Agents collectively form a cost-optimized, parallel-capable execution engine that decomposes monolithic AI coding tasks into focused subagent responsibilities.

## Design

**Agent taxonomy:** Each agent has a fixed role (Explorer searches, Fixer codes, Oracle reviews, Designer polishes, Librarian researches, Discuss scopes) with explicit tool permissions and skill requirements. The `orchestrator.md` is the canonical routing logic—it classifies tasks (simple/medium/heavy), determines which agents to dispatch, and synthesizes results. `plan-plus-executor.md` is a ephemeral executor for structured plan steps.

**Cost/speed trade-offs:** Explorer and Librarian are haiku (cheap, fast parallel search); Fixer is haiku for mechanical work; Code-reviewer, Oracle, Designer are sonnet (deeper reasoning). Orchestrator is opus (decision-making). Pre-work delegation (discuss, explorer searches) before fixer execution avoids rework.

## Flow

1. User submits task → **Orchestrator** classifies (STAR: simple/medium/heavy)
2. Simple: Orchestrator edits directly
3. Medium/Heavy: Orchestrator plans → dispatches **Discuss** (scope alignment), **Explorer** (discovery), **Librarian** (APIs), **Fixer** (execution)
4. Fixer executes plan, writes tests, runs linters → **Code-reviewer** (diff quality) + **Oracle** (architecture) review → apply feedback loop (max 3 rounds) → merge
5. Designer dispatched for UI tasks (responsive, a11y, design systems); always stops before PR creation (Fixer takes over)

## Integration

Agents are stateless; context flows via orchestrator prompts (summaries, file paths, diff summaries). Explorer scans changed folders after each commit for hybrid codemap updates. Code-reviewer and Oracle receive summaries from Fixer/Explorer, not raw diffs. Fixer owns the full end-to-end chain (impl → tests → PR → reviews → merge). Designer and Fixer coordinate: Designer implements UI, Fixer integrates and handles PR flow. Orchestrator never writes code for medium/heavy; it only plans and dispatches.
