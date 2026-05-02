# plugin/workflows/

# Codemap: `plugin/workflows/`

## Responsibility
Defines the two operational frameworks for Claude-driven development: lean-flow rules and standard session flow. `claude-rules.md` establishes mandatory skill triggers, escalation logic, and branching strategy. `standard-development-flow.md` documents the orchestrator-fixer-reviewer execution model with Mermaid diagrams showing STAR classification, pattern recall, planning gates, and step-branch workflows.

## Design
- **Dual-document architecture**: Rules (prescriptive constraints) separated from Flow (descriptive process)
- **Mandatory triggers table** in claude-rules.md maps situations (bug, pre-coding, pre-merge) to specific `lean-flow:*` commands
- **STAR classification** (simple/medium/heavy + greenfield/hotfix) gates complexity into dispatch strategy
- **Step-branch model**: parent branch (1 per plan) → step-N branches → sequential PRs → parent → main, with optional parallel designer dispatch for frontend work
- **Escalation gates**: 3-attempt retry → oracle diagnosis; 3 oracle escalations → human flag

## Flow
1. SessionStart loads `orchestrator.md` context → User prompt triggers AutoRecall pattern search
2. STAR classify → conditional dispatch: simple (direct PR), greenfield (doc-first), hotfix (minimal fast path), or complex (pattern/brainstorm/plan)
3. Planning phase: EnterPlanMode → `superpowers:writing-plans` → plan-checker validation → user approval
4. Branch creation (parent, then step-N per plan step)
5. Step execution: optional researcher/designer parallel dispatch → TDD (RED/GREEN/REFACTOR) → coverage ≥90% gate → step PR to parent
6. Final parent PR: code-reviewer (sonnet) → oracle validation → CODEMAP_UPDATE + CI gate

## Integration
- **Input**: User prompt (via UserPromptSubmit hook), codebase context (docs/CODEBASE_MAP.md)
- **Invokes**: `lean-flow:*` commands (systematic-debugging, test-driven-development, verification-before-completion, code-reviewer, map-codebase, ingest-docs, phase-researcher, assumptions-analyzer, spike, plan-checker, finishing-a-development-branch, cartography)
- **Output**: Branch naming convention (feature/fix/improvement/security/hotfix/chore/docs with kebab-case), PR descriptions, release notes, updated CODEMAP.md via hybrid approach
- **Dispatch targets**: fixer (haiku), designer (sonnet), oracle (sonnet, think-only), explorer/librarian (research phase)
