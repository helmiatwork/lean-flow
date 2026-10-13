---
name: pr-comment
description: Post review findings from a previous pr-review to the GitHub PR. Use for "comment on the PR", "post the findings". Usage: /pr-comment "<which findings>, <approve|request changes>"
---

# PR Comment

Post comments to the given PR. If no PR is given, assume the most recently reviewed PR.

## Rules

- Comments on GitHub are always in English. Console output is in English.
- Keep each finding and the review body (request changes / approve) concise and human in tone — no robotic tables, agent prefixes, or AI attribution.
- Approve vs request changes always comes from the command argument. If it is missing, do nothing and ask the user which one.
- Target findings classified as Blocker and Important.
- Skip Nit-picks unless the user names them.
- If finding numbers are given, comment only on those numbers and nothing else.
- Resolve threads from earlier rounds that are already fixed.
- Post as one review (`gh api repos/<owner>/<repo>/pulls/<n>/reviews`) with inline comments on the PR head commit.
- Inline `line` must be the source-file line on the PR head (and inside the diff), never a diff offset. Verify against `git show <head>:<path>` before posting.
- Put replacement code in ```suggestion blocks.
