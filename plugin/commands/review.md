---
name: review
description: Trigger code-reviewer + oracle in parallel on current branch or specific PR.
---

# /lean-flow:review

Trigger parallel code-quality and architecture reviews on current branch or a specific PR. Dispatches `lean-flow:code-reviewer` and `lean-flow:oracle` (both sonnet, think-only) in single Agent call.

## Step 1 — Ask user: review scope

Display AskUserQuestion with options:

```
Review code on which scope?

  [1] Current branch (HEAD vs merge-base with main)
      Reviews: git diff main...HEAD (all commits in this branch)
  
  [2] Specific PR (input PR number)
      Reviews: PR's diff (from base branch to head)
  
  [3] Last commit only
      Reviews: git diff HEAD~1 HEAD (most recent commit)

Choose [1], [2], or [3] (default: 1):
```

Store user choice.

## Step 2 — Determine diff range

**If choice == 1 (current branch):**
```bash
DIFF_RANGE=$(git merge-base main HEAD)...HEAD
SCOPE_DESC="current branch vs main"
```

**If choice == 2 (specific PR):**
```bash
# Prompt for PR number
PR_NUM=<ask-user-for-number>

# Get PR base + head
PR_BASE=$(gh pr view $PR_NUM --json baseRefName --jq '.baseRefName')
PR_HEAD=$(gh pr view $PR_NUM --json headRefName --jq '.headRefName')
DIFF_RANGE=$PR_BASE...$PR_HEAD
SCOPE_DESC="PR #$PR_NUM ($PR_BASE...$PR_HEAD)"
```

**If choice == 3 (last commit):**
```bash
DIFF_RANGE=HEAD~1..HEAD
SCOPE_DESC="last commit only"
```

## Step 3 — Get changed files and diff summary

```bash
CHANGED_FILES=$(git diff --name-only $DIFF_RANGE)
CHANGED_COUNT=$(echo "$CHANGED_FILES" | wc -l)

# Fetch short summary (first 50 lines of diff)
DIFF_SUMMARY=$(git diff $DIFF_RANGE | head -50)
```

## Step 4 — Dispatch code-reviewer + oracle in parallel

Use single Agent call to dispatch both agents in parallel (batch agents):

```
Dispatch both agents:

---

Agent: lean-flow:code-reviewer
Context: "Code-quality + SOLID review

Scope: $SCOPE_DESC
Diff range: $DIFF_RANGE
Changed files ($CHANGED_COUNT):
$CHANGED_FILES

Diff preview (first 50 lines):
\`\`\`
$DIFF_SUMMARY
\`\`\`

Task: Review code for:
1. Code quality (naming, clarity, maintainability)
2. SOLID principles (single responsibility, open/closed, etc.)
3. Design patterns (appropriate use, consistency)
4. Test coverage and test quality
5. Performance concerns
6. Security issues (input validation, injection vectors)

Return verdict:
- APPROVED (or APPROVED with minor notes)
- CHANGES_REQUESTED (with numbered findings)

Format: numbered list of findings (if any), each with:
  - P0/P1/P2 severity
  - File:line (or area)
  - Issue + recommendation
"

---

Agent: lean-flow:oracle
Context: "Architecture + security review

Scope: $SCOPE_DESC
Diff range: $DIFF_RANGE
Changed files ($CHANGED_COUNT):
$CHANGED_FILES

Diff preview (first 50 lines):
\`\`\`
$DIFF_SUMMARY
\`\`\`

Task: Review for:
1. Architectural consistency (matches project design)
2. Security implications (new attack surface, data flow)
3. Cross-cutting concerns (error handling, logging, observability)
4. Trade-offs and dependencies (new deps, API contracts)
5. Scalability (no obvious bottlenecks or N+1 queries)
6. Database/API design (if applicable)

Return verdict:
- APPROVED (or APPROVED with notes)
- CHANGES_REQUESTED (with numbered findings)

Format: numbered list of findings (if any), each with:
  - P0/P1/P2 severity
  - Category (architecture/security/api/db/etc)
  - Issue + recommendation
"
```

Wait for both agents to return (parallel batch, single combined response).

## Step 5 — Parse and render combined verdict

Collect responses from both agents. Render markdown summary:

```markdown
# Code Review Report

**Scope:** $SCOPE_DESC  
**Changed files:** $CHANGED_COUNT  
**Reviewers:** lean-flow:code-reviewer (sonnet) + lean-flow:oracle (sonnet)

---

## Code-Reviewer Verdict

<VERDICT-FROM-CODE-REVIEWER>

### Findings (if any)

<NUMBERED-FINDINGS>

---

## Oracle Verdict

<VERDICT-FROM-ORACLE>

### Findings (if any)

<NUMBERED-FINDINGS>

---

## Summary

| Reviewer | Verdict | Issues |
|----------|---------|--------|
| code-reviewer | <APPROVED/CHANGES_REQUESTED> | <count> |
| oracle | <APPROVED/CHANGES_REQUESTED> | <count> |

### Combined Status

<If both APPROVED:>
  ✅ **All reviewers approved.** Ready to merge (after CI green).

<If any CHANGES_REQUESTED:>
  🔍 **Review feedback received.**
  
  Next steps:
  1. Review findings above
  2. Address each issue (fix code or request clarification)
  3. Re-test and verify linters pass
  4. Push changes
  5. Re-request review (re-run this command or open PR)
  
  Fixer owns applying feedback and re-requesting review.
```

## Hard rules

- **No code edits.** Both reviewers are think-only (sonnet). Orchestrator/fixer applies feedback.
- **Parallel dispatch.** Single Agent call with both agents (batch, efficient).
- **Graceful fallback.** If user cancels at scope prompt, stop cleanly.
- **No automatic changes.** Just report findings; user/fixer applies fixes.
- **Reviewer rules:** code-reviewer focuses on code-quality/SOLID/patterns; oracle focuses on architecture/security/trade-offs. No overlap in responsibilities.
- **Async-safe.** Both agents run think-only (no file access). Safe to loop multiple times.
