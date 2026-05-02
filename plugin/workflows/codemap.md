# plugin/workflows/

# Codemap: plugin/workflows/

## Responsibility

This directory defines the mandatory workflow rules and development process for the entire codebase:
- **claude-rules.md** — enforcement layer specifying lean-flow command triggers, branching strategy (feature/fix/hotfix naming), escalation rules (3 retries → oracle), and triage logic (simple/complex/greenfield/hotfix paths)
- **standard-development-flow.md** — visual orchestration map (mermaid) showing role separation (opus orchestrator vs. haiku fixer vs. sonnet reviewers), control flow through TDD/planning/branching/CI gates, and parallel dispatch patterns (designer for frontend work, explorer for cartography)

## Design

Two-tier governance model:
- **Rules layer** (claude-rules.md): mandatory triggers (systematic-debugging on failures, test-driven-development before code, verification-before-completion before merge), branch taxonomy, and escalation thresholds
- **Flow layer** (standard-development-flow.md): state machine showing STAR classification (simple/medium/heavy + greenfield/hotfix), pattern recall → brainstorm → plan → execute pipeline, and role-based dispatch (orchestrator routes to fixer/designer/reviewer based on task type)

Key decision: **plan-checker gate** blocks execution until 8-dimension verification passes; **3-strike escalation** prevents infinite retry loops.

## Flow

User prompt → Orchestrator (opus) auto-recalls patterns → STAR classify → if medium/heavy: brainstorm → plan approval → create parent branch → dispatch fixer to step branches (parallel designer if frontend) → tests/coverage gates → PR step→parent (auto-merge) → post-steps → PR parent→main → code-reviewer → oracle final gate → codemap update.

Simple tasks bypass planning (direct fixer→PR→main). Hotfixes skip planning entirely (minimal fast path).

## Integration

- **Entry point**: SessionStart hook loads this via orchestrator.md (injected in additionalContext)
- **Enforcement**: All lean-flow commands (systematic-debugging, test-driven-development, finishing-a-development-branch, code-reviewer, oracle) are bound to rules defined here
- **Output**: Governs branch structure fed to git/CI, PR routing (step-branch auto-merge vs. parent-branch oracle review), and pattern storage (pattern_store updates on completion)
- **Dependencies**: Requires docs/CODEBASE_MAP.md (triage rule 1), ADRs/PRDs/SPECs (ingest-docs step), and orchestrator.md role declaration
