# plugin/workflows/

# codemap.md: `plugin/workflows/`

## Responsibility
Defines the operational framework and rule sets for Claude-driven development workflows. Establishes mandatory skill triggers, branching strategies, triage logic, and development patterns that orchestrate the entire lean-flow system. Acts as the policy layer for all development activities.

## Design
- **claude-rules.md**: Prescriptive rule engine with lookup tables (skill triggers, branch prefixes, escalation thresholds). Implements mandatory checkpoints (TDD before impl, verification before completion, code review gates) and escalation rules (3-strike fixer failure → oracle diagnosis → human flag).
- **standard-development-flow.md**: Visual state machine (mermaid flowchart) mapping user input through triage → complexity classification (simple/complex/greenfield/hotfix) → path-specific execution (pattern matching → brownfield mapping → brainstorming → planning → branching → step execution → verification).
- Key abstractions: STAR clarification (Scope·Task·Approach·Requirements), step-branch isolation (feature/name/step-N), role-based dispatch (Fixer/Oracle/Sonnet agents).

## Flow
1. **User prompt** → auto pattern recall (FTS5 search) → STAR classification hook
2. **Triage decision tree**: Simple (direct fix) | Complex (pattern search → map codebase → research → plan) | Greenfield (doc-first: PRD→HLA→TRD) | Hotfix (minimal, fast-path)
3. **Complex branch**: pattern_search → if no match, brownfield (map-codebase + ingest-docs) → brainstorm → research → assumptions-analyzer → spike (if blocked) → planning (EnterPlanMode) → plan-checker (8-dim validation) → branch creation → step-by-step execution → verifier → nyquist-auditor → finishing-a-development-branch
4. **Mandatory gates**: TDD RED→GREEN→REFACTOR before impl; verification (unit + E2E + ≥80% coverage) before PR; plan-checker blocks invalid plans; escalation after 3 fixer failures on same step.

## Integration
- **Consumed by**: Orchestrator (triage decision routing), Fixer/Oracle role dispatch, skill trigger hooks (UserPromptSubmit, plan completion gates)
- **Consumes**: Knowledge MCP (pattern_search), explorer/librarian haiku agents (research), superpowers:writing-plans and superpowers:executing-plans (plan generation/execution), plan-checker and verifier (validation gates)
- **Referenced by**: CI/CD (branch naming enforces kebab-case validation), PR workflow (parent→main merge after security audit), dev tooling (step-branch creation, release notes templates)
