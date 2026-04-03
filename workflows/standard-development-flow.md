# Standard Development Flow

## Mermaid Diagram

```mermaid
flowchart TD
    USER(["User prompt"]) --> TRIAGE

    TRIAGE{"Orchestrator triages\ncomplexity"}
    TRIAGE -->|"Simple (1-2 files)"| DIRECT["Orchestrator handles directly"]
    TRIAGE -->|"Complex"| MEMORY

    MEMORY["pattern_search\nCheck for solved patterns"] --> FOUND

    FOUND{"Pattern found?"}
    FOUND -->|"Strong match"| ADAPT["Apply known pattern\nSkip planning"]
    FOUND -->|"No match"| PP

    ADAPT --> FIX
    DIRECT --> DONE

    PP["plan-plus\nGenerate plan, break into steps"] --> REVIEW

    REVIEW{"User reviews plan"}
    REVIEW -->|"Changes needed"| PP
    REVIEW -->|"Approved"| GROUP

    GROUP["Group independent steps\nfor parallel execution"] --> STEP

    STEP{"Next step/batch?"}
    STEP -->|"Yes"| RESEARCH{"Needs research?"}
    STEP -->|"All done"| AUDIT

    RESEARCH -->|"Unfamiliar code"| EXP["Explorer - haiku\nFind files, navigate codebase"]
    RESEARCH -->|"External API/docs"| LIB["Librarian - sonnet\nDocs lookup, web search"]
    RESEARCH -->|"No"| FIX

    EXP --> FIX
    LIB --> FIX

    FIX["Fixer - sonnet\nImplement step\n(parallel for independent steps)"] --> TEST

    TEST["Tests\nrails test / npm test"]
    TEST -->|"Fail"| RETRY{"Retry count?"}
    RETRY -->|"1st-2nd"| FIX
    RETRY -->|"3rd fail"| ESCALATE["Oracle - opus\nDiagnose root cause\nProvide fix guidance"]
    ESCALATE --> FIX
    TEST -->|"Pass"| STEP

    AUDIT["Auditor - sonnet\nSecurity scan + diff risk\non FULL diff"] --> CLEAN

    CLEAN{"Issues?"}
    CLEAN -->|"Found"| FIX
    CLEAN -->|"Clean"| PR

    PR["Orchestrator creates PR\ngh pr create\nFollow PR template"] --> ORACLE

    ORACLE["Oracle - opus\nCode review\nReview PR quality + description"]

    ORACLE -->|"Issues"| FIXPR["Fixer - sonnet\nFix oracle feedback"]
    ORACLE -->|"Approved"| LEARN

    FIXPR --> ORACLE

    LEARN["pattern_store\nSave successful patterns\nfor future sessions"] --> MERGE

    MERGE(["Merge PR\ngh pr merge"])

    style USER fill:#34495E,color:#fff
    style TRIAGE fill:#8E44AD,color:#fff
    style MEMORY fill:#2980B9,color:#fff
    style FOUND fill:#F39C12,color:#fff
    style ADAPT fill:#2980B9,color:#fff
    style DIRECT fill:#27AE60,color:#fff
    style PP fill:#4A90D9,color:#fff
    style REVIEW fill:#F39C12,color:#fff
    style GROUP fill:#8E44AD,color:#fff
    style FIX fill:#E67E22,color:#fff
    style FIXPR fill:#E67E22,color:#fff
    style TEST fill:#7B68EE,color:#fff
    style AUDIT fill:#E74C3C,color:#fff
    style PR fill:#2ECC71,color:#fff
    style ORACLE fill:#9B59B6,color:#fff
    style LEARN fill:#2980B9,color:#fff
    style MERGE fill:#27AE60,color:#fff
    style EXP fill:#3498DB,color:#fff
    style LIB fill:#3498DB,color:#fff
    style DONE fill:#27AE60,color:#fff
    style RETRY fill:#E67E22,color:#fff
    style ESCALATE fill:#9B59B6,color:#fff
    style CLEAN fill:#F39C12,color:#fff
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

### 4. Execute Steps in Batches (then loop)
- Group independent steps for parallel execution
- Each fixer runs as `plan-plus:plan-plus-executor` subagent (ephemeral context)
- After each batch completes + tests pass, loop to next batch
- Continue until all steps done

### 5. Agent Model Routing
| Agent | Model | When |
|-------|-------|------|
| Explorer | haiku | File discovery, codebase navigation |
| Librarian | sonnet | Docs, API lookup, web search |
| Fixer | sonnet | All implementation work |
| Auditor | sonnet | Security scan, diff risk analysis |
| Oracle | opus | Code review, stuck diagnosis only |
| Orchestrator | opus | Triage, PR creation (no agent cost) |

### 6. Test + Retry
- Run tests after each step/batch
- Retry fixer up to 2x on failure
- 3rd failure: escalate to Oracle (opus) for root cause diagnosis
- Oracle provides guidance → Fixer implements fix

### 7. Audit (once, on FULL diff before PR)
- Security scan + diff risk on the complete branch diff
- Runs after ALL steps pass tests
- Uses sonnet for thoroughness

### 8. PR Creation (Orchestrator — no agent cost)
- Orchestrator creates PR directly via `gh pr create`
- Follows repo's `.github/PULL_REQUEST_TEMPLATE.md`

### 9. Code Review (Oracle — opus, one call)
- Reviews full PR diff + title + description
- Checks: N+1, security, architecture, test coverage, PR quality
- Issues → Fixer fixes → Oracle re-reviews
- Approved → proceed to learn + merge

### 10. Learn (pattern_store)
- `pattern_store` successful patterns via knowledge MCP
- Tags: task type, files touched, approach used
- Future sessions retrieve instead of re-reasoning

### 11. Auto-Dream (Stop hook — background)
- Runs on session end (every 5 sessions / 24h)
- Consolidates memory, removes duplicates, prunes stale entries
- Uses haiku in background — zero interactive cost
