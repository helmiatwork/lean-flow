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

Full rules in `workflows/claude-rules.md`. Global flow in `~/.claude/CLAUDE.md` applies; this file adds project-specific overrides.

### Task Classification (MANDATORY first step)

| Type | Criteria | Path |
|------|----------|------|
| **Simple** | 1–2 files, clear change, <30min | @fixer direct → done checklist → commit |
| **Medium** | multi-file, new feature, refactor | STAR → `lean-flow:discuss` → `phase-researcher` → plan-plus → execute |
| **Heavy** | new system, multi-phase, architecture | STAR → `discuss` → `map-codebase` + `ingest-docs` → research → plan-plus → execute |
| **Hotfix** | production emergency | @fixer minimal fix → @oracle review → PR to main |
| **Bug** | unexpected behavior | `lean-flow:systematic-debugging` FIRST — no ad-hoc fixes |

### Plan-Plus Enforcement (HARD RULE)

For any **medium/heavy** task, a fresh plan-plus skeleton at `~/.claude/plans/<plan-name>/skeleton.md` (modified <120min) is **required** before any Task / Edit / Write. Enforced by `~/.claude/hooks/enforce-plan-plus.sh`. If scope grows simple → medium mid-task, STOP and create the skeleton. Native Plan mode alone is insufficient.

### Branch Naming (MANDATORY)

`feature/` `fix/` `improvement/` `security/` `test/` `docs/` `chore/` `hotfix/` `release/` `experiment/` `revert/` — step branches append `/step-N`.

### Non-negotiable triggers

- Bug/failure → `lean-flow:systematic-debugging` FIRST, always
- Writing feature code → `lean-flow:test-driven-development` (RED-GREEN-REFACTOR)
- Claiming done / before PR → `lean-flow:verification-before-completion`
- Implementation complete → `lean-flow:finishing-a-development-branch`
- Code review → `lean-flow:code-reviewer`

### Hard Rules

1. Never write code before classifying the task
2. Never skip STAR for medium/heavy
3. Plan-plus mandatory for all plans — native Plan mode alone is insufficient
4. @oracle never writes code — think-only
5. @fixer (haiku) does ALL implementation
6. Completion claims require evidence, not assertions

### Escalation

- Fixer fails 3× same step → oracle diagnoses (stop retrying)
- Oracle escalates 3× → flag human intervention
