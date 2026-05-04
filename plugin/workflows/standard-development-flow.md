# Standard Development Flow

## Mermaid Diagram

```mermaid
flowchart TD
    SESSION_START(["🟢 Session start<br/>SessionStart hook"]) --> ROLE_DECLARE
    ROLE_DECLARE["🎯 Load orchestrator.md<br/>main session = orchestrator (opus)<br/>injected via session-briefing.sh<br/>additionalContext"] --> USER
    USER(["👤 User prompt"]) --> AUTORECALL

    %% =========================================================
    %% LANE 1 — ORCHESTRATOR (opus, coordinates, never edits code)
    %% =========================================================
    subgraph ORCH ["🎯 ORCHESTRATOR LANE — opus, coordinates only"]
      AUTORECALL["⚡ Auto pattern recall<br/>UserPromptSubmit hook<br/>FTS5 → patterns.db"] --> STARCHECK
      STARCHECK{"⭐ STAR classify<br/>simple / medium / heavy<br/>+ greenfield / hotfix"}
      STARCHECK -->|"medium / heavy"| STARSHOW["📋 STAR breakdown<br/>shown to user"]
      STARSHOW --> STARCONFIRM{"User confirms?"}
      STARCONFIRM -->|"adjust"| STARSHOW
      STARCONFIRM -->|"yes"| MEMORY["🧠 pattern_search<br/>+ map-codebase<br/>+ ingest-docs (heavy)"]
      MEMORY --> FOUND{"Pattern match?"}
      FOUND -->|"yes"| DISPATCH_ADAPT(["📤 Dispatch fixer<br/>(apply pattern)"])
      FOUND -->|"no"| BRAINSTORM["💡 brainstorming<br/>+ phase-researcher<br/>+ assumptions-analyzer<br/>+ spike if blocked"]
      BRAINSTORM --> PLAN
      PLAN["📋 superpowers:writing-plans<br/>EnterPlanMode → approve → ExitPlanMode<br/>plan-checker gate"] --> BRANCH_CREATE["🌿 Create parent branch"]
      BRANCH_CREATE --> STEP{"Next step?"}
      STEP -->|"yes"| DISPATCH_STEP(["📤 Dispatch fixer<br/>(implement step N)"])
      STEP -->|"all done"| DISPATCH_FINAL(["📤 Dispatch fixer<br/>(post-steps + final PR)"])
      STEP -->|"plan invalid"| PLAN
      VERIFY["✅ Orchestrator verifies<br/>fixer summary + diff spot-check"]
    end

    %% Dispatch routes from STARCHECK
    STARCHECK -->|"simple"| DISPATCH_SIMPLE(["📤 Dispatch fixer<br/>(direct PR to main)"])
    STARCHECK -->|"greenfield 🌱"| GREENFIELD["🌱 Generate docs<br/>parallel sonnet<br/>PRD / HLA / TRD"]
    GREENFIELD --> PLAN
    STARCHECK -->|"hotfix 🔥"| DISPATCH_HOTFIX(["📤 Dispatch fixer<br/>(hotfix fast path)"])

    %% =========================================================
    %% LANE 2 — EXECUTION (fixer haiku + reviewers sonnet, all writes)
    %% =========================================================
    subgraph EXEC ["🔧 EXECUTION LANE — lean-flow:fixer (haiku) + reviewers (sonnet)"]

      %% Simple path
      DISPATCH_SIMPLE --> DIRECTFIX["🔧 fixer impl + tests"]
      DIRECTFIX --> DIRECTPR["PR → main<br/>+ release notes"]
      DIRECTPR --> CI_SIMPLE{"CI green?"}
      CI_SIMPLE -->|"red"| DIRECTFIX

      %% Hotfix path
      subgraph hotfix_branch ["🌿 hotfix branch (off main)"]
        DISPATCH_HOTFIX --> HOTFIXFIX["🔧 fixer minimal fix + tests"]
        HOTFIXFIX --> HOTFIXPR["PR hotfix → main<br/>🔮 oracle inline review"]
      end
      HOTFIXPR --> CI_HOTFIX{"CI green?"}
      CI_HOTFIX -->|"red"| HOTFIXFIX

      %% Adapt-pattern shortcut
      DISPATCH_ADAPT --> BRANCH_CREATE

      %% Step branch loop — with optional parallel designer
      subgraph step_branch ["🌿 step branch per step"]
        DISPATCH_STEP --> STEPBR["🌿 Step branch<br/>optional research:<br/>explorer / librarian"]
        STEPBR --> HAS_FRONTEND{"Frontend work<br/>in step?"}
        HAS_FRONTEND -->|"yes"| DESIGNER_DISPATCH["📤 Dispatch designer<br/>(parallel to fixer)"]
        HAS_FRONTEND -->|"no"| TESTFIRST
        DESIGNER_DISPATCH --> DESIGNER_IMPL["🎨 designer: frontend-design<br/>+ tdd + verification<br/>commits to step branch"]
        DESIGNER_IMPL --> DESIGNER_WAIT["⏳ Designer done<br/>waiting for fixer"]
        TESTFIRST{"TDD?"}
        TESTFIRST -->|"yes"| TDDTEST["RED → GREEN → REFACTOR"] --> IMPLEMENT
        TESTFIRST -->|"no"| IMPLEMENT
        IMPLEMENT["🔧 fixer impl + tests + self-verify"] --> TEST["Run tests"]
        TEST -->|"pass"| COVERAGE_GATE{"📊 Coverage ≥ 90%?"}
        TEST -->|"fail × 3"| ORACLE_ESC["🔮 oracle (think-only)<br/>systematic-debugging"]
        ORACLE_ESC --> IMPLEMENT
        COVERAGE_GATE -->|"< 90%"| IMPLEMENT
        COVERAGE_GATE -->|"≥ 90%"| FIXER_CARTO["🔧 fixer commits<br/>orchestrator dispatches<br/>explorer: lean-flow:cartography<br/>(changed folders only)"]
        DESIGNER_WAIT --> FIXER_CARTO
      end
      FIXER_CARTO --> STEPPR["PR step → parent<br/>auto-merge, no oracle"]

      %% Parent → main final PR
      subgraph parent_branch ["🌿 parent branch (off main)"]
        DISPATCH_FINAL --> POSTSTEPS["✅ Post-step gate<br/>verifier + nyquist + finishing"]
        POSTSTEPS --> MAINPR["🔧 fixer opens PR<br/>parent → main<br/>+ release notes"]
        MAINPR --> CODEREVIEW["📋 lean-flow:code-reviewer<br/>(sonnet)"]
        CODEREVIEW -->|"issues"| ISSUE_ROUTE["🔀 fixer routes issues<br/>backend → fixer<br/>frontend → designer<br/>cross-cutting → both parallel"]
        ISSUE_ROUTE --> FIXFINAL["🔧 + 🎨 apply fixes<br/>+ re-verify<br/>+ push"]
        FIXFINAL --> CODEREVIEW
        CODEREVIEW -->|"approved"| FINAL["🔮 lean-flow:oracle<br/>(sonnet, tools:[])<br/>also validates CLAUDE.md"]
        FINAL -->|"issues"| ISSUE_ROUTE
        FINAL -->|"approved"| CODEMAP_UPDATE["🔧 Hybrid codemap update §12a<br/>+ pattern_store"]
        CODEMAP_UPDATE --> CI_GATE{"⏳ CI green?"}
        CI_GATE -->|"red"| FIXFINAL
      end
    end

    %% Step loop — execution reports back to orchestrator's STEP control
    STEPPR --> STEP

    %% Final convergence
    CI_SIMPLE -->|"green"| DONE(["✅ Done<br/>human monitors prod separately"])
    CI_HOTFIX -->|"green"| DONE
    CI_GATE -->|"green"| MERGE_MAIN(["✅ fixer merges PR<br/>squash + delete branch"])
    MERGE_MAIN --> VERIFY
    VERIFY --> DONE

    %% Escalations cross both lanes
    ORACLE_ESC -.->|"3 oracle rounds stuck"| HUMAN_ESCALATE
    FIXFINAL -.->|"3 review rounds"| HUMAN_ESCALATE
    HUMAN_ESCALATE["⚠️ Human intervention<br/>fixer + reviewers stuck<br/>orchestrator surfaces blocker"]
    HUMAN_ESCALATE --> USER

    %% Styling — orchestrator lane (cool blues/teals/purples)
    style SESSION_START fill:#16A085,color:#fff
    style ROLE_DECLARE fill:#117A65,color:#fff
    style USER fill:#34495E,color:#fff
    style AUTORECALL fill:#1A5276,color:#fff
    style STARCHECK fill:#F39C12,color:#fff
    style STARSHOW fill:#8E44AD,color:#fff
    style STARCONFIRM fill:#F39C12,color:#fff
    style MEMORY fill:#2980B9,color:#fff
    style FOUND fill:#F39C12,color:#fff
    style BRAINSTORM fill:#E91E63,color:#fff
    style PLAN fill:#4A90D9,color:#fff
    style BRANCH_CREATE fill:#1ABC9C,color:#fff
    style STEP fill:#8E44AD,color:#fff
    style GREENFIELD fill:#16A085,color:#fff
    style VERIFY fill:#27AE60,color:#fff

    %% Dispatch arrows (orchestrator → execution boundary)
    style DISPATCH_SIMPLE fill:#D35400,color:#fff
    style DISPATCH_HOTFIX fill:#D35400,color:#fff
    style DISPATCH_ADAPT fill:#D35400,color:#fff
    style DISPATCH_STEP fill:#D35400,color:#fff
    style DISPATCH_FINAL fill:#D35400,color:#fff

    %% Styling — execution lane (warm oranges/greens)
    style DIRECTFIX fill:#E67E22,color:#fff
    style DIRECTPR fill:#2ECC71,color:#fff
    style CI_SIMPLE fill:#F39C12,color:#fff
    style HOTFIXFIX fill:#E67E22,color:#fff
    style HOTFIXPR fill:#2ECC71,color:#fff
    style CI_HOTFIX fill:#F39C12,color:#fff
    style STEPBR fill:#1ABC9C,color:#fff
    style HAS_FRONTEND fill:#F39C12,color:#fff
    style DESIGNER_DISPATCH fill:#D35400,color:#fff
    style DESIGNER_IMPL fill:#9B59B6,color:#fff
    style DESIGNER_WAIT fill:#8E44AD,color:#fff
    style TESTFIRST fill:#F39C12,color:#fff
    style TDDTEST fill:#3498DB,color:#fff
    style IMPLEMENT fill:#3498DB,color:#fff
    style TEST fill:#7B68EE,color:#fff
    style COVERAGE_GATE fill:#F39C12,color:#fff
    style ORACLE_ESC fill:#9B59B6,color:#fff
    style FIXER_CARTO fill:#E67E22,color:#fff
    style STEPPR fill:#2ECC71,color:#fff
    style POSTSTEPS fill:#27AE60,color:#fff
    style MAINPR fill:#2ECC71,color:#fff
    style CODEREVIEW fill:#8E44AD,color:#fff
    style ISSUE_ROUTE fill:#E91E63,color:#fff
    style FIXFINAL fill:#E67E22,color:#fff
    style FINAL fill:#9B59B6,color:#fff
    style CODEMAP_UPDATE fill:#9B59B6,color:#fff
    style CI_GATE fill:#F39C12,color:#fff
    style MERGE_MAIN fill:#27AE60,color:#fff
    style HUMAN_ESCALATE fill:#C0392B,color:#fff
    style DONE fill:#27AE60,color:#fff
```

> **Reading the swimlane diagram:**
> - **🎯 Orchestrator lane** — everything the main session (opus) does directly: classify, plan, decide, dispatch. Never writes code or runs dev commands for medium/heavy.
> - **📤 Dispatch nodes** (orange diamonds) — the boundary where the orchestrator hands work to `lean-flow:fixer`. Five dispatch points: simple, hotfix, adapt-pattern, step, and final-PR.
> - **🔧 Execution lane** — everything `lean-flow:fixer` (haiku) and reviewers (sonnet) do: implement, test, lint, commit, push, PR, code-review, oracle review, codemap, merge.
> - **Loop-back** — `STEPPR → STEP` and `MERGE_MAIN → VERIFY → DONE` arrows show execution reporting back into the orchestrator lane for next-step control / final verification.
> - **🎨 Designer node** — parallel to fixer on step branches when frontend work is present. Designer commits to step branch, fixer opens the PR. No separate designer PR.
> - **🔀 Issue routing** — fixer classifies review feedback: backend → fixer, frontend → designer, cross-cutting → both parallel. Re-verify and re-request review until both APPROVED.
> - **Explorer cartography** — after each fixer/designer commit, orchestrator dispatches explorer to update `codemap.md` for changed folders (scoped, not full repo).

## Skill → Agent Mapping

| Agent | Required Skills | Model | Dispatched When |
|---|---|---|---|
| **orchestrator** | `superpowers:using-superpowers` → `superpowers:writing-plans` → `superpowers:dispatching-parallel-agents` | opus | Main session — never spawned. Coordinates tier routing, planning, dispatch. |
| **fixer** | `superpowers:executing-plans` → `superpowers:test-driven-development` → `superpowers:verification-before-completion` → `superpowers:finishing-a-development-branch` → `superpowers:requesting-code-review` | haiku | Medium/heavy tasks. Owns full impl → test → lint → commit → PR → review loop → merge. Routes review feedback to fixer/designer/both. |
| **designer** | `frontend-design:frontend-design` → `superpowers:executing-plans` → `superpowers:test-driven-development` → `superpowers:verification-before-completion` | sonnet | Step has frontend work. Implements UI/components, writes tests, commits to step branch. **Stops before PR** — fixer opens PR and manages review. |
| **oracle** | `superpowers:receiving-code-review` + `claude-md-management:claude-md-improver` (when diff touches CLAUDE.md / agents/*.md / workflows/*.md) | sonnet | PR review after code-reviewer. Think-only (tools:[]). Architecture + security audit. Final approval gate before merge. |
| **code-reviewer** | `superpowers:receiving-code-review` + `superpowers:verification-before-completion` | sonnet | Step or parent PR review. Code-quality, SOLID, patterns, coverage. Returns APPROVED or numbered issues. |
| **explorer** | `lean-flow:cartography` (post-commit per-folder) + on-demand: `lean-flow:map-codebase`, `lean-flow:phase-researcher`, `lean-flow:assumptions-analyzer` | haiku | After every fixer/designer commit, orchestrator dispatches explorer for cartography on changed folders only. Also on-demand for discovery/research. |
| **librarian** | Context7 MCP + WebSearch + WebFetch (tools = the skill) | haiku | When researching library APIs, documentation, best practices. No plugin-defined skill — tool-native. |

**Key contracts:**
- Designer commits + stops; fixer opens PR and manages feedback loops
- Oracle validates CLAUDE.md / agents/*.md / workflows/*.md during rule-file PRs
- Explorer cartography is mandatory per-commit (scoped to changed folders), not optional
- Fixer routes review feedback per IssueRoutingRules (orchestrator.md) — backend to fixer, frontend to designer, cross-cutting to both parallel

## Branch Naming Convention

| Prefix | When to use | Example |
|--------|------------|---------|
| `feature/` | New functionality | `feature/user-onboarding` |
| `fix/` | Bug fixes | `fix/login-redirect-loop` |
| `improvement/` | Refactors, performance | `improvement/query-optimization` |
| `security/` | Security patches | `security/xss-sanitization` |
| `test/` | Test-only changes | `test/backend-model-coverage` |
| `docs/` | Documentation | `docs/api-reference` |
| `chore/` | Dependencies, CI, config | `chore/upgrade-rails-8.2` |
| `hotfix/` | Urgent production fixes | `hotfix/payment-crash` |
| `release/` | Release prep, version bumps, changelog | `release/v2.1.0` |
| `experiment/` | Spikes, prototypes (may be discarded) | `experiment/graphql-subscriptions` |
| `revert/` | Reverting a bad merge | `revert/broken-auth-flow` |

**Step branches** append `/step-N` to the parent: `feature/user-onboarding/step-1`

**Rules:**
- Always kebab-case
- Short but descriptive
- Never generic (`feature/update`, `fix/bugfix`)

## Branching Strategy

```
main
 └── <prefix>/name              ← parent branch (1 per plan)
      ├── <prefix>/name/step-1  ← PR #1 → parent
      ├── <prefix>/name/step-2  ← PR #2 → parent (after #1 merged)
      ├── <prefix>/name/step-3  ← PR #3 → parent
      └── (all steps merged)
           └── security audit on parent
                ├── issues → fixer implements fix, oracle reviews
                └── clean → PR parent → main

Hotfix (fast path):
main
 └── hotfix/name                ← branch directly from main
      └── fix + test → PR → oracle inline review → merge to main
```

## Flow Rules

### 1. Triage (Orchestrator — no agent cost)
- **First**: Check if `docs/CODEBASE_MAP.md` exists. If not, run `/cartographer` to map the repo before starting work.
- **Simple** tasks (1-2 files, clear change): fixer implements → tests → PR to main
- **Complex** tasks: continue to pattern search + planning
- **Greenfield** (new project, empty repo): doc-first path → brainstorm → generate docs → plan → build
- **Hotfix** (production emergency): fast path — skip planning, minimal review

### 1a. Auto Pattern Recall (UserPromptSubmit hook — automatic)
Before any work begins, `pattern-recall.sh` fires automatically on every prompt:
- Extracts keywords from the prompt (stop words filtered, top 8 terms)
- Runs FTS5 full-text search against `patterns.db`
- Project-scoped first, falls back to all projects
- Injects matching patterns as `hookSpecificOutput` — **zero tokens if no match**
- Supplements (does not replace) the manual `pattern_search` in the complex path

### 1b. STAR Clarification (UserPromptSubmit hook — medium/heavy tasks only)
After pattern recall fires, `star-clarify.sh` classifies the prompt complexity via haiku:
- **Simple** (1-2 file changes, bug fix, quick config): skipped — zero tokens overhead
- **Medium** (multi-file feature, refactor, new script): STAR expansion generated
- **Heavy** (new system, major architecture, multi-phase): STAR expansion generated

For medium/heavy tasks, haiku generates a STAR breakdown:
- **S — Situation:** context and challenge
- **T — Task:** specific goal
- **A — Action:** planned approach
- **R — Result:** expected deliverable

The orchestrator shows this to the user and asks for confirmation **before doing any work**. The user replies `yes` to proceed or describes what's different. This eliminates misunderstandings on costly multi-file tasks without adding friction to simple ones.

Short prompts (<50 chars) and follow-up messages (`yes`, `ok`, `proceed`, etc.) are automatically skipped.

### 1c. Brownfield Orientation (complex tasks on existing codebases)
Before brainstorming on complex tasks in existing codebases:
- **`lean-flow:map-codebase`** — Spawn parallel explorer (haiku) agents across 7 dimensions (stack, architecture, structure, integrations, conventions, testing, concerns). Token-efficient — haiku only.
- **`lean-flow:ingest-docs`** — If ADRs, PRDs, or SPECs exist, extract locked decisions and surface conflicts before planning. ADR decisions are treated as locked unless user overrides.

### 2. Pattern Search (knowledge MCP)
- `pattern_search` for previously solved patterns
- Match found: fixer applies pattern, skip planning, enter step loop
- No match: proceed to brainstorming + `superpowers:writing-plans`

### 3. Brainstorming
- **`lean-flow:brainstorming`** — auto-invoked before planning for complex tasks
- Explores user intent, requirements, and design before implementation
- Hard gate: no implementation until design is approved
- Output feeds into `superpowers:writing-plans`

### 3a. Pre-Planning Research
Before EnterPlanMode on medium/heavy tasks:
- **`lean-flow:phase-researcher`** — Answers "what do I need to know to plan this well?" Verifies library APIs, patterns, pitfalls via Context7 + docs + web search. Tags every finding as [VERIFIED] or [ASSUMED].
- **`lean-flow:assumptions-analyzer`** — Scans codebase for evidence behind every plan assumption. Classifies as Confident/Likely/Unclear with file citations. Unclear assumptions block planning until resolved.
- **`lean-flow:spike`** — When assumptions-analyzer flags UNCLEAR items, run a throwaway 15-min experiment to validate feasibility before committing to a plan.

### 3b. Greenfield: Doc-First Development
For new projects (empty repos), generate project documentation **before** planning code:

1. **Brainstorm** — discuss product concept, target users, core features, tech stack
2. **Generate docs** — spawn parallel sonnet agents to create:
   - **PRD** — product requirements, user stories, MVP scope
   - **HLA** — high-level architecture, system diagram, component breakdown
   - **TRD** — technical requirements, data models, implementation specs (umbrella for below)
   - **Database Design** — detailed TRD spec: full DDL, indexes, spatial queries, seed data
   - **API Design** — detailed TRD spec: all endpoints with request/response contracts
   - **Architecture** — ADRs, DDD bounded contexts, migration path
3. **Split TRD per repo** — in multi-repo projects, keep docs scoped per repo to avoid token bloat
4. **Plan from docs** — use generated docs as the reference for implementation planning

> **Why docs first?** Generated docs become the single source of truth for all agents. The TRD feeds directly into `superpowers:writing-plans` task breakdown. Without docs, each agent re-derives requirements from scratch — wasting tokens and introducing inconsistencies.

### 4. Planning (superpowers:writing-plans)
- `EnterPlanMode` — opens plan file at `~/.claude/plans/`
- Invoke **`superpowers:writing-plans`** for the structured plan (exact file paths, code blocks, TDD steps, no placeholders)
- Write the plan to the plan mode file (wrong directory blocked by `block-wrong-plan-dir.sh` hook)
- User MUST review and approve before execution
- `ExitPlanMode` — finalize plan
- **`lean-flow:plan-checker`** runs after ExitPlanMode — 8-dimension goal-backward verification before any fixer is dispatched. BLOCKER issues send plan back for revision.
- Plan viewer opens at localhost:3456
- Execute via **`superpowers:executing-plans`** (replaces deprecated plan-plus)

### 5. Branching
- Create parent branch: `<prefix>/<name>` from main
- Each step gets its own branch: `<prefix>/<name>/step-N` from parent
- Steps are sequential — step-2 branch created after step-1 PR is merged into parent
- If step branch has conflicts with parent: rebase step branch onto parent
- **Solo dev exception:** skip step branches, commit directly on parent (see §6a)

### 6. Execute Steps (sequential, parallel fixers within)
- For each step:
  1. Create step branch from parent
  2. **TDD** (always for features): invoke `lean-flow:test-driven-development` — RED (failing test) → GREEN (minimal code) → REFACTOR. Non-negotiable gate.
  3. Dispatch fixer(s) — parallel for independent sub-tasks within the step
  4. Fixer implements + writes tests
  5. **Fixer self-verify** — run done checklist (always + conditional items)
  6. Run tests
  7. Create PR: step branch → parent branch
  8. Merge step PR into parent (no oracle review — saves tokens)
     Oracle only reviews the final parent→main PR
  9. Loop to next step

### 6a. Solo Dev: Skip Step Branches
When working solo (no team reviewers, no CI per step), per-step PRs are pure overhead:

- **Work on parent branch** — no step branches, no per-step PRs. Commit once at the end or per logical group
- **Still use `superpowers:writing-plans` steps** — steps structure the work, but don't need separate branches
- **Run `superpowers:executing-plans` per step** — each step dispatched with checkpoints
- **Parallel independent steps** — steps with no dependency can run as parallel agents
- **Single PR: parent → main** — oracle review + audit on the final diff

**When to use per-step PRs instead:**
- Team with reviewers needs to approve each step
- CI/CD runs per PR (integration tests, deploy preview)
- Steps are large enough to warrant isolated review

### 7. Re-planning (mid-execution escape hatch)
- If a step reveals the plan is wrong (assumptions broken, scope changed):
  - Pause execution at the STEP decision node
  - Re-invoke `superpowers:writing-plans` to revise remaining steps
  - User reviews revised plan
  - Continue execution from the revised steps

### 8. Agent Model Routing
| Agent | Model | Reads files? | Writes files? | When |
|-------|-------|-------------|---------------|------|
| Explorer | haiku | Yes | No | File discovery, codebase navigation, codebase map scanning, pre-oracle diff reading |
| Librarian | haiku | Yes | No | Docs, API lookup, web search |
| Fixer | haiku | Yes | Yes | All implementation + 90% test coverage + run tests + linters + commit + push + PR creation + oracle review loop + merge — full end-to-end for medium/heavy tasks |
| Oracle | sonnet | **No** | **No** | Architecture decisions, code review, security audit, codebase map synthesis (think-only) |
| Designer | sonnet | Yes | Yes | UI/UX, frontend components |
| Orchestrator | opus | — | — | Triage, PR creation, reviews auditor fixes (no agent cost) |

> **Oracle is think-only — hard prohibited from Write/Edit/Bash.** Oracle has `tools: []`. It receives summaries from explorer via orchestrator, returns text instructions only. Never writes code. If oracle needs file content, it tells orchestrator what to ask explorer to fetch.

> **Orchestrator never writes files or runs dev commands directly.** git, grep, npm test, file reads — all delegated to `explorer` (read-only) or `fixer` (write + execute). Enforced via global CLAUDE.md rules. Use the `delegate-to-haiku` skill as reference. Orchestrator stays thin: triage, dispatch, decide.

> **All Bash output is automatically compressed.** RTK strips verbose output on every command. For outputs >25 lines (git log, npm test, grep -r, etc.), `auto-compress-output.sh` pipes through haiku, returns a summary, and blocks the original call. Zero manual effort.

### 8a. Background Agent Visibility
All sessions — including background sub-agents Claude spawns invisibly — are tracked via hooks:
- **PreToolUse / PostToolUse / Stop** hooks write state to `/tmp/claude-sessions/{session_id}.json`
- **SwiftBar** menu bar shows all active sessions: `🟢 6%(21m)┊24%(3d) · 2⚡`
- Clicking a session row opens a live terminal viewer (`claude-session-view.sh`) showing tool history with timestamps
- No extra API calls, no tokens — hook-only, file-based state

### 8b. Fixer Done Checklist
Fixer invokes **`lean-flow:verification-before-completion`** before reporting back — evidence before assertions, always:

**Always:**
- Tests pass, deterministic, cover error/edge cases
- No debug artifacts, secrets, or sensitive data in logs
- No N+1, unbatched loops, or injection vectors
- No over-engineering, no duplicate logic
- Naming consistent, files <500 lines, matches existing patterns
- Errors actionable and traceable (context IDs, not sensitive data)
- Release notes accurate for user-facing changes

**If touching DB/API:** migrations reversible, indexes, no breaking changes, pagination, input validated
**If async/jobs:** idempotent, retry-safe, race conditions handled, dead-letter/failure handling
**If risky/new:** feature flags, safe env defaults, dependencies justified, logs for critical flows

### 8c. Code Review
Use **`lean-flow:code-reviewer`** (dedicated sonnet agent) for code review — separate from oracle's architecture role.
**`lean-flow:code-reviewer`** checks: spec compliance, code quality, patterns, error handling, naming, test coverage, security, performance, SOLID principles. Returns APPROVED or numbered issues (Critical / Important / Suggestion).

### 8d. Oracle Review Checklist
Oracle verifies architecture and system-level concerns before returning APPROVED.

**Oracle hard rules (enforced via `tools: []`):**
- Never use Write, Edit, or Bash — express all fixes as text: "In `src/foo.py` line 42, change X to Y"
- Never read files directly — tell orchestrator what to ask explorer to fetch
- Return APPROVED or a numbered list of issues with severity and exact location

- PR description matches actual changes, scoped to request
- Architecture fits system, follows domain boundaries
- No unintended behavior changes beyond what was requested
- Simplicity vs flexibility balanced, no over-abstraction
- Impact to other services analyzed, rollback strategy exists
- Safe to deploy gradually, no downtime risk
- Compatible with current infra
- Hot paths reviewed, cache strategy considered
- API contracts consistent, versioned if behavior changes
- Third-party limits/rate limits considered
- Matches business intent, edge cases align with real user behavior
- Error handling aligns with UX expectations

**Post-approval — hybrid codemap update (§12a):**
- **Tier 2 (always):** run `cartographer.py changes` → explorer fills affected `codemap.md` → fixer writes → `cartographer.py update`
- **Tier 1 (if structural):** new/removed modules or major architectural shifts → Sonnet subagents update relevant sections of `docs/CODEBASE_MAP.md`

### 9. Bug Handling + Test + Retry
**Any bug, test failure, or unexpected behavior:** invoke **`lean-flow:systematic-debugging`** first — root cause before fix, always. No ad-hoc fixes.

- Run tests after each step
- Retry fixer up to 2x on failure
- 3rd failure: explorer reads error context → orchestrator passes summary to oracle → oracle diagnoses
- Oracle provides guidance → Fixer implements fix
- After 3 oracle escalations on the same step: flag for human intervention

### 10. Security Audit (once, after ALL steps merged into parent)
Before the security audit, run goal verification:
- **`lean-flow:verifier`** — Checks each deliverable is exists + substantive + wired + data-flowing. Catches stubs and disconnected implementations.
- **`lean-flow:nyquist-auditor`** — Fills test coverage gaps. Generates behavioral tests for uncovered requirements. Read-only on implementation files.

Then the security audit proceeds:
- **Explorer** (haiku) reads the full parent branch diff vs main → produces structured summary
- **Oracle** (sonnet, think-only) audits from explorer's summary — security issues, N+1, diff risk
- **Special attention:** database migrations (table locks, backward compat, reversibility)
- If issues found: **Fixer** implements fix on parent → **Explorer** re-reads → **Oracle** reviews
- Re-audit until clean (max 3 rounds, then escalate to human)

### 11. Commit & PR Style

**Commits:** `<type>: <what changed>` — lowercase, under 72 chars, no period.
Types: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `perf`, `security`

**Two PR templates:**

| PR Type | Template | Audience | Release Notes? |
|---------|----------|----------|----------------|
| Step → parent | `PULL_REQUEST_TEMPLATE.md` | Developer reviewing the step | No |
| Parent → main | `PULL_REQUEST_TEMPLATE_MAIN.md` | Team + stakeholders | **Yes, required** |
| Simple fix → main | `PULL_REQUEST_TEMPLATE_MAIN.md` | Team + stakeholders | **Yes, required** |
| Hotfix → main | `PULL_REQUEST_TEMPLATE_MAIN.md` | Team + stakeholders | **Yes, required** |

**Any PR to main/master MUST include release notes.** Written for end users, not developers.

### 12. Final PR: Parent → Main (MUST include release notes)
- Invoke **`lean-flow:finishing-a-development-branch`** — structured options for merge/PR/cleanup decision
- Create PR from parent branch into main
- **Explorer** scans PR diff → **`lean-flow:code-reviewer`** reviews code quality → **Oracle** reviews architecture
- Issues → fix on parent → re-review cycle
- Approved → hybrid codemap update → learn + merge

### 12a-prefix. Fixer-Driven Final PR (medium/heavy tasks)

For medium/heavy tasks, the orchestrator does not manually drive the final PR cycle. Instead, the fixer who executed the plan owns it end-to-end:

1. **Fixer creates the parent → main PR** with release notes.
2. **Fixer dispatches `lean-flow:code-reviewer`** (sonnet) for code quality review.
3. **Fixer dispatches `oracle`** (sonnet, think-only) for architecture review.
4. **Fixer applies issues** from both reviews, re-runs tests + linters, pushes, and re-requests review until clean (max 3 rounds combined).
5. **Fixer triggers the hybrid codemap update** (§12a) before merge.
6. **Fixer merges the PR**.

The orchestrator only intervenes if fixer hits the 3-round cap or surfaces an explicit blocker.

### 12a. Hybrid Codemap Update (after Oracle approval)

After approving a PR, update both tiers of the codemap system before merging:

#### Tier 2: Per-Folder Codemaps (always, cheap)
1. Run `cartographer.py changes --root <repo>` to identify affected folders
2. If no changes: skip to Tier 1 check
3. For each affected folder: dispatch **Explorer** (haiku) to read files and fill `codemap.md`
4. **Fixer** writes updated `codemap.md` files
5. Run `cartographer.py update --root <repo>` to record new hashes

#### Tier 1: CODEBASE_MAP.md (conditional, only for structural changes)
After Tier 2 is done, check if the PR introduced **major structural changes**:
- New modules/directories added
- Directories removed or renamed
- Significant architectural shifts (new entry points, changed data flow)

**If yes:**
1. Run `scan-codebase.py . --format json` for updated token counts
2. Spawn **Sonnet subagents** to re-analyze only the changed modules (read + synthesize)
3. **Fixer** (haiku) writes the updated sections to `docs/CODEBASE_MAP.md` (merge with existing, don't regenerate everything)
4. **Fixer** updates `last_mapped` timestamp

**If no:** Skip — `docs/CODEBASE_MAP.md` stays as-is.

> **Cost:** Tier 2 runs on every PR (~200 tokens per folder, haiku only). Tier 1 runs rarely (~10% of PRs, Sonnet subagents). Total overhead is minimal for routine PRs, thorough for structural ones.

### 12b. CI Codemap Auto-Update (on push to main)
After merge to main, GitHub Actions automatically updates codemaps for changed directories:
- Detects changed directories from `git diff HEAD~1 HEAD`
- For each directory with an existing `codemap.md`: reads files (up to 20, 120 lines each) and calls Claude Haiku to regenerate the 4-section codemap
- Commits updated files with `[skip ci]` — no infinite loop
- Only touches directories that actually changed — unrelated codemaps are never overwritten
- Requires `ANTHROPIC_API_KEY` secret in GitHub repo settings

### 12c. PR Review Comment Convention
When `lean-flow:code-reviewer` or `lean-flow:oracle` reviews a GitHub PR:

**Summary comments:**
- Always post a summary comment as the final action via `gh pr comment <PR>`
- Prefix the comment with `CODE_REVIEWER_AGENT: <verdict>` or `ORACLE_AGENT: <verdict>`
- Verdicts: `✅ APPROVED` or `⚠️ CHANGES_REQUESTED` (never `❌ REJECTED`)
- Follow prefix with full review body (findings, rationale, suggested fixes)

**Per-file inline comments:**
- Post file-specific findings via `gh pr review <PR> --comment -F <tmpfile>`
- Each inline comment body starts with the agent tag (`CODE_REVIEWER_AGENT:` or `ORACLE_AGENT:`) for authorship clarity

**Label semantics (oracle manages these):**
- On PR create: fixer adds `for review` label (orange #ffa500) and assigns to self
- Code-reviewer posts verdict:
  - `⚠️ CHANGES_REQUESTED` → fixer swaps `for review` → `reviewed` (blue)
  - `✅ APPROVED` → fixer leaves label as-is for oracle
- Oracle posts verdict:
  - `⚠️ CHANGES_REQUESTED` → oracle keeps `reviewed` (no change)
  - `✅ APPROVED` → oracle swaps `reviewed` → `ready to merge` (green) AND calls `gh pr review <PR> --approve`

**Idempotency:**
- Hook (`post-agent-review.sh`) runs on `SubagentStop` to post fallback verdict comments
- Checks if a comment with the agent prefix already exists on the PR before posting (prevents duplicates)
- Silently exits if: agent is not a reviewer, PR context missing, no verdict found, or comment already posted

### 13. Hotfix Fast Path 🔥
- For production emergencies only (critical bugs, security vulnerabilities)
- Branch `hotfix/<name>` directly from main (no parent branch, no step branches)
- Fixer implements minimal fix + tests
- Oracle does inline review (combined code + security review in one pass)
- PR directly to main with release notes
- After merge: cherry-pick into any in-flight feature parent branches

### 14. Post-Merge
- **Monitor:** watch for errors after merge (Sentry, logs, CI)
- **Rollback:** if the merge breaks production, create a `hotfix/revert-<feature>` branch with `git revert` and fast-track through the hotfix path
- **Fix-forward vs revert:** prefer fix-forward for minor issues, revert for critical breakage

### 15. Learn (pattern_store + auto-observe)

**Manual — `pattern_store`:**
- Store successful patterns via knowledge MCP after solving a non-trivial problem
- Tags: task type, files touched, approach used
- Future sessions retrieve instead of re-reasoning

**Automatic — `auto-observe` (Stop hook):**
- Fires on every session end with zero tokens and no API calls
- Reads the session log, writes a 1-line tool-usage observation to `patterns.db`
- Format: `lean-flow | main | Bash×12, Edit×5 | git commit×3 [45m]`
- Stored with `category = session-observation` — excluded from pattern recall to avoid noise
- Builds a passive usage history without any manual effort

### 16. Session Briefing (SessionStart hook)

`session-briefing.sh` runs on every SessionStart and emits two parts:

**Part A — Orchestrator role declaration (always fires, never cached):**
- Injected as `hookSpecificOutput.additionalContext` on every session start
- Declares the main Claude Code session IS the orchestrator (opus)
- Points to the canonical contract at `${CLAUDE_PLUGIN_ROOT}/agents/orchestrator.md`
- Restates tier routing (simple → direct edit · medium/heavy → plan + delegate `lean-flow:fixer` end-to-end · greenfield → docs-first · hotfix → fast path)
- Restates hard rules (no direct code edit on medium/heavy, no push to main, no `--no-verify`, no AI attribution, 3-round review cap)
- Points to the canonical workflow at `${CLAUDE_PLUGIN_ROOT}/workflows/standard-development-flow.md`
- Cost: ~120 tokens per session start — small price to keep the orchestrator in role across compacts/restarts

**Part B — Repo / branch / pattern briefing (cached per state):**
- Fires once per unique (repo, branch, working-tree, top-3 patterns) state
- Computes `md5(repo + branch + git_status + pattern_sig)` and caches to `/tmp/`
- **Zero tokens on repeat sessions** — no `systemMessage` if nothing changed
- When state changes: injects repo name, branch, dirty files, and top-3 patterns as `systemMessage`
- Pattern bullets come from `patterns.db` score-ordered query — max ~100 tokens, never per-prompt

### 17. Auto-Dream (Stop hook — background)
- Runs on session end (every 5 sessions / 24h)
- Consolidates memory, removes duplicates, prunes stale entries
- Uses haiku in background — zero interactive cost

## Plugin Structure

```
plugin/                         ← plugin source (installed as ${CLAUDE_PLUGIN_ROOT})
├── agents/                     ← agent definitions (explorer, fixer, oracle, designer, librarian)
├── hooks/
│   └── hooks.json              ← all lifecycle hooks (SessionStart, PreToolUse, PostToolUse, Stop)
├── mcp-servers/
│   └── knowledge/              ← SQLite knowledge MCP server (auto-installed on SessionStart)
├── scripts/
│   ├── claude-monitor/         ← SwiftBar plugin + session tracker + live viewer
│   ├── block-*.sh              ← guard rails (no --no-verify, no direct push to main, etc.)
│   ├── ensure-*.sh             ← idempotent setup scripts (run on SessionStart)
│   ├── session-briefing.sh     ← cached session context injection
│   ├── pattern-recall.sh       ← auto FTS5 recall on every prompt
│   ├── knowledge-prefilter.sh  ← FTS5 pattern surface on EnterPlanMode
│   ├── auto-observe.sh         ← passive session observation on Stop
│   └── auto-update-codemaps.*  ← local codemap update after git commit
└── skills/                     ← cartography skill definition

scripts/                        ← CI tools (not shipped in plugin)
└── ci-update-codemaps.py       ← GitHub Actions codemap updater
```
