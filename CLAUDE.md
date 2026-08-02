# lean-flow

Claude Code plugin providing orchestrator binding, multi-agent dispatch, and workflow enforcement for medium and heavy software engineering tasks.

## Overview

- **Core purpose**: Bind main Claude Code session to orchestrator contract — classify → plan → dispatch → verify, never edit code directly for medium/heavy tasks.
- **Ships 6 subagents**: fixer (haiku, end-to-end), oracle (sonnet, think-only), code-reviewer (sonnet, quality), explorer (haiku, search), librarian (haiku, docs), designer (sonnet, UI).
- **Bundled commands**: `/project-doctor` (25-item AI-readiness audit), `/project-doctor-fix` (auto-generate missing artefacts).
- **Safety hooks**: block protected push, block no-verify, block claude-identity, enforce PR template.
- **Automation**: codemap auto-update, pattern memory, plan viewer.

## Tech Stack

- **Bash** (POSIX 3.2 macOS-compatible) — hooks, scripts, project-doctor audit.
- **Python 3** — cartographer, restructure-plan, scan-codebase.
- **JSON** — plugin manifest, hook config, settings.
- **Markdown** — agent contracts, workflow docs, domain model.
- **jq** — required JSON manipulation in hooks.

No compiled dependencies, no JS/Ruby/Go toolchain.

## Conventions

### File Organization

- Plugin internals: `plugin/` (agents/, commands/, hooks/, scripts/).
- Documentation: `docs/` (architecture, domain, codebase map, ADRs).
- Tests: `tests/` (shell/, python/, node/).
- Root: README, CHANGELOG, LICENSE, CLAUDE.md, this file.

### Bash Standards

Bash 3.2 compatible, `set -euo pipefail`, shellcheck clean; hook scripts live in `plugin/scripts/` and are registered in `plugin/hooks/hooks.json`. Full conventions are the single source in **[`plugin/CLAUDE.md`](plugin/CLAUDE.md#plugin-conventions)** — don't restate them here.

### Commits & PRs

- **Format**: `<type>: <what changed>` — lowercase, ≤72 chars, no period.
- **Types**: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `perf`, `security`.
- **Never**: push to main directly, use --no-verify, include Claude/AI attribution.
- **PR templates**: Step → parent (no release notes), parent → main (include release notes).

### Branching

- **Prefixes**: `feature/`, `fix/`, `improvement/`, `chore/`, `docs/`, `test/`, `hotfix/`, `security/`, `release/`.
- **Step branches**: append `/step-N` (e.g., `feature/foo/step-1`).
- Always kebab-case, descriptive.

## Key Commands

```bash
bash tests/run-all.sh                          # full test suite
bash plugin/scripts/project-doctor/score.sh    # run audit
/project-doctor                                # slash command version
gh pr create                                   # template-enforced PR
```

## Documentation

- **`docs/CODEBASE_MAP.md`** — architecture atlas + module layout.
- **`docs/ARCHITECTURE.md`** — system design, hooks lifecycle, agent models.
- **`docs/DOMAIN.md`** — entities, relationships, boundaries.
- **`docs/adr/`** — Architectural Decision Records (Nygard format).
- **README.md** — features, quick start, uninstall.

See individual `CLAUDE.md` files in `plugin/` and `tests/` for subsystem conventions.

---

## Global Rules (Orchestrator Binding)

The orchestrator binding, the 12 Hard Rules, tier routing, and agent roles are the single source of truth in **[`plugin/CLAUDE.md`](plugin/CLAUDE.md)** — this file does not restate them. The canonical orchestrator contract is `plugin/agents/orchestrator.md`; the canonical workflow is `plugin/workflows/standard-development-flow.md`.

---

@RTK.md
