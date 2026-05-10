# plugin/skills/

# codemap.md for `plugin/skills/`

## Responsibility

Repository of agent-invocable skills that orchestrate complex workflows before implementation. Each skill encapsulates a distinct phase (discuss, plan, map, audit, finish) and hands off to the next. Skills are coordination tools, not implementation — they produce guidance, decisions, or structured output that guides fixer/explorer work.

## Design

**Skill types by lifecycle phase:**
- **Pre-plan**: `discuss.md`, `ingest-docs.md`, `assumptions-analyzer.md`, `phase-researcher.md` — lock decisions & validate assumptions before planning
- **Planning**: `map-codebase.md`, `pathfinder.md`, `cartography.md` — understand existing architecture
- **Execution**: `brainstorming.md`, `delegate-to-haiku.md` — coordinate implementation work
- **Verification**: `plan-checker.md`, `nyquist-auditor.md` — validate plans & test coverage
- **Completion**: `babysit.md`, `finishing-a-development-branch.md` — shepherd work to merge
- **Onboarding**: `learn-codebase.md` — bootstrap context by reading all source

**No skill writes implementation code.** All spawn sub-agents (explorer/fixer) or produce decision documents (specs, plans, audits). Skills are orchestration + decision gates.

## Flow

1. User describes work → invoke `discuss` (lock decisions) → `ingest-docs` (read existing constraints)
2. Validate assumptions → `assumptions-analyzer` → `phase-researcher` (verify approach)
3. Understand codebase → `learn-codebase` / `map-codebase` / `pathfinder` (extract architecture)
4. Plan implementation → `brainstorming` (design) → create plan (external)
5. Check plan → `plan-checker` (8-dimension verification)
6. Execute → `delegate-to-haiku` (route mechanical work) + `cartography` (update maps)
7. Verify → `nyquist-auditor` (fill test gaps)
8. Finish → `babysit` (watch PR) → `finishing-a-development-branch` (merge)

Each skill is independent; user or orchestrator invokes by name. No skill calls another directly.

## Integration

**Subagent dispatch**: Skills spawn explorer (read-only, haiku) and fixer (write-capable, haiku) via standard agent tool. `delegate-to-haiku.md` formalizes routing to avoid expensive model for pure command work.

**Artifact outputs**: Skills write to `docs/`, `.planning/`, or `PATHFINDER-*/` directories. Skills read existing outputs (e.g., `plan-checker` reads `.planning/plan.md`).

**Codebase scanning**: `cartography.md` and `map-codebase.md` use parallel Sonnet subagents to analyze large codebases efficiently — orchestrator coordinates, Sonnet reads, haiku writes.

**Decision capture**: `discuss.md` output feeds downstream tools; confirmed decisions are referenced by `assumptions-analyzer` and `plan-checker` to catch contradictions.
