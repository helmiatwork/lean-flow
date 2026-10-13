---
name: pr-review
description: Review a GitHub PR and print the result to the terminal only. Use for "review this PR", "look at this PR", "re-review the PR". Usage: /pr-review <pr-url>
---

# PR Review

Review the given PR. Output goes to the terminal only — never post to GitHub from this skill (use `pr-comment` for that).

## Steps

- Run the review with `superpowers:requesting-code-review` (dispatch the reviewer subagent with the PR's base/head SHAs).
- Do NOT write results with `gh pr review` / `gh pr comment`. Print to the terminal only.
- Re-review: first fetch the previous review findings, then evaluate mainly by the status of each one (addressed / not addressed / different approach).
- If the PR description links an Asana task or Sentry issue, read it and check the PR meets the requirement and the fix is appropriate.
- Show the verdict first with an icon: 🟢 Approve or 🔴 Request Changes. Keep the output concise.
- Number every finding and group by severity with an icon, so the user can refer to them later:
  - 🚫 Blocker
  - ⚠️ Important
  - 💡 Nit-picks
- To check code out locally, use `git worktree` under the project's `.worktrees/` directory.
- Remove the worktree (and any temp branch) after the review.
- If you started docker containers to verify, stop them after the review. Do not stop containers that were already running before this review session.
- Print the PR URL at the end.
- Console output in English.
