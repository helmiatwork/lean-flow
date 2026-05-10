---
name: project-doctor-fix
description: Auto-generate all missing project context artefacts in one pass — runs the audit, asks 4W1H questions, writes every missing file. Triggers on /project-doctor-fix or when the user wants to bulk-generate project documentation.
---

# Project Doctor — Fix

When invoked, run the same flow as `/project-doctor-fix` slash command. See `commands/project-doctor-fix.md` in this plugin for full instructions.

## Trigger phrases
- "/project-doctor-fix"
- "bulk-generate missing project artefacts"
- "auto-fix project documentation gaps"
- "run project doctor fix"

## Disambiguation
This skill writes files. If user wants only to check status, route to `/project-doctor` (read-only audit) instead.
