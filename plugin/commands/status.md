---
name: status
description: Composite project health snapshot (score, branch, recent commits, open PRs).
---

# /lean-flow:status

Composite project health dashboard. Read-only snapshot of AI-readiness score, current branch, recent commits, and open pull requests.

## Step 1 — Get AI-readiness score

Run project-doctor scorer (read-only):

```bash
SCORE_OUTPUT=$(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/project-doctor/score.sh 2>/dev/null || echo "")

# Extract score line: "X/25 (Y%)"
SCORE=$(echo "$SCORE_OUTPUT" | grep -E "^[0-9]+/25" | head -1)
if [ -z "$SCORE" ]; then
  SCORE="? (scorer unavailable)"
fi
```

## Step 2 — Get current branch

```bash
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "?")
```

## Step 3 — Get recent commits

```bash
RECENT_COMMITS=$(git log --oneline -5 2>/dev/null | sed 's/^/  /')
if [ -z "$RECENT_COMMITS" ]; then
  RECENT_COMMITS="  (no commits)"
fi
```

## Step 4 — Get open PRs from GitHub (if in git repo with remote)

```bash
REMOTE=$(git config --get remote.origin.url 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/\.git$//')

if [ -n "$REMOTE" ] && command -v gh >/dev/null; then
  # Attempt to fetch open PRs (requires gh CLI auth)
  PR_LIST=$(gh pr list --state open --limit 5 --json number,title,state,mergeable 2>/dev/null || echo "")
  
  if [ -n "$PR_LIST" ]; then
    PR_COUNT=$(echo "$PR_LIST" | wc -l)
    PR_SUMMARY=$(echo "$PR_LIST" | awk '{print "  #" $1 ": " substr($2, 1, 60)}' | head -5)
  else
    PR_COUNT="0"
    PR_SUMMARY="  (none or gh not authenticated)"
  fi
else
  PR_COUNT="?"
  PR_SUMMARY="  (not a GitHub repo or gh CLI not available)"
fi
```

## Step 5 — Render composite dashboard

```markdown
# Project Status

## AI-Readiness Score
**${SCORE}**

([Full audit: /lean-flow:project-doctor](${CLAUDE_PLUGIN_ROOT}/plugin/commands/project-doctor.md))

## Git State

| Metric | Value |
|--------|-------|
| **Current Branch** | \`$BRANCH\` |
| **Total Commits** | $COMMIT_COUNT |
| **Remote** | $REMOTE |

## Recent Commits (last 5)

\`\`\`
$RECENT_COMMITS
\`\`\`

## Open Pull Requests

**Count:** $PR_COUNT

\`\`\`
$PR_SUMMARY
\`\`\`

---

### Next Steps

- **If score < 100%:** Run \`/lean-flow:project-doctor\` for full audit
- **If score has gaps:** Run \`/lean-flow:project-doctor-fix\` to auto-generate missing artefacts
- **For branch health:** Check recent commits above; ensure tests pass before merging
- **For open PRs:** Review status; check CI gates and review state

---

**Last checked:** $(date -u +'%Y-%m-%dT%H:%M:%SZ')
```

## Hard rules

- **Read-only.** No writes, no changes.
- **No questions asked.** Just report.
- **Graceful degradation.** If gh CLI unavailable or not authenticated, report PRs as "(not available)".
- **Non-blocking audit.** Status is informational; does not halt workflows.
- **Fast execution.** Keep runtime under 5 seconds (cache scorer output if needed).
- **Remote-agnostic.** If not a GitHub repo or remote not configured, report gracefully (does not error).
