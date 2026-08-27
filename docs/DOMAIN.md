# Domain Model

Core entities of the lean-flow plugin and their relationships.

## Entities

| Entity | Role | Example |
|--------|------|---------|
| **Orchestrator** | Main Claude Code session bound to `lean-flow:orchestrator` contract. Classifies prompts (simple/medium/heavy), writes plans, dispatches subagents, verifies output. Never writes code for medium/heavy. | "User opens a project → session starts → orchestrator triages the request." |
| **Agent** | Specialized subagent dispatched by orchestrator. Six roles: fixer (impl), oracle (architecture, think-only), code-reviewer (quality), explorer (file search), librarian (docs), designer (frontend). | `lean-flow:fixer` implements tests + code. `lean-flow:oracle` reviews architecture (reads summaries, not files). |
| **Skill** | Auto-discoverable behavior module invoked via Skill tool. Examples: `superpowers:writing-plans`, `superpowers:test-driven-development`, `cartography`, `project-doctor`. | Invoking `writing-plans` skill generates a plan skeleton with step structure. |
| **Hook** | Event-triggered shell command registered in `plugin/hooks/hooks.json`. Lifecycle events: SessionStart, PreToolUse, PostToolUse, Stop, PostCompact, UserPromptSubmit. | `bash-guard.sh` fires on PreToolUse(Bash) and blocks dangerous patterns (protected-branch push, --no-verify, secret files, Claude identity, PR comments). |
| **Plan** | Multi-step implementation contract created via `superpowers:writing-plans` skill. Executed via dispatcher → agents per step. Plans live in `~/.gemini/plans/`. | A 5-step feature plan with step files + skeleton for user to mark progress. |
| **Phase** | Group of related plans within a milestone (optional structure for heavy work). Used for tracking multi-session projects. | Phase 1: Setup + CI. Phase 2: Core feature. Phase 3: Polish. |
| **Step Branch** | Single-plan-step branch named `<base>/step-N`, merged into parent before final PR to main. Isolates work per step. | `feature/user-auth/step-1` (login form), `feature/user-auth/step-2` (password reset). |
| **Command** | Slash command bundled in the plugin. Invoked as `/<name>`. Maps to a skill or hook. | `/project-doctor` runs the audit skill. `/project-doctor-fix` runs the fix generation skill. |
| **PR** | Pull request linking step branches to parent, or parent to main. Two templates: step (technical) vs main (business + release notes). | Step PR auto-merges on CI. Main PR requires oracle approval. |

## Relationships

```
Orchestrator
├─ dispatches → Agent
│  └─ (fixer, oracle, code-reviewer, explorer, librarian, designer)
├─ invokes → Skill
│  └─ (writing-plans, test-driven-development, cartography, project-doctor, etc.)
└─ triggers → Hook
   └─ (on SessionStart, PreToolUse, PostToolUse, Stop, etc.)

Plan
├─ contains → Step (ordered sequence)
│  └─ Step-N may spawn Step Branch → Agent
│     └─ Agent pushes → PR
│        └─ PR merges to Parent
└─ Phase (optional grouping)

Command
└─ invokes → Skill or Hook

Agent
├─ returns → Diff, PR, or text guidance
└─ never peer-to-peer (always routed through Orchestrator)
```

## Boundaries

### Orchestrator Boundary
- **MUST NOT** write code for medium/heavy work. Always dispatch fixer.
- **CAN** read files, check git state, create branches, write memory/planning docs.
- **ROUTES** all code changes through fixer → reviewer → oracle → merge.

### Oracle Boundary
- **CANNOT** read files or write code. Has `tools: []`.
- **CAN** receive summaries from explorer and return text guidance only.
- **RETURNS** architecture review, security audit, PR feedback, codebase map decisions (not implementations).

### Fixer Boundary
- **CAN** write code, tests, linters, commit, push, open PRs.
- **ROUTES** PR feedback (from oracle/code-reviewer) to appropriate subagent (designer, self, or both).
- **OWNS** the full cycle: impl → tests → lint → commit → push → PR → reviews → merge.

### Explorer Boundary
- **CAN** read files, diffs, scan codebase.
- **CANNOT** write code or edit files.
- **RETURNS** structured summaries (file lists, diff summaries, codebase structure) to oracle.

### Designer Boundary
- **CAN** write frontend code, tests, styling, components.
- **STOPS** before opening PR. Fixer owns the PR cycle.
- **ROUTES** to fixer for final review + merge.

### Hook Boundary
- **RUN** synchronously, must complete ≤30s typically.
- **CANNOT** dispatch agents. May block actions (exit code 2).
- **MAY** read files, execute shell commands, inject context.
- **MUST** be fast and idempotent (no side effects outside `.gitignore`d paths).

## State Machines

### Prompt Tier Classification
```
UserPrompt
  → STAR classifier
    ├─ Simple → orchestrator edits directly
    ├─ Medium → plan → dispatch fixer
    ├─ Heavy → plan + research → dispatch fixer
    ├─ Greenfield → brainstorm + docs → plan → dispatch fixer
    └─ Hotfix → minimal fix → oracle inline review → merge
```

### Plan Execution
```
Plan created (writing-plans skill)
  → User reviews + approves
  → ExitPlanMode (plan-plus restructures)
  → Step 1
    → Step branch → agent → PR
    → Merge to parent
    → Mark [x] in skeleton
  → Step 2, 3, ... (same)
  → All steps complete
  → Parent → main PR (full review cycle)
  → Merge to main
```

### PR Review Cycle
```
PR opened (fixer)
  → code-reviewer reviews (round 1)
  → oracle reviews (round 1)
  ├─ Both APPROVED → CI gate
  ├─ Issues found → fixer applies → loop (round 2, 3)
  ├─ Round 4 → human escalation
  └─ CI green → merge (squash)
```

## Consistency Rules

1. **Agents never communicate peer-to-peer.** All routing through orchestrator.
2. **Oracle is always think-only.** Never edit, never read files directly.
3. **Hooks run fast and can't dispatch.** They inject context or block actions.
4. **Plans are explicit before execution.** No YOLO coding on medium/heavy work.
5. **Every commit is conventional.** Type + subject + optional body.
6. **Every PR has a template.** Step PRs (technical), main PRs (business + release notes).

## Glossary

| Term | Definition |
|------|-----------|
| **Dispatch** | Orchestrator sends a work request to a subagent via the Task/Agent tool. |
| **Invoke** | Orchestrator calls a Skill (automatic on matching context). |
| **Think-only** | Agent receives summaries only (no file access), returns text guidance only. |
| **E2E** | End-to-end: implementation → tests → lint → commit → push → PR → review → merge. |
| **Step branch** | Isolated work branch for a single plan step, merged to parent before final PR. |
| **STAR** | Simple/medium/heavy/greenfield/hotfix tier classifier. |
| **Cartography** | Two-tier codebase mapping: Tier 1 (atlas: `docs/CODEBASE_MAP.md`), Tier 2 (detail: per-folder `codemap.md`). |
