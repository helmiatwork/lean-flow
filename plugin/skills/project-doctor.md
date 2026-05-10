---
name: project-doctor
description: Read-only audit of project context artefacts. Reports AI-readiness score and lists missing items. Does NOT modify files. Use /project-doctor-fix to auto-generate.
---

# Project Doctor — Audit

Run the same flow as `/project-doctor` slash command (read-only). See `commands/project-doctor.md`.

## Trigger phrases
- "/project-doctor"
- "audit project context"
- "check project AI readiness"
- "project health check"

## Disambiguation
This skill is read-only — it does not modify files. If user wants to generate missing artefacts, route to `/project-doctor-fix` instead.
