# plugin/workflows/

# codemap.md — `plugin/workflows/`

## Responsibility
Defines the mandatory workflow rules and development processes for all Claude agents in this codebase. `claude-rules.md` enforces lean-flow commands, escalation discipline, and branching strategy; `standard-development-flow.md` documents the full orchestrator-fixer coordination model with mermaid diagrams showing session lifecycle, dispatch patterns, and CI gates.

## Design
Two complementary documents:
- **claude-rules.md**: Command-driven ruleset with escalation thresholds (3 retries → oracle → human), branch naming conventions (`feature/name/step-N`), and mandatory skill triggers (e.g., TDD before code, `verification-before-completion` before PR).
- **standard-development-flow.md**: Mermaid flowchart modeling the full session—orchestrator (opus) coordinates via pattern recall + STAR triage, dispatches fixers/designers in parallel, gates on coverage ≥90% and CI, requires code-reviewer + oracle sign-off before main merge.

## Flow
User prompt → SessionStart hook → Orchestrator loads rules + auto-recalls patterns → STAR classify (simple/medium/heavy/greenfield/hotfix) → Route to: direct PR (simple), plan+steps (medium/heavy), doc-first (greenfield), or hotfix fast-path. Each step branch runs fixer (TDD + tests) + optional designer in parallel, then gates on coverage + CI before step PR to parent. Final parent→main PR requires code-reviewer + oracle + codemap update.

## Integration
Central policy hub: referenced in session-briefing.sh (injects orchestrator.md via additionalContext), gates all dispatch decisions in standard-development-flow.md, and enforces lean-flow command vocabulary across fixer/oracle/designer agents. Codemap updates (§12a) feed patterns back to patterns.db for future pattern_search recall.
