# plugin/workflows/

# plugin/workflows/ Codemap

## Responsibility
Defines the mandatory workflows and rules that govern Claude's behavior in lean-flow operations. `claude-rules.md` enforces non-negotiable command discipline, skill triggers, and escalation protocols. `standard-development-flow.md` prescribes the full session architecture: orchestrator (opus) coordination, fixer execution, pattern recall, and gated verification stages.

## Design
- **Dual-document model**: rules (enforcement layer) + flow (process layer)
- **STAR classification**: simple/medium/heavy + greenfield/hotfix branching strategy
- **Orchestrator pattern**: opus coordinates via hooks (SessionStart, UserPromptSubmit), never edits code; dispatches fixer/designer/explorer/librarian/reviewer based on task complexity
- **Skill trigger table**: mandatory invocations (systematic-debugging, test-driven-development, verification-before-completion) before state transitions
- **Escalation gates**: 3-retry limit per step → oracle diagnosis → flag for human if oracle escalates 3x same step
- **TDD + coverage guardrails**: RED→GREEN→REFACTOR, E2E validation, ≥80–90% coverage enforcement before PR merge

## Flow
1. **Session start** → orchestrator loads rules + flow doc → user prompt triggers auto-recall (FTS5 pattern search)
2. **STAR classify** → determines path: simple (direct PR), complex (plan), greenfield (doc-first), hotfix (fast)
3. **Complex/greenfield** → brainstorm → `superpowers:writing-plans` → plan-checker gate → user approval
4. **Branching**: parent branch (feature/name) ← step branches (feature/name/step-N) ← PRs merge sequentially
5. **Step execution**: TDD tests → fixer impl → coverage ≥90% → optional designer (frontend) parallel → self-verify → PR step→parent (auto-merge)
6. **Parent→main**: code-reviewer (sonnet) + oracle final gate → CLAUDE.md validation → codemap update → CI gate

## Integration
- **Hooks**: `SessionStart` (load orchestrator), `UserPromptSubmit` (auto-recall pattern search)
- **Referenced skills**: `lean-flow:*` commands (systematic-debugging, test-driven-development, verification-before-completion, code-reviewer, oracle, cartography)
- **Dispatch targets**: fixer (haiku), designer (parallel frontend work), explorer/librarian (research), reviewer/oracle (gated approvals)
- **Outputs feed**: CODEBASE_MAP.md (via cartographer), pattern_store (via pattern_search), release notes (per PR), codemap updates (post-merge)
