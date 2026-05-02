# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines the canonical workflows and rule enforcement for Claude-based development. `claude-rules.md` establishes mandatory lean-flow commands, escalation policies, and branching conventions. `standard-development-flow.md` provides the mermaid orchestration diagram showing how orchestrator (opus) coordinates with fixer (haiku) and reviewers (sonnet) across simple/complex/hotfix/greenfield paths.

## Design
- **Rules-as-contract**: `claude-rules.md` establishes non-negotiable skill triggers (e.g., TDD before implementation, systematic-debugging on failure), escalation limits (3 retries → oracle diagnosis), and branch naming conventions (`feature/*/step-N`, `hotfix/*`, `docs/*`)
- **Orchestrated async execution**: `standard-development-flow.md` shows role separation — orchestrator never edits code, dispatches fixers/designers in parallel, gates on CI/coverage/code-review before merge
- **Pattern reuse**: Pattern search (FTS5 → patterns.db) short-circuits planning; matching patterns skip to dispatch-adapt; no match → brainstorm → plan

## Flow
1. **Session start** → orchestrator loads rules, user submits prompt
2. **Auto-recall + STAR classify** → pattern search (FTS5) → found (dispatch adapt) or not (brainstorm)
3. **Branching strategy**: parent branch off main → step branches off parent (sequential, each step PRs to parent) → final parent PR to main (oracle-gated)
4. **Parallel dispatch** where applicable: designer + fixer in step branches, both writing code; orchestrator only coordinates and verifies
5. **Escalation**: fixer fails 3× on same step → oracle diagnoses (think-only); oracle escalates 3× → flag human

## Integration
- Imported by session-briefing.sh into `orchestrator.md` context (opus role declaration)
- Validates against `docs/CODEBASE_MAP.md` (triage checks it exists; cartographer regenerates changed folders)
- Feeds patterns back to `patterns.db` (FTS5 knowledge store) after merge
- Gate checks: plan-checker (8-dimension verification), coverage ≥80–90%, CI green, code-review approval, oracle final sign-off before codemap + pattern_store update
