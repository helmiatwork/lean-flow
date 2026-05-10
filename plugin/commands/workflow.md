---
name: workflow
description: Display standard development flow (STAR routing, tier paths, hard rules).
---

# /lean-flow:workflow

Reference command: show the canonical development workflow. Read-only, no questions, no writes.

## Step 1 — Load canonical workflow doc

Read `${CLAUDE_PLUGIN_ROOT}/plugin/workflows/standard-development-flow.md` — the single source of truth for the standard development flow (mermaid diagram, STAR routing, tier paths, review gates, merge criteria).

## Step 2 — Extract compact summary

From the full workflow doc, synthesize and display:

1. **STAR Classifier** (tier routing)
2. **Tier paths** (simple, medium, heavy, greenfield, hotfix)
3. **Key decision points** (each tier's entry/exit gates)
4. **Hard rules** (constraints common to all paths)
5. **Mermaid diagram** (compact flowchart from the doc)

## Step 3 — Render summary markdown

Render a structured summary (≤500 lines total):

### STAR Classification (UserPromptSubmit hook)

Every prompt is classified into one tier. Route per tier:

| Tier | Criteria | Path | Lead agent | Review |
|------|----------|------|------------|--------|
| **simple** | 1–2 line tweak, single config edit, quick answer | Orchestrator edits directly | orchestrator (opus) | None |
| **medium** | Multi-file feature, refactor, bug fix, multi-step impl | Plan → dispatch fixer | lean-flow:fixer (haiku) | Code-reviewer + oracle (3 rounds cap) |
| **heavy** | New system, major architecture, multi-phase, multi-repo | Plan + research + dispatch fixer | lean-flow:fixer (haiku) | Code-reviewer + oracle (3 rounds cap) |
| **greenfield** 🌱 | Empty repo, new project | Docs (PRD/HLA/TRD) → plan → fixer | lean-flow:fixer (haiku) | Code-reviewer + oracle |
| **hotfix** 🔥 | Production emergency | Quick fix on hotfix/ branch → main | lean-flow:fixer (haiku) | Oracle inline (no code-reviewer) |

**STAR breakdown shown to user for medium/heavy/greenfield/hotfix.** User confirms before work starts.

### Execution Paths

#### Path 1: Simple (orchestrator direct)
```
User prompt
  ↓
STAR: simple?
  ↓
Orchestrator edits (1–2 lines, config)
  ↓
Done (no PR, no tests, no reviews)
```

#### Path 2: Medium (fixer + reviews)
```
User prompt
  ↓
STAR: medium?
  ↓
Orchestrator:
  - pattern_search (check prior solutions)
  - superpowers:writing-plans (structured plan)
  - plan-checker gate (8 dimensions)
  ↓
Create parent branch
  ↓
Dispatch fixer (for each step):
  - Optional: designer (parallel) for frontend
  - Impl + tests ≥90% coverage
  - Linters clean
  - Commit + push
  - Post-commit cartography (explorer)
  ↓
Dispatch fixer for final PR:
  - Code-reviewer (sonnet) review
  - Oracle (sonnet) review
  - Loop (3 rounds max) until both APPROVED
  ↓
CI green?
  ↓
Merge (squash)
```

#### Path 3: Heavy (research + plan + fixer + reviews)
```
Same as Medium, plus:
  - map-codebase (explorer + orchestrator)
  - ingest-docs (understand existing architecture)
  - Potentially multiple steps per phase
  - Full review cycle with oracle
```

#### Path 4: Greenfield 🌱 (docs first, then plan + fixer)
```
User prompt (empty repo)
  ↓
Orchestrator dispatches sonnet agents in parallel:
  - Generate PRD (vision, scope, audience)
  - Generate HLA (system architecture)
  - Generate TRD (tech decisions, trade-offs, DB/API design)
  ↓
Approve docs
  ↓
superpowers:writing-plans (detailed implementation plan)
  ↓
Dispatch fixer
  ↓
Same review chain as Medium/Heavy
```

#### Path 5: Hotfix 🔥 (fast path, oracle inline)
```
Production issue detected
  ↓
Create hotfix/ branch off main
  ↓
Dispatch fixer (minimal fix only)
  ↓
Tests + linters
  ↓
Open PR hotfix → main
  ↓
Oracle inline review (think-only, no code-reviewer)
  ↓
Apply oracle feedback
  ↓
CI green?
  ↓
Merge
```

### Design Flow (Medium/Heavy with Frontend)

For steps with frontend work (UI, components, styling):

```
Fixer + Designer dispatch in parallel:

Fixer lane:
  - Backend logic
  - Database
  - API contracts
  - Tests

Designer lane:
  - UI components
  - Frontend forms
  - Styling
  - Interaction tests

Both commit to step branch
  ↓
Fixer commits + triggers cartography
  ↓
Both PR step → parent (auto-merge, no oracle)
```

**Designer contract:** commits to step branch, **stops before PR**. Fixer owns final PR cycle (code-reviewer + oracle + merge).

### Hard Rules (all paths)

1. **Orchestrator never writes code** for medium/heavy. Classifies → plans → dispatches.
2. **Fixer owns implementation, tests, linters, commits, PR, reviews, merge.** Full end-to-end.
3. **Never push to main directly** — guard rail blocks it. Always PR.
4. **Never use --no-verify** — pre-commit hooks enforce security + style.
5. **No Claude attribution** in commits/PRs — hooks block it.
6. **Code-reviewer + oracle cap: 3 combined rounds.** Round 4 → human escalation.
7. **Tests ≥ 90% coverage** on new code. If below, add more tests.
8. **CI must be green** before merge.
9. **Merge strategy:** squash for clean history. Branch auto-delete after merge.
10. **Step PRs** (step → parent) skip code-reviewer + oracle (cheap, fast). Only final parent → main PR runs full review chain.

### Step PRs (multi-step medium/heavy)

For large features split into steps:

```
Parent branch: feature/user-onboarding
  ├── step-1 → parent (CI passes → auto-merge, no oracle)
  ├── step-2 → parent (CI passes → auto-merge, no oracle)
  ├── step-3 → parent (CI passes → auto-merge, no oracle)
  ↓
All steps merged into parent
  ↓
Parent → main (FULL review: code-reviewer + oracle, 3 rounds cap)
  ↓
Merge
```

### Key Checkpoints

| Checkpoint | Owner | Decision |
|-----------|-------|----------|
| STAR confirm | Orchestrator | Proceed with tier-specific path? |
| Pattern match | Orchestrator | Pattern found? Adapt or brainstorm. |
| Plan approval | Orchestrator (+ user) | Plan is complete + validated? |
| Test pass | Fixer | All tests passing? |
| Coverage ≥90% | Fixer | Enough test coverage? |
| Linters clean | Fixer | Code style + types? |
| Code-reviewer | Sonnet | APPROVED or CHANGES_REQUESTED? |
| Oracle | Sonnet | APPROVED or CHANGES_REQUESTED? |
| CI green | GitHub Actions | Tests, linters, integration all passing? |
| Merge | Fixer | All gates passed? Squash merge. |

### Mermaid Diagram

See `plugin/workflows/standard-development-flow.md` for the full flowchart. Key paths shown above in text form.

## Hard rules

- No file writes.
- No questions.
- Workflow is reference only; canonical implementation lives in plugin/agents/ and plugin/workflows/.
- Dispatch logic is orchestrator's responsibility; this command is informational.
