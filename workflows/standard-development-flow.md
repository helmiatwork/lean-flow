# Standard Development Flow

## Mermaid Diagram

```mermaid
flowchart TD
    USER(["👤 User prompt"]) --> TRIAGE

    TRIAGE{"🎯 Orchestrator\ntriages complexity"}
    TRIAGE -->|"Simple"| DIRECT["Orchestrator\nhandles directly"]
    TRIAGE -->|"Complex"| MEMORY

    MEMORY["🧠 pattern_search\nKnowledge MCP"] --> FOUND

    FOUND{"Match?"}
    FOUND -->|"Yes"| ADAPT["Apply pattern"]
    FOUND -->|"No"| PP

    ADAPT --> BRANCH
    DIRECT --> DONE(["✅ Done"])

    PP["📋 plan-plus\nGenerate plan"] --> REVIEW

    REVIEW{"Approved?"}
    REVIEW -->|"No"| PP
    REVIEW -->|"Yes"| BRANCH

    BRANCH["🌿 Create parent branch"] --> STEP

    STEP{"Next step?"}
    STEP -->|"Yes"| RESEARCH
    STEP -->|"All done"| AUDIT

    RESEARCH{"Needs research?"}
    RESEARCH -->|"Unfamiliar code"| EXPLORER["🔍 Explorer\n(haiku)"]
    RESEARCH -->|"Need docs"| LIBRARIAN["📚 Librarian\n(sonnet)"]
    RESEARCH -->|"No"| STEPBR

    EXPLORER --> STEPBR
    LIBRARIAN --> STEPBR

    STEPBR["🌿 Step branch\nprefix/name/step-N"] --> FIX

    FIX["🔧 Fixer\n(sonnet, parallel)"] --> TESTWRITE

    TESTWRITE["🧪 Tester\n(sonnet)\nWrite/verify tests"] --> TEST

    TEST["Run tests"]
    TEST -->|"Fail x3"| ORACLE_ESC["🔮 Oracle\n(opus)\nDiagnosis"]
    ORACLE_ESC --> FIX
    TEST -->|"Pass"| STEPPR

    STEPPR["PR step → parent"] --> STEPREV

    STEPREV["🔮 Oracle\n(opus)\nReview step PR"]
    STEPREV -->|"Issues"| FIX
    STEPREV -->|"Approved"| MERGE_STEP["Merge to parent"]
    MERGE_STEP --> STEP

    AUDIT["🔒 Auditor\n(sonnet)\nSecurity scan\nfull parent diff"] --> CLEAN

    CLEAN{"Issues?"}
    CLEAN -->|"Found"| FIXAUDIT["🔮 Oracle creates\nfix PR → parent"]
    CLEAN -->|"Clean"| MAINPR

    FIXAUDIT --> AUDITREV["🎯 Orchestrator\nreviews fix"]
    AUDITREV --> AUDIT

    MAINPR["PR parent → main"] --> FINAL

    FINAL["🔮 Oracle\n(opus)\nFinal review"]
    FINAL -->|"Issues"| FIXFINAL["🔧 Fixer\nfix on parent"]
    FINAL -->|"Approved"| LEARN

    FIXFINAL --> FINAL
    LEARN["🧠 pattern_store\nSave patterns"] --> MERGE_MAIN(["✅ Merge to main"])

    style USER fill:#34495E,color:#fff
    style TRIAGE fill:#8E44AD,color:#fff
    style MEMORY fill:#2980B9,color:#fff
    style FOUND fill:#F39C12,color:#fff
    style ADAPT fill:#2980B9,color:#fff
    style DIRECT fill:#27AE60,color:#fff
    style PP fill:#4A90D9,color:#fff
    style REVIEW fill:#F39C12,color:#fff
    style BRANCH fill:#1ABC9C,color:#fff
    style STEP fill:#8E44AD,color:#fff
    style STEPBR fill:#1ABC9C,color:#fff
    style FIX fill:#E67E22,color:#fff
    style FIXAUDIT fill:#E67E22,color:#fff
    style FIXFINAL fill:#E67E22,color:#fff
    style TEST fill:#7B68EE,color:#fff
    style AUDIT fill:#E74C3C,color:#fff
    style MAINPR fill:#2ECC71,color:#fff
    style RESEARCH fill:#F39C12,color:#fff
    style EXPLORER fill:#3498DB,color:#fff
    style LIBRARIAN fill:#3498DB,color:#fff
    style TESTWRITE fill:#7B68EE,color:#fff
    style ORACLE_ESC fill:#9B59B6,color:#fff
    style FINAL fill:#9B59B6,color:#fff
    style STEPPR fill:#2ECC71,color:#fff
    style STEPREV fill:#9B59B6,color:#fff
    style MERGE_STEP fill:#27AE60,color:#fff
    style LEARN fill:#2980B9,color:#fff
    style MERGE_MAIN fill:#27AE60,color:#fff
    style DONE fill:#27AE60,color:#fff
    style CLEAN fill:#F39C12,color:#fff
    style AUDITREV fill:#8E44AD,color:#fff
```

## Branch Naming Convention

| Prefix | When to use | Example |
|--------|------------|---------|
| `feature/` | New functionality, screens, endpoints | `feature/user-onboarding` |
| `fix/` | Bug fixes | `fix/login-redirect-loop` |
| `improvement/` | Refactors, performance, code quality | `improvement/query-optimization` |
| `security/` | Security patches, vulnerability fixes | `security/xss-sanitization` |
| `test/` | Adding/improving tests only | `test/backend-model-coverage` |
| `docs/` | Documentation changes only | `docs/api-reference` |
| `chore/` | Dependencies, config, CI, tooling | `chore/upgrade-rails-8.2` |
| `hotfix/` | Urgent production fixes | `hotfix/payment-crash` |

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
                ├── issues → oracle fix PR → parent
                └── clean → PR parent → main
```

## Flow Rules

### 1. Triage (Orchestrator — no agent cost)
- Simple tasks (1-2 files, clear change): handle directly, no plan needed
- Complex tasks: continue to pattern search + planning

### 2. Pattern Search (knowledge MCP)
- `pattern_search` for previously solved patterns
- Match found: apply pattern directly, skip full planning
- No match: proceed to plan-plus

### 3. Planning (plan-plus — ALWAYS for complex tasks)
- Generate structured plan with skeleton + files format
- User MUST review and approve before execution
- Changes loop back to re-plan

### 4. Branching
- Create parent branch: `feature/<plan-name>` from main
- Each step gets its own branch: `feature/<plan-name>/step-N` from parent
- Steps are sequential — step-2 branch created after step-1 PR is merged into parent

### 5. Execute Steps (sequential, parallel fixers within)
- For each step:
  1. Create step branch from parent
  2. Dispatch fixer(s) — parallel for independent sub-tasks within the step
  3. Run tests
  4. Create PR: step branch → parent branch
  5. Oracle reviews step PR
  6. Merge step PR into parent
  7. Loop to next step

### 6. Agent Model Routing
| Agent | Model | When |
|-------|-------|------|
| Explorer | haiku | File discovery, codebase navigation |
| Librarian | sonnet | Docs, API lookup, web search |
| Fixer | sonnet | All implementation work |
| Auditor | sonnet | Security scan, diff risk analysis |
| Oracle | opus | Code review, stuck diagnosis, security fixes |
| Orchestrator | opus | Triage, PR creation (no agent cost) |

### 7. Test + Retry
- Run tests after each step
- Retry fixer up to 2x on failure
- 3rd failure: escalate to Oracle (opus) for root cause diagnosis
- Oracle provides guidance → Fixer implements fix

### 8. Security Audit (once, after ALL steps merged into parent)
- Run on the full parent branch diff vs main
- Auditor (sonnet) scans for security issues, N+1, diff risk
- If issues found: Oracle creates a fix PR into parent branch
- Orchestrator reviews oracle's fix (acts as PM/lead)
- Re-audit until clean

### 9. Commit & PR Style

**Commits:** `<type>: <what changed>` — lowercase, under 72 chars, no period.
Types: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `perf`, `security`

**Two PR templates:**

| PR Type | Template | Audience | Release Notes? |
|---------|----------|----------|----------------|
| Step → parent | `PULL_REQUEST_TEMPLATE.md` | Developer reviewing the step | No |
| Parent → main | `PULL_REQUEST_TEMPLATE_MAIN.md` | Team + stakeholders | **Yes, required** |

**Step PRs (child → parent):** Short and technical.
- What (1 sentence) + Changes (bullets) + How to test (commands)

**Feature PRs (parent → main):** Descriptive and non-technical.
- Overview (what + why) + Links to ALL step PRs + Security audit status + Release Notes
- Release notes written for END USERS: "Teachers can now score all students at once"
- Not: "Added bulkCreateDailyScores mutation"

**Any PR to main/master MUST include release notes.** Features, hotfixes, improvements, security — all of them.

**Never include:** AI attribution, co-authored-by, paragraphs instead of bullets, technical jargon in release notes.

### 10. Final PR: Parent → Main (MUST include release notes)
- Create PR from parent branch into main
- Oracle does final review on the complete feature diff
- Reviews: code quality, PR title/description, architecture, test coverage
- Issues → fix on parent → re-review
- Approved → learn + merge

### 11. Learn (pattern_store)
- `pattern_store` successful patterns via knowledge MCP
- Tags: task type, files touched, approach used
- Future sessions retrieve instead of re-reasoning

### 12. Auto-Dream (Stop hook — background)
- Runs on session end (every 5 sessions / 24h)
- Consolidates memory, removes duplicates, prunes stale entries
- Uses haiku in background — zero interactive cost
