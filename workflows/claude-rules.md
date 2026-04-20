# lean-flow: Rules for Claude

CRITICAL: Use lean-flow commands only. Never suggest /gsd-* commands.

## Mandatory Skill Triggers

These are NON-NEGOTIABLE — always invoke before proceeding:

| Situation | Must invoke |
|---|---|
| Any bug / test failure / unexpected behavior | `lean-flow:systematic-debugging` |
| Before writing implementation code | `lean-flow:test-driven-development` |
| Before claiming complete / creating PR | `lean-flow:verification-before-completion` |
| Implementation done, ready to merge | `lean-flow:finishing-a-development-branch` |
| Code review requested | `lean-flow:code-reviewer` |

## Escalation Rule

- Fixer fails same step 3 times → stop retrying → oracle diagnoses
- Oracle escalates 3 times on same step → flag for human intervention
- Never retry blindly — diagnose root cause first

## Branch Naming

| Prefix | When |
|---|---|
| `feature/` | New functionality |
| `fix/` | Bug fixes |
| `improvement/` | Refactors, performance |
| `security/` | Security patches |
| `hotfix/` | Urgent production fixes |
| `chore/` | Dependencies, CI, config |
| `docs/` | Documentation only |

Step branches: `feature/name/step-1`, `feature/name/step-2`
Rules: always kebab-case, short but descriptive, never generic.

## Branching Strategy

```
main
 └── feature/name              ← parent branch (1 per plan)
      ├── feature/name/step-1  ← PR → parent
      ├── feature/name/step-2  ← PR → parent (after step-1 merged)
      └── (all steps merged) → security audit → PR parent → main
```

## Flow Rules

### 1. Triage
- Check `docs/CODEBASE_MAP.md` exists — if not, run `/cartographer` first
- **Simple** (1-2 files, clear change): fixer → tests → PR to main
- **Complex**: pattern search → research → brainstorm → plan → execute
- **Greenfield**: doc-first → brainstorm → PRD/HLA/TRD → plan → build
- **Hotfix**: fast path — skip planning, minimal review

### 1c. Brownfield Orientation (complex tasks on existing codebases)
- `lean-flow:map-codebase` — map repo across 7 dimensions before planning
- `lean-flow:ingest-docs` — extract locked decisions from ADRs/PRDs/SPECs

### 2. Pattern Search
- Search knowledge MCP for previously solved patterns
- Match found: fixer applies pattern, skip planning
- No match: brainstorm → plan-plus

### 3. Brainstorming
- Auto-invoked before planning for complex tasks
- Explore intent, requirements, design before implementation

### 3a. Pre-Planning Research
- `lean-flow:phase-researcher` — verify APIs, patterns, pitfalls. Tag [VERIFIED] or [ASSUMED]
- `lean-flow:assumptions-analyzer` — scan codebase for evidence. Unclear assumptions block planning
- `lean-flow:spike` — 15-min throwaway experiment when assumptions are UNCLEAR

### 3b. Greenfield: Doc-First
Generate before writing code: PRD → HLA → TRD (Database Design + API Design + Architecture).
Split TRD per repo in multi-repo projects.

### 4. Planning
- `EnterPlanMode` → invoke `writing-plans` skill → write plan → `ExitPlanMode`
- `lean-flow:plan-checker` runs after ExitPlanMode — 8-dimension verification. BLOCKER = revise plan
- User MUST approve before execution

### 5. Branching
- Create parent branch from main, step branches from parent
- Steps are sequential — step-2 after step-1 PR merged
- **Solo dev**: skip step branches, work on parent, single PR to main

### 6. Execute Steps
1. Create step branch
2. TDD: fixer writes failing tests first (if applicable)
3. Dispatch fixer(s) — parallel for independent sub-tasks
4. Fixer implements + tests
5. Fixer runs done checklist (§8b)
6. Run tests → create PR step → parent → merge
7. Oracle only reviews final parent→main PR

### 6a. Solo Dev
- Work on parent branch, no step PRs
- Still use plan-plus steps to structure work
- Parallel agents for independent steps
- Single PR: parent → main with oracle review

### 7. Re-planning
If a step breaks assumptions: pause → revise plan with plan-plus → user approves → continue.

### 8. Agent Model Routing

| Agent | Model | Reads | Writes | When |
|---|---|---|---|---|
| Explorer | haiku | Yes | No | File discovery, codebase nav, pre-oracle diff |
| Librarian | haiku | Yes | No | Docs, API lookup, web search |
| Fixer | haiku | Yes | Yes | All implementation |
| Oracle | sonnet | No | No | Review, audit, decisions (think-only) |
| Designer | sonnet | Yes | Yes | UI/UX, frontend |
| Orchestrator | opus | — | — | Triage, dispatch |

**Oracle is think-only** — hard prohibited from Write/Edit/Bash. Returns text instructions only.
**Orchestrator never writes files or runs dev commands** — always delegates to explorer/fixer.

### 8b. Fixer Done Checklist
Always verify before reporting done:
- Tests pass, deterministic, cover edge cases
- No debug artifacts, secrets, or sensitive data
- No N+1, injection vectors, over-engineering
- Naming consistent, files <500 lines, matches patterns
- Errors actionable and traceable

If touching DB/API: migrations reversible, indexes added, no breaking changes, input validated.
If async/jobs: idempotent, retry-safe, race conditions handled.

### 8c. Oracle Review Checklist
- Never use Write/Edit/Bash — express fixes as text with file+line reference
- Return APPROVED or numbered issues with severity + location
- Check: architecture fit, no unintended behavior, simplicity balanced, rollback exists
- API contracts consistent, third-party limits considered, matches business intent

### 9. Test + Retry
- Run tests after each step
- Retry fixer up to 2x on failure
- 3rd failure: explorer reads error → orchestrator → oracle diagnoses → fixer fixes
- 3 oracle escalations on same step: flag for human

### 10. Security Audit (after ALL steps merged to parent)
- `lean-flow:verifier` — verify each deliverable exists, wired, data-flowing
- `lean-flow:nyquist-auditor` — fill test coverage gaps
- Explorer reads full diff → Oracle audits → Fixer fixes → repeat until clean (max 3 rounds)

### 11. Commit & PR Style
Commits: `<type>: <what>` — lowercase, under 72 chars.
Types: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `perf`, `security`

Step→parent PR: developer-facing, no release notes needed.
Parent→main PR: **must include release notes** written for end users.

### 12. Final PR: Parent → Main
- Explorer scans diff → Oracle reviews → Fixer fixes → repeat until approved
- After approval: update codemaps (Tier 2 always, Tier 1 if structural changes)
- Merge

### 13. Hotfix Fast Path
- Branch `hotfix/<name>` from main
- Fixer: minimal fix + tests
- Oracle: combined code + security review
- PR directly to main with release notes
- Cherry-pick into in-flight feature branches after merge

### 14. Post-Merge
- Monitor: watch errors (Sentry, logs, CI)
- Rollback: `hotfix/revert-<feature>` with `git revert` if critical breakage
- Prefer fix-forward for minor issues, revert for critical
