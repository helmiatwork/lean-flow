---
name: using-lean-flow
description: Master workflow guide. Invoke before ANY task — simple or heavy. Defines which lean-flow skill to use and when.
---

# lean-flow: Master Workflow

CRITICAL: Always follow this workflow. Never skip steps. Never use /gsd-* commands.

## Task Classification

Before doing anything, classify the task:

| Type | Criteria | Path |
|---|---|---|
| **Simple** | 1-2 files, clear change, <30min | fixer directly → done checklist → commit |
| **Medium** | multi-file, new feature, refactor | STAR → discuss → research → plan → execute |
| **Heavy** | new system, multi-phase, architecture | STAR → discuss → map-codebase → research → doc-first → plan → execute |
| **Hotfix** | production emergency | fixer minimal fix → oracle review → PR to main |
| **Bug** | unexpected behavior | systematic-debugging first, always |

## Skills by Situation

| When | Use |
|---|---|
| Any bug or unexpected behavior | `lean-flow:systematic-debugging` |
| Before writing ANY feature code | `lean-flow:test-driven-development` |
| Before claiming work is done | `lean-flow:verification-before-completion` |
| Scoping a medium/heavy task | `lean-flow:discuss` |
| Pre-planning research | `lean-flow:phase-researcher` + `lean-flow:assumptions-analyzer` |
| Unclear feasibility | `lean-flow:spike` |
| Existing codebase, complex task | `lean-flow:map-codebase` + `lean-flow:ingest-docs` |
| After all steps merged | `lean-flow:verifier` + `lean-flow:nyquist-auditor` |
| Implementation complete, ready to merge | `lean-flow:finishing-a-development-branch` |
| Code review needed | `lean-flow:code-reviewer` |
| Creative/design work | `lean-flow:brainstorming` |

## Hard Rules

1. **Never write code before classifying the task**
2. **Never skip STAR for medium/heavy** — fires automatically via hook
3. **Never suggest /gsd-* commands** — lean-flow equivalents always exist
4. **Bugs → systematic-debugging first** — no ad-hoc fixes
5. **Features → TDD** — failing test before implementation
6. **Completion claims → verification-before-completion** — evidence before assertions
7. **3 fixer failures on same step → escalate to oracle** — don't retry blindly
8. **Oracle never writes code** — think-only, returns text instructions

## Agent Routing (quick ref)

- `lean-flow:explorer` (haiku) — read-only file discovery
- `lean-flow:fixer` (haiku) — all implementation
- `lean-flow:oracle` (sonnet, think-only) — review, audit, decisions
- `lean-flow:designer` (sonnet) — UI/UX only
- `lean-flow:code-reviewer` (sonnet) — dedicated code review
