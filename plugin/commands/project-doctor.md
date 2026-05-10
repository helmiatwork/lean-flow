---
name: project-doctor
description: Audit project context artefacts (CLAUDE.md, codemap, architecture, ERD, ADR, hooks, etc.) and report gaps. Read-only.
---

# /project-doctor

Read-only audit. Reports the AI-readiness score and lists missing artefacts. Does NOT modify the repo.

## Step 1 — Run scanner

Run `${CLAUDE_PLUGIN_ROOT}/scripts/project-doctor/score.sh`. Capture stdout.

## Step 2 — Render report

Print the scanner's 5-column markdown table verbatim: # | Item | File | Severity | Status. Do not reformat.

Print final score: `X/25 (Y%)` and `P0 missing: N`.

## Step 3 — Recommend next action

If score < 100%, append:
> Run `/project-doctor-fix` to auto-generate missing artefacts.

End. No questions asked. No files written.
