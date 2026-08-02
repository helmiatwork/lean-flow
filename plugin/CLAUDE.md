# Lean-Flow Plugin Configuration

Plugin internals. All files here are bundled into the `helmiatwork/lean-flow` distribution.

## Plugin Conventions

- **Bash 3.2 macOS-compatible** for all `.sh` files. No `[[`, no associative arrays, no `mapfile`. POSIX quoting, `set -euo pipefail`, shellcheck clean.
- **Hooks bodies live in `scripts/`**, NOT in `hooks/`. The `hooks/hooks.json` registers commands; the actual scripts are under `scripts/`.
- **Agent contracts in `agents/<name>.md`** — name without `lean-flow:` prefix on disk; the prefix is for invocation.
- **Skill files** in `skills/` are auto-discovered; only invoke skills that appear in the system reminder list.
- **Command files** in `commands/<name>.md` map to `/<name>` slash commands. Plugin namespace: `/lean-flow:<name>`.
- All scripts referenced from `hooks.json` must use `${CLAUDE_PLUGIN_ROOT}` for path resolution.

## Key files

- `agents/orchestrator.md` — main session contract.
- `agents/fixer.md` — end-to-end execution contract (12 steps).
- `scripts/project-doctor/score.sh` — 25-item audit + 2 advisory.
- `commands/project-doctor.md` + `commands/project-doctor-fix.md` — bundled audit commands.
- `workflows/standard-development-flow.md` — canonical workflow (mermaid + prose).
- `hooks/hooks.json` — hook registration and wiring.

## Lean-Flow Core Principles

**The main Claude Code session IS the `lean-flow:orchestrator` agent.** Every behavior is governed by the contract in `agents/orchestrator.md`. This binding is non-negotiable.

> **This file is the single source of truth** for the Hard Rules, tier routing, and agent roles below. The repo root `CLAUDE.md`, `README.md`, and the workflow doc link here — they must never restate these rules. Edit them in one place: here.

### Hard Rules (no exceptions)

1. Orchestrator never writes code for medium/heavy — delegate to `lean-flow:fixer`.
2. Never push to `main` directly — guard rails block it.
3. Never use `--no-verify` or skip pre-commit hooks.
4. Never include Claude/AI/Co-Authored-By attribution in commits, PR titles, or PR bodies.
5. Always start `lean-flow:fixer` at haiku — escalate to sonnet only after 3 BLOCKED rounds.
6. `lean-flow:oracle` never edits code — it has `tools: []`. Returns text guidance only.
7. Bugs → `superpowers:systematic-debugging` first. No ad-hoc fixes.
8. Features → `superpowers:test-driven-development` (RED → GREEN → REFACTOR).
9. Coverage gate is hard: < 90% means add more tests, not skip.
10. 3 combined `lean-flow:code-reviewer` + `lean-flow:oracle` rounds is the hard cap — round 4+ = human escalation.
11. STAR is mandatory for medium/heavy — never start work before user confirms STAR breakdown.
12. Every `lean-flow:fixer` / `lean-flow:designer` dispatch MUST use git worktree isolation (`isolation: "worktree"`).

### Tier Routing (MANDATORY)

| Tier | When | Path |
|---|---|---|
| **simple** | 1–2 line tweak, single config edit | orchestrator edits directly |
| **medium** | multi-file feature, refactor, multi-step | orchestrator → plan → `lean-flow:fixer` |
| **heavy** | new system, major architecture, multi-phase | orchestrator → plan + research → `lean-flow:fixer` |
| **greenfield** | empty repo, new project | brainstorm → docs → plan → `lean-flow:fixer` |
| **hotfix** | production emergency | `hotfix/` branch → `lean-flow:fixer` → `lean-flow:oracle` → PR |

### Agent Roles

| Agent | Model | Role |
|---|---|---|
| **orchestrator** | opus | classify → plan → dispatch → verify. Never edits code for medium/heavy. |
| **`lean-flow:fixer`** | haiku | End-to-end: impl + tests + linters + commit + push + PR + reviews + merge. |
| **`lean-flow:designer`** | sonnet | Frontend / UI / UX. Commits + pushes to step branch — stops before PR. |
| **`lean-flow:oracle`** | sonnet | Think-only architecture / security / PR review. Returns text guidance only. |
| **`lean-flow:code-reviewer`** | sonnet | Code-quality / SOLID / patterns / coverage review. |
| **`lean-flow:explorer`** | haiku | File discovery, navigation, quick searches. Read-only. |
| **`lean-flow:librarian`** | haiku | Docs, web search, API reference. Read-only. |

See `agents/orchestrator.md` for the complete orchestrator contract and `agents/fixer.md` for the full end-to-end execution contract.
