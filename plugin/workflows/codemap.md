# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines the operational playbooks and rule frameworks for Claude agents executing development tasks. `claude-rules.md` is the **mandatory skill trigger matrix** and **branching/escalation discipline**, while `standard-development-flow.md` documents the **session orchestration pattern** (STAR classification → pattern recall → planning → execution) with explicit role separation (orchestrator vs. fixer vs. designer).

## Design
- **claude-rules.md**: Lookup table (skills by situation) + decision trees (triage complexity, branching strategy, escalation thresholds). Enforces lean-flow command discipline and 3-strike rule before oracle escalation.
- **standard-development-flow.md**: Mermaid swimlane diagram encoding the full session lifecycle—role declaration (opus/fixer/haiku) → auto-recall → STAR triage → parallel execution lanes (orchestrator coordinates, fixer/designer execute, oracle gate-keeps final PR).
- Both files are **prescriptive, not descriptive**—they block invalid operations (e.g., `/gsd-*` commands, retries without diagnosis) rather than document existing behavior.

## Flow
1. User submits prompt → `claude-rules.md` lookup determines **which lean-flow skill** (systematic-debugging, test-driven-development, etc.)
2. Orchestrator auto-classifies via STAR → consults `standard-development-flow.md` swimlanes to route (simple → direct PR; complex → plan → step branches; hotfix → fast path)
3. Fixer dispatches follow the **branching strategy** from `claude-rules.md` (parent + step branches, kebab-case naming)
4. Each step gates on coverage ≥80%, escalation after 3 failures
5. Final merge triggers codemap update (post-execution cartography)

## Integration
- **Entry point**: SessionStart hook loads `claude-rules.md` as mandatory context via `session-briefing.sh`
- **Orchestration**: `standard-development-flow.md` is the control flow diagram; `claude-rules.md` is the decision lookup
- **Dispatch target**: Fixer agents receive the relevant **skill trigger** (e.g., `lean-flow:test-driven-development`) from the orchestrator's STAR → flow-diagram decision
- **Escalation**: 3-strike rule (from `claude-rules.md`) feeds back to oracle gate-keep step in `standard-development-flow.md` (oracle inline review on hotfix, oracle think-only on systematic-debugging)
- **Artifacts**: Plans, PRs, and codemap updates are committed; pattern matches are stored to `patterns.db` for future FTS5 recall
