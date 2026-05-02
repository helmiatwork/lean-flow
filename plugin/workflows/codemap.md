# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines the two core operational frameworks for Claude-based development:
- **claude-rules.md**: Mandatory command triggers, escalation rules, branch naming conventions, and the 6-step triage-to-merge workflow (Triage → Pattern Search → Brainstorm → Plan → Branch → Execute).
- **standard-development-flow.md**: Mermaid-driven orchestration model showing the two-lane execution pattern (Orchestrator opus coordinates; Fixer haiku + Designer/Reviewer sonnets execute code changes), with hooks for auto-recall, STAR classification, dispatch routing, and CI gates.

Together, these enforce deterministic, repeatable development discipline: lean-flow commands gate all major decisions, escalation rules prevent infinite retries, and parallel dispatch (fixer + optional designer) enables efficient multi-person workflows.

## Design
- **Rules as state machine**: claude-rules.md encodes mandatory skill triggers (TDD, systematic-debugging, verification-before-completion) as lookup table — each situation maps to exactly one lean-flow command.
- **Two-lane architecture**: Orchestrator (decision-making, no code edits) stays in op-context; Execution lane (fixer haiku + reviewers sonnet) handles all writes. Dispatch calls decouple roles.
- **STAR triage gates complexity**: Simple (→ direct PR) vs. Medium/Heavy (→ planning) vs. Greenfield (→ doc-first) vs. Hotfix (→ fast path). Prevents over-engineering simple fixes.
- **Step branching with merge gating**: Parent branch coordinates; step branches isolate work; step PRs auto-merge to parent (no oracle), final parent→main PR gets full code review + oracle + CLAUDE.md validation.
- **Hook-based auto-recall**: UserPromptSubmit triggers pattern_search (FTS5 on patterns.db); SessionStart loads orchestrator.md. No manual context loading.

## Flow
1. **Session start**: Orchestrator (opus) loaded via session-briefing.sh, awaits user prompt.
2. **Auto-recall**: UserPromptSubmit hook fires → pattern_search + map-codebase + ingest-docs (for heavy tasks).
3. **STAR classify**: Orchestrator determines simple/medium/heavy + greenfield/hotfix; user confirms breakdown.
4. **Dispatch routing**:
   - Simple → fixer direct PR to main (no planning).
   - Medium/Heavy + pattern match → fixer applies pattern, creates parent branch.
   - No pattern match → brainstorm + researcher + assumptions-analyzer, then plan (with plan-checker gate), then branch + step loop.
   - Greenfield → parallel doc generation (PRD/HLA/TRD), then plan.
   - Hotfix → fixer minimal fix off main, minimal review.
5. **Step execution**: For each step: TDD if applicable → fixer + optional designer parallel → tests + coverage ≥90% gate → step PR to parent (auto-merge) → orchestrator verifies.
6. **Final PR**: Parent → main, code-reviewer (sonnet) + oracle (sonnet, tools:[]) validation, CLAUDE.md check, pattern_store update.
7. **Escalation breakout**: 3 same-step failures → oracle diagnose; 3 oracle escalations → flag human.

## Integration
- **Invokes**: lean-flow command suite (systematic-debugging
