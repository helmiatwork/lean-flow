# lean-flow Project Instructions

## CRITICAL: Do NOT use GSD commands

This project uses **lean-flow** workflow only. Never suggest or use `/gsd-*` commands.

| Instead of | Use |
|---|---|
| `/gsd-discuss-phase` | `lean-flow:discuss` |
| `/gsd-plan-phase` | plan-plus + `lean-flow:fixer` |
| `/gsd-executor` | `lean-flow:fixer` |
| `/gsd-verify-phase` | `lean-flow:verifier` |
| `/gsd-*` anything | lean-flow equivalent |

## Workflow — Always Follow

Full rules in `workflows/claude-rules.md`. Summary:

**Before any code:** STAR auto-fires → `lean-flow:discuss` → research → plan → execute

**Non-negotiable triggers:**
- Bug/failure → `lean-flow:systematic-debugging` FIRST, always
- Writing feature code → `lean-flow:test-driven-development` (RED-GREEN-REFACTOR)
- Claiming done / before PR → `lean-flow:verification-before-completion`
- Implementation complete → `lean-flow:finishing-a-development-branch`
- Code review → `lean-flow:code-reviewer`

**Escalation:**
- Fixer fails 3× same step → oracle diagnoses (stop retrying)
- Oracle escalates 3× → flag human intervention
