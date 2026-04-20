# lean-flow Project Instructions

## CRITICAL: Do NOT use GSD commands

This project uses **lean-flow** workflow only. Never suggest or use `/gsd-*` commands.

| Instead of | Use |
|---|---|
| `/gsd-discuss-phase` | `lean-flow:discuss` |
| `/gsd-plan-phase` | plan-plus skill + lean-flow:fixer |
| `/gsd-executor` | `lean-flow:fixer` |
| `/gsd-verify-phase` | `lean-flow:verifier` |
| `/gsd-*` anything | lean-flow equivalent |

## Workflow

Follow `workflows/standard-development-flow.md` for all tasks.

Key steps before writing any code:
1. STAR clarification fires automatically on medium/heavy prompts
2. Run `lean-flow:discuss` to scope decisions
3. Use `lean-flow:phase-researcher` + `lean-flow:assumptions-analyzer` for research
4. Plan with plan-plus, then execute with `lean-flow:fixer`
