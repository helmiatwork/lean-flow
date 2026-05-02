# plugin/agents/

# codemap.md — `plugin/agents/`

## Responsibility

Defines the lean-flow plugin's specialist agents — each a Claude role with specific permissions, tools, and trigger rules. Together they form a delegation framework that routes work to cost/speed-optimized experts: explorer (codebase search), librarian (docs), oracle (architecture), code-reviewer (quality), designer (UI/UX), fixer (implementation), discuss (scoping), and plan-plus-executor (step execution). The orchestrator (main session, not an agent) coordinates them via the Agents and Workflow sections of `orchestrator.md`.

## Design

- **Agent = Role + Skills + Tools**: Each `.md` file defines a Claude role with mandatory superpowers (e.g., `superpowers:executing-plans`), permitted tools (Read/Write/Bash/Agent/etc.), and trigger rules.
- **Model inheritance**: Most agents use `model: inherit` (take orchestrator's model) or explicit model (haiku for cheap reads, sonnet for thinking, opus for orchestrator). `oracle.md` has `tools: []` — think-only, never writes.
- **Skill-tool coupling**: Skills like `superpowers:verification-before-completion` imply a checklist; `superpowers:executing-plans` implies no deviation from a plan. Tools enforce scope (e.g., explorer's read-only grep/glob vs. fixer's write/edit).
- **Dispatch rules in descriptions and workflow**: When to call each agent is stated in both their `.md` and in `orchestrator.md`'s `<Workflow>` section (STAR classifier → tier routing → pre-work → dispatch).

## Flow

1. **User submits task** → Orchestrator classifies (simple/medium/heavy) via STAR.
2. **Simple**: Orchestrator edits directly.
3. **Medium/Heavy**: Orchestrator writes a plan (exact code + paths + commands), then dispatches `lean-flow:fixer` (haiku) as primary executor. Fixer owns the full chain: impl → tests → linters → commit → PR → code-reviewer (diff quality) → oracle (architecture) → merge.
4. **Blockers during impl**: Orchestrator can dispatch `lean-flow:explorer` (search), `lean-flow:librarian` (API docs), or `lean-flow:oracle` (stuck diagnosis) in parallel.
5. **UI/UX work**: Fixer routes to `lean-flow:designer` (sonnet) via plan; designer implements, writes tests, then stops — fixer creates PR and manages reviews.
6. **Scope ambiguity**: Orchestrator dispatches `lean-flow:discuss` (pre-work) to lock in 3–5 decisions before any implementation.
7. **Step-level work**: `lean-flow:plan-plus-executor` runs a single step of a skeleton-plus-files plan in ephemeral context, updating shared `context/` files with discoveries.

## Integration

- **Orchestrator coordinates**: Reads files locally, dispatches agents via `Agent` tool with structured prompts (e.g., "Explorer, scan folder X"), aggregates results.
- **Skills are cross-agent**: A skill like `superpowers:test-driven-development` appears in fixer, designer, and plan-plus-executor — they all follow RED → GREEN → REFACTOR.
- **Oracle is centralized decision-maker**: Final parent → main PR reviews always route to oracle (§
