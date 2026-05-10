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

The table includes 25 scored rows (items 1–25) and 2 advisory rows (items 26–27). Advisory rows do not contribute to the score and display as informational with `[OK]` or `[ADVISORY]` status.

Print final score: `X/25 (Y%)` and `P0 missing: N`. (Score denominator is always 25; advisory rows are excluded.)

## Step 3 — Recommend next action

If score < 100%, append:
> Run `/project-doctor-fix` to auto-generate missing artefacts.

End. No questions asked. No files written.

## Status legend

| Status | Meaning | Affects score? |
|--------|---------|----------------|
| `[OK]` | Check passes | Yes (numerator) |
| `[MISSING]` | Required artefact absent or empty | Yes (lowers score) |
| `[STALE]` | Required artefact present but >90d unchanged | Yes (lowers score) |
| `[ADVISORY]` | Optional environment tool not detected (rows >25) | No — informational only |

## Tier definitions

- **Scored items (1–25):** Required artefacts fixable by repo commit. Each contributes to `PRESENT/25` denominator. Severity P0–P2 determines display order, not weight.
- **Advisory items (26+):** External tooling (CLI binaries, environment state) not fixable by repo commit. Severity P3. Excluded from `--missing-only` and from score numerator/denominator. Displayed for awareness only.

When adding a new check: if the user can fix it by committing to the repo → scored (1–25). If it requires their dev environment to change → advisory (26+).
